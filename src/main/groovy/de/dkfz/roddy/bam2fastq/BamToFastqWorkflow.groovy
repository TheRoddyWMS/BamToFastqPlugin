/*
 * Copyright (c) 2018 DKFZ - ODCF
 *
 * Distributed under the MIT License (license terms are at https://github.com/TheRoddyWMS/BamToFastqPlugin/blob/master/LICENSE.txt).
 */
package de.dkfz.roddy.bam2fastq

import de.dkfz.roddy.Constants
import de.dkfz.roddy.Roddy
import de.dkfz.roddy.config.ConfigurationError
import de.dkfz.roddy.core.DataSet
import de.dkfz.roddy.core.ExecutionContext
import de.dkfz.roddy.core.ExecutionContextError
import de.dkfz.roddy.core.Workflow
import de.dkfz.roddy.execution.io.ExecutionService
import de.dkfz.roddy.knowledge.files.BaseFile
import de.dkfz.roddy.knowledge.files.FileGroup
import de.dkfz.roddy.tools.LoggerWrapper
import groovy.transform.CompileStatic


@CompileStatic
class BamToFastqWorkflow extends Workflow {

    public static final LoggerWrapper logger = LoggerWrapper.getLogger("BamToFastqWorkflow")

    private synchronized static Map<DataSet,List<BaseFile>> _bamFilesPerDataset = [:]

    private synchronized static Map<DataSet, Config> _config = [:]

    private synchronized final static Map<String,ReadGroupGroup> readGroupsPerBamfile = [:]

    public static final String TOOL_BAM_LIST_READ_GROUPS = "bamListReadGroups"
    public static final String TOOL_BAM2FASTQ = "bam2fastq"
    public static final String TOOL_SORT_FASTQ_SINGLE = "sortFastqSingle"
    public static final String TOOL_SORT_FASTQ_PAIR = "sortFastqPair"
    public static final String TOOL_CLEANUP = "cleanup"

    List<BaseFile> getBamFiles() {
        _bamFilesPerDataset.get(context.dataSet, [])
    }

    Config getConfig() {
        _config.get(context.dataSet, null)
    }

    // TODO Remove sample, sequence protocol etc. from filename patterns, etc. -- implement this stuff later
    void determineBamFiles() {
        List<BaseFile> bamFiles = []
        if (Roddy.isMetadataCLOptionSet()) {
            logger.severe("Metadata table input not implemented. Please use ${Config.CVALUE_BAMFILE_LIST} to specify the BAM files to convert.")
        } else if (config.bamList.size() > 0) {
            bamFiles = config.bamList.collect { filename ->
                BaseFile.getSourceFile(context, filename, "BamFile")
            }
        } else {
            // Collect files from directory structure.
            logger.severe("Please use '${Config.CVALUE_BAMFILE_LIST}' to specify the BAM files to convert.")
        }
        if (bamFiles.size() == 0)
            logger.warning("No input BAM files were specified for dataset ${context.dataSet}.")

        _bamFilesPerDataset[context.dataSet] = bamFiles
    }

    /**
     * Return a list of ReadGroups from a BAM file. This executes the TOOL_BAM_LIST_READ_GROUPS on the (possibly remote) submission host.
     * @param context
     * @param bamfileName
     */
    ReadGroupGroup listReadGroups(String bamfileName) {
        if (!readGroupsPerBamfile[bamfileName]) {
            logger.always("Listing read groups in '$bamfileName'.")
            readGroupsPerBamfile[bamfileName] =
                    new ReadGroupGroup(
                            ExecutionService.getInstance().
                            runDirect(context, TOOL_BAM_LIST_READ_GROUPS, ['BAMFILE': bamfileName] as Map<String, Object>).
                            collect { new ReadGroup(it) })
            logger.always("Found the following read-groups in '$bamfileName':${Constants.ENV_LINESEPARATOR}\t" +
                    readGroupsPerBamfile[bamfileName].readGroups.collect { it.name }.join("${Constants.ENV_LINESEPARATOR}\t"))
        }
        readGroupsPerBamfile[bamfileName]
    }

    private ReadGroupGroup<BaseFile> updatedReadGroupGroup(final ReadGroupGroup<BaseFile> oldGroups, final FileGroup fileGroup) {
        assert(oldGroups.readGroups.collect { it.files.size() }.sum() == fileGroup.size())
        List<ReadGroup<BaseFile>> readGroups = []
        for (int grpIdx = 0; grpIdx < oldGroups.size(); ++grpIdx) {
            ReadGroup newGroup = new ReadGroup<BaseFile>(oldGroups.readGroups[grpIdx].name)
            for (int tpeIxd = 0; tpeIxd < ReadFileType.values().size(); ++ tpeIxd) {
                int idx = grpIdx * ReadFileType.values().size() + tpeIxd
                newGroup = newGroup.updatedFile(ReadFileType.values()[tpeIxd], fileGroup[idx])
            }
            readGroups += newGroup
        }
        return new ReadGroupGroup(readGroups)
    }

    /**
     * Extract FASTQs from a BAM. This may be with or without read-groups. The names of the output files depend on the parameters.
     */
    ReadGroupGroup bam2fastq(BaseFile controlBam, ReadGroupGroup groups) {
        List<String> rgFileIndicesParameter = groups.allReadGroupIds()
        updatedReadGroupGroup(groups, callWithOutputFileGroup(TOOL_BAM2FASTQ, controlBam,
                rgFileIndicesParameter, [readGroups: groups.readGroups*.name]))
    }

    /** Submit sorting jobs for each read group. The read-group name is provided via the `readGroup` parameter. Also the BAM-file name is provided
     *  such that it can be used in the filename pattern using the `${cvalue}` syntax.
     *
     * @param bamFileName
     * @param readGroup
     * @param fastq1
     * @param fastq2
     * @param fastq3
     */
    void sortPairedFastqs(String bamFileName, String readGroup, BaseFile fastq1, BaseFile fastq2) {
        assert (fastq1 != null)
        assert (fastq1.absolutePath != fastq2?.absolutePath)
        HashMap<String, String> parameters = [readGroup: readGroup, bamFileName: bamFileName]
        call_fileObject(TOOL_SORT_FASTQ_PAIR, fastq1, fastq2, parameters)
    }

    void sortFastq(String bamFileName, String readGroup, BaseFile fastq) {
        assert (fastq != null)
        HashMap<String, String> parameters = [readGroup: readGroup, bamFileName: bamFileName]
        call_fileObject(TOOL_SORT_FASTQ_SINGLE, fastq, parameters)
    }

    protected FileGroup cleanupFastqsForBam(Config config, BaseFile controlBam, ReadGroupGroup groups) {
        if (config.pairedEnd) {
            List<String> rgFileIndicesParameter = groups.allReadGroupIds()
            return callWithOutputFileGroup(TOOL_CLEANUP, controlBam, rgFileIndicesParameter, [readGroups: groups])
        } else {
            throw new ConfigurationError("Single-end cleanup not implemented", config.FLAG_PAIRED_END)
        }
    }

    @Override
    boolean cleanup() {
        for (BaseFile BaseFile : _bamFilesPerDataset.get(context.dataSet, [])) {

            if (config.outputPerReadGroup) {
                cleanupFastqsForBam(config, BaseFile, readGroupsPerBamfile[BaseFile.absolutePath])
            }

        }
        return true
    }

    Map<String, ReadGroupGroup> readAllReadGroups(List<BaseFile> bamFiles) {
        bamFiles.collectEntries { bamFile ->
            [(bamFile.absolutePath): listReadGroups(bamFile.absolutePath)]
        }
    }

    @Override
    boolean setupExecution(ExecutionContext context) {
        _config[context.dataSet] = new Config(context)

        boolean result = super.setupExecution(context)
        determineBamFiles()
        if (bamFiles.size() > 0) {
            if (new Config(context).outputPerReadGroup)
                readAllReadGroups(bamFiles)
            result &= true
        } else {
            result &= false
        }
        result
    }

    @Override
    boolean execute(ExecutionContext context) {

        for (BaseFile bamFile : bamFiles) {

            if (config.outputPerReadGroup) {
                ReadGroupGroup<BaseFile> groups = readGroupsPerBamfile[bamFile.absolutePath]

                ReadGroupGroup<BaseFile> groupsWithUnsortedFastqs = bam2fastq(bamFile, groups)

                if (config.sortFastqs) {
                    for (ReadGroup<BaseFile> grp : groupsWithUnsortedFastqs.readGroups) {
                        sortPairedFastqs(bamFile.getPath().name, grp.name, grp[ReadFileType.READ1], grp[ReadFileType.READ2]) // R1/R2
                        sortFastq(bamFile.getPath().name, grp.name, grp[ReadFileType.UNMATCHED_READ1]) // U1
                        sortFastq(bamFile.getPath().name, grp.name, grp[ReadFileType.UNMATCHED_READ2]) // U2
                        sortFastq(bamFile.getPath().name, grp.name, grp[ReadFileType.SINGLETON]) // S
                    }
                }

            } else {
//                FileGroup out = bam2fastq(cfg, BaseFile)
//                if (cfg.sortPairedFastqs())
//                    this.sortPairedFastqs(cfg)
                throw new ConfigurationError("bam2fastq without output per read group not implemented", config.FLAG_SPLIT_BY_READ_GROUP)
            }

        }

        return true
    }

    protected boolean bamFilesAreAccessible(List<BaseFile> bamFiles) {
        return bamFiles.collect { file ->
            boolean result = context.fileIsAccessible(file.path)
            if (!result)
                context.addErrorEntry(ExecutionContextError.EXECUTION_PATH_INACCESSIBLE.
                        expand("BAM file not accessible: '${file.absolutePath}'"))
            result
        }.every()
    }

    protected boolean checkReadGroups(List<BaseFile> bamFiles) {
        Map<String, ReadGroupGroup<BaseFile>> readGroups = bamFiles.collectEntries { [(it): readGroupsPerBamfile[it.absolutePath]] }

        boolean result = readGroups.collect { file, groups ->
            if (groups.size() == 0) {
                context.addErrorEntry(ExecutionContextError.EXECUTION_NOINPUTDATA.
                        expand("BAM '${file}' does not contain any read group."))
                false
            } else {
                true
            }
        }.every()

        List<String> allReadGroupNames = readGroups.values().collect { it.readGroups.collect { it.name } }.flatten() as List<String>
        allReadGroupNames.countBy { it }.forEach { String group, Integer count ->
            if (count > 1) {
                // This is not a fatal error but may be intentional. Therefore just inform.
                logger.warning("Read group '${group}' occurs in multiple files. Continuing ...")
            }
        }

        return result
    }

    protected boolean checkBamFiles() {
        Boolean result = true

        if (!bamFiles) {
            context.addErrorEntry(ExecutionContextError.EXECUTION_NOINPUTDATA.expand("Did not find any BAM files."))
            return false
        }

        result &= bamFilesAreAccessible(bamFiles)

        if (new Config(context).outputPerReadGroup) {
            result &= checkReadGroups(bamFiles)
        }

        return result
    }

    boolean checkSingleDatasetOnly() {
        List<DataSet> datasets = context.getRuntimeService().
                loadDatasetsWithFilter(context.analysis, Roddy.getCommandLineCall().datasetSpecifications, true)
        if (datasets.size() != 1) {
            context.addErrorEntry(ExecutionContextError.EXECUTION_SETUP_INVALID.
                    expand("BamToFastqWorkflow only supports processing single datasets per run!"))
            return false
        }
        return true
    }

    @Override
    boolean checkExecutability() {
        boolean result = true
        result &= checkSingleDatasetOnly()
        result &= checkBamFiles()
        return result
    }
}
