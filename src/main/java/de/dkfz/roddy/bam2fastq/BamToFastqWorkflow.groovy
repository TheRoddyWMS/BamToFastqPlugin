package de.dkfz.roddy.bam2fastq

import de.dkfz.b080.co.common.BasicCOProjectsRuntimeService
import de.dkfz.b080.co.files.BasicBamFile
import de.dkfz.roddy.config.ToolEntry
import de.dkfz.roddy.config.ToolFileGroupParameter
import de.dkfz.roddy.core.DataSet
import de.dkfz.roddy.core.ExecutionContext
import de.dkfz.roddy.core.ExecutionContextError

/*
 * Copyright (c) 2018 DKFZ - ODCF
 *
 * Distributed under the MIT License (license terms are at https://www.github.com/eilslabs/Roddy/LICENSE.txt).
 */
import de.dkfz.roddy.core.Workflow
import de.dkfz.roddy.knowledge.files.BaseFile
import de.dkfz.roddy.knowledge.files.FileGroup
import de.dkfz.roddy.tools.LoggerWrapper
import groovy.transform.CompileStatic
import sun.reflect.generics.reflectiveObjects.NotImplementedException

@CompileStatic
class BamToFastqWorkflow extends Workflow {

    public static final LoggerWrapper logger = LoggerWrapper.getLogger("BamToFastqWorkflow")

    private List<BasicBamFile> bamFiles = []

    public static final String TOOL_BAM_LIST_READ_GROUPS = "bamListReadGroups"
    public static final String TOOL_BAM2FASTQ = "bam2fastq"
    public static final String TOOL_SORT_FASTQ_SINGLE = "sortFastqSingle"
    public static final String TOOL_SORT_FASTQ_PAIR = "sortFastqPair"
    public static final String TOOL_CLEANUP = "cleanup"

    /**
     * Return a list of read-groups identifiers from a bam
     * @param context
     * @param bamfileName
     */
    private synchronized final Map<String,List<String>> readGroupsPerBamfile = [:]

    List<String> listReadGroups(ExecutionContext context, String bamfileName) {
        if (!readGroupsPerBamfile[bamfileName]) {
             readGroupsPerBamfile[bamfileName] = callSynchronized(context, TOOL_BAM_LIST_READ_GROUPS, ["BAMFILE": bamfileName] as Map<String, Object>)
        }
        return readGroupsPerBamfile[bamfileName]
    }

    String getFastqName(Config cfg, String prefix, String readGroup, String index) {
        String result = prefix + readGroup + "_r" + index + ".fastq"
        if (cfg.compressIntermediateFastqs)
            result += ".gz"
        return result
    }

    /**
     * Extract FASTQs from a BAM. This may be with or without read-groups. The names of the output files depend on the parameters.
     */
    FileGroup bam2fastq(Config config, BasicBamFile controlBam, List<String> readGroups) {
        if (config.pairedEnd) {
            List<String> rgFileIndicesParameter = readGroups.collect { String rg -> [rg + "_R1", rg + "_R2"] }.flatten() as List<String>
            return callWithOutputFileGroup(TOOL_BAM2FASTQ, controlBam, rgFileIndicesParameter, [readGroups: readGroups])
        } else {
            throw new NotImplementedException()
        }
    }

    void sortFastqs(Config cfg, String readGroup, BaseFile fastq1, BaseFile fastq2 = null, BaseFile fastq3 = null) {
        assert(fastq1 != fastq2)
        assert(fastq1 != fastq3)
        assert(fastq2 == null || fastq2 != fastq3)
        if (cfg.pairedEnd) {
            if (!cfg.writeUnpairedFastq) {
                call(TOOL_SORT_FASTQ_PAIR, fastq1, fastq2, [readGroup: readGroup])
            } else {
                throw new NotImplementedException()
            }
        } else {
            call(TOOL_SORT_FASTQ_PAIR, fastq1, [readGroup: readGroup])
        }
    }

//    private FileGroup createCleanupJobInputFileGroup(ExecutionContext context) {
//        def configuration = context.getConfiguration()
//        ToolEntry.ToolParameter tparm = configuration.getTools().getValue("cleanup").getOutputParameters(configuration)[0];
//        return createOutputFileGroup(tparm as ToolFileGroupParameter) as FileGroup
//    }
//
//    @Override
//    boolean cleanup(DataSet dataset) {
//        return call(TOOL_CLEANUP, )
//        return false
//    }

    Map<String, List<String>> readAllReadGroups(ExecutionContext context, List<BasicBamFile> bamFiles) {
        return bamFiles.collectEntries { bamFile ->
            new MapEntry(bamFile.absolutePath, listReadGroups(context, bamFile.absolutePath))
        }
    }

    @Override
    boolean setupExecution(ExecutionContext context) {
        boolean result = super.setupExecution(context)
        bamFiles = (context.runtimeService as BasicCOProjectsRuntimeService).getAllBamFiles(context)
        if (bamFiles.size() > 0) {
            if (new Config(context).outputPerReadGroup)
                readAllReadGroups(context, bamFiles)
            result &= true
        } else {
            result &= false
        }
        return result
    }

    @Override
    boolean execute(ExecutionContext context) {
        Config cfg = new Config(context)

        for (BasicBamFile basicBamFile : bamFiles) {

            if (cfg.outputPerReadGroup) {
                List<String> readGroups = readGroupsPerBamfile[basicBamFile.absolutePath]

                FileGroup unsortedFastqs = bam2fastq(cfg, basicBamFile, readGroups)

                if (cfg.sortFastqs) {
                    for (int i = 0; i < readGroups.size(); i++) {
                        this.sortFastqs(cfg, readGroups[i], unsortedFastqs[i * 2], unsortedFastqs[i * 2 + 1]) // All paired end, sorted by read group.
                    }
                }

            } else {
//                FileGroup out = bam2fastq(cfg, basicBamFile)
//                if (cfg.sortFastqs())
//                    this.sortFastqs(cfg)
            }

        }

        return true
    }

    protected static boolean bamFilesAreAccessible(ExecutionContext context, List<BasicBamFile> bamFiles) {
        return bamFiles.collect { file ->
            context.fileIsAccessible(file.path)
        }.inject { res, i -> res && i }
    }

    protected static boolean bamFileIsUnique(ExecutionContext context, List<BasicBamFile> bamFiles) {
        return bamFiles.groupBy { it.path }.collect { path, files ->
            if (files.size() > 1) {
                context.addErrorEntry(ExecutionContextError.EXECUTION_NOINPUTDATA.
                        expand("BamToFastqWorkflow requires unique set of BAM files per dataset. Violated by '${path}'."))
                false
            } else {
                true
            }
        }.inject { res, i -> res && i }
    }

    protected Boolean checkReadGroups(ExecutionContext context, List<BasicBamFile> bamFiles) {
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
                logger.always("Read group '${group}' occurs in multiple files.")
            }
        }

        return result
    }

    protected boolean checkBamFiles(ExecutionContext context) {
        Boolean result = true

        if (!bamFiles) {
            context.addErrorEntry(ExecutionContextError.EXECUTION_NOINPUTDATA.expand("Did not find any BAM files."))
            return false
        }

        result &= bamFilesAreAccessible(context, bamFiles)
        result &= bamFileIsUnique(context, bamFiles)

        if (new Config(context).outputPerReadGroup) {
            result &= checkReadGroups(context, bamFiles)
        }

        return result
    }

    @Override
    boolean checkExecutability(ExecutionContext context) {
        boolean result = super.checkExecutability(context)
        result &= checkBamFiles(context)
        return result
    }
}