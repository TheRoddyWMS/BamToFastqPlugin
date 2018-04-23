package de.dkfz.roddy.bam2fastq

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

/*
 * Copyright (c) 2018 DKFZ - ODCF
 *
 * Distributed under the MIT License (license terms are at https://www.github.com/eilslabs/Roddy/LICENSE.txt).
 */
import groovy.transform.CompileStatic

@CompileStatic
class BamToFastqWorkflow extends Workflow {

    public static final LoggerWrapper logger = LoggerWrapper.getLogger("BamToFastqWorkflow")

    private synchronized Map<DataSet,List<BaseFile>> _bamFilesPerDataset = [:]

    private Config config = null

    public static final String TOOL_BAM_LIST_READ_GROUPS = "bamListReadGroups"
    public static final String TOOL_BAM2FASTQ = "bam2fastq"
    public static final String TOOL_SORT_FASTQ_SINGLE = "sortFastqSingle"
    public static final String TOOL_SORT_FASTQ_PAIR = "sortFastqPair"
    public static final String TOOL_CLEANUP = "cleanup"

    List<BaseFile> getBamFiles() {
        _bamFilesPerDataset.get(context.dataSet, [])
    }

    // Remove sample, sequence protocol etc. from filename patterns, etc. -- implement this stuff later
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
     * Return a list of read-groups identifiers from a bam
     * @param context
     * @param bamfileName
     */
    private synchronized final Map<String,List<String>> readGroupsPerBamfile = [:]

    List<String> listReadGroups(String bamfileName) {
        if (!readGroupsPerBamfile[bamfileName]) {
             readGroupsPerBamfile[bamfileName] = //callDirect(TOOL_BAM_LIST_READ_GROUPS, ["BAMFILE": bamfileName] as Map<String, Object>)
                     ExecutionService.getInstance().callDirect(context, TOOL_BAM_LIST_READ_GROUPS, ["BAMFILE": bamfileName] as Map<String, Object>)
        }
        return readGroupsPerBamfile[bamfileName]
    }

    List<String> readGroupIndices(List<String> readGroups) {
        return readGroups.collect { String rg -> [rg + "_R1", rg + "_R2"] }.flatten() as List<String>
    }

    /**
     * Extract FASTQs from a BAM. This may be with or without read-groups. The names of the output files depend on the parameters.
     */
    FileGroup bam2fastq(BaseFile controlBam, List<String> readGroups) {
        if (config.pairedEnd) {
            List<String> rgFileIndicesParameter = readGroupIndices(readGroups)
            return callWithOutputFileGroup(TOOL_BAM2FASTQ, controlBam, rgFileIndicesParameter, [readGroups: readGroups])
        } else {
            throw new ConfigurationError("Single-end bam2fastq not implemented", config.FLAG_PAIRED_END)
        }
    }

    void sortFastqs(String readGroup, BaseFile fastq1, BaseFile fastq2 = null, BaseFile fastq3 = null) {
        assert(fastq1 != fastq2)
        assert(fastq1 != fastq3)
        assert(fastq2 == null || fastq2 != fastq3)
        if (config.pairedEnd) {
            if (!config.writeUnpairedFastq) {
                call_fileObject(TOOL_SORT_FASTQ_PAIR, fastq1, fastq2, [readGroup: readGroup])
            } else {
                throw new ConfigurationError("Single-end sortFastq not implemented", config.FLAG_PAIRED_END)
            }
        } else {
            call_fileObject(TOOL_SORT_FASTQ_PAIR, fastq1, [readGroup: readGroup])
        }
    }

    protected FileGroup cleanupFastqsForBam(Config config, BaseFile controlBam, List<String> readGroups) {
        if (config.pairedEnd) {
            List<String> rgFileIndicesParameter = readGroupIndices(readGroups)
            return callWithOutputFileGroup(TOOL_CLEANUP, controlBam, rgFileIndicesParameter, [readGroups: readGroups])
        } else {
            throw new ConfigurationError("Single-end cleanup not implemented", config.FLAG_PAIRED_END)
        }
    }

    @Override
    boolean cleanup() {
        for (BaseFile BaseFile : _bamFilesPerDataset.get(context.dataSet, [])) {

            if (config.outputPerReadGroup) {
                cleanupFastqsForBam(config, BaseFile, readGroupsPerBamfile[BaseFile.getAbsolutePath()])
            }

        }
        return true
    }

    Map<String, List<String>> readAllReadGroups(List<BaseFile> bamFiles) {
        return bamFiles.collectEntries { bamFile ->
            new MapEntry(bamFile.absolutePath, listReadGroups(bamFile.absolutePath))
        }
    }

    @Override
    boolean setupExecution(ExecutionContext context) {
        config = new Config(context)

        boolean result = super.setupExecution(context)
        determineBamFiles()
        if (bamFiles.size() > 0) {
            if (new Config(context).outputPerReadGroup)
                readAllReadGroups(bamFiles)
            result &= true
        } else {
            result &= false
        }
        return result
    }

    @Override
    boolean execute(ExecutionContext context) {

        for (BaseFile BaseFile : bamFiles) {

            if (config.outputPerReadGroup) {
                List<String> readGroups = readGroupsPerBamfile[BaseFile.absolutePath]

                FileGroup unsortedFastqs = bam2fastq(BaseFile, readGroups)

                if (config.sortFastqs) {
                    for (int i = 0; i < readGroups.size(); i++) {
                        this.sortFastqs(readGroups[i], unsortedFastqs[i * 2], unsortedFastqs[i * 2 + 1]) // All paired end, sorted by read group.
                    }
                }

            } else {
//                FileGroup out = bam2fastq(cfg, BaseFile)
//                if (cfg.sortFastqs())
//                    this.sortFastqs(cfg)
                throw new ConfigurationError("bam2fastq without output per read group not implemented", config.FLAG_SPLIT_BY_READ_GROUP)
            }

        }

        return true
    }

    protected static boolean bamFilesAreAccessible(List<BaseFile> bamFiles) {
        return bamFiles.collect { file ->
            boolean result = context.fileIsAccessible(file.path)
            if (!result)
                context.addErrorEntry(ExecutionContextError.EXECUTION_PATH_INACCESSIBLE.
                        expand("BAM file not accessible: '${file.absolutePath}'"))
            result
        }.inject { res, i -> res && i }
    }

    protected Boolean checkReadGroups(List<BaseFile> bamFiles) {
        Map<String, List<String>> readGroups = bamFiles.collectEntries { new MapEntry(it, readGroupsPerBamfile[it.absolutePath]) }

        boolean result = readGroups.collect { file, groups ->
            if (groups.size() == 0) {
                context.addErrorEntry(ExecutionContextError.EXECUTION_NOINPUTDATA.
                        expand("BAM '${file}' does not contain any read group."))
                false
            } else {
                true
            }
        }.inject { res, i -> res && i }

        readGroups.values().flatten().countBy { it }.forEach { String group, Integer count ->
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