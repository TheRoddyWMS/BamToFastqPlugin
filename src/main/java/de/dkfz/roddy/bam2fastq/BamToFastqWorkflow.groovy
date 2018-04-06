package de.dkfz.roddy.bam2fastq

import de.dkfz.b080.co.common.BasicCOProjectsRuntimeService
import de.dkfz.b080.co.files.BasicBamFile

/*
 * Copyright (c) 2018 DKFZ - ODCF
 *
 * Distributed under the MIT License (license terms are at https://www.github.com/eilslabs/Roddy/LICENSE.txt).
 */
import de.dkfz.roddy.core.ExecutionContext
import de.dkfz.roddy.core.ExecutionContextError
import de.dkfz.roddy.core.Workflow
import de.dkfz.roddy.knowledge.files.BaseFile
import de.dkfz.roddy.knowledge.files.FileGroup
import de.dkfz.roddy.tools.LoggerWrapper
import groovy.transform.CompileStatic
import sun.reflect.generics.reflectiveObjects.NotImplementedException

import java.util.logging.Level

@CompileStatic
class BamToFastqWorkflow extends Workflow {

    public static final LoggerWrapper logger = LoggerWrapper.getLogger("BamToFastqWorkflow")

    private List<BasicBamFile> bamFiles = []

    public static final String TOOL_BAM_LIST_READ_GROUPS = "bamListReadGroups"
    public static final String TOOL_BAM2FASTQ = "bam2fastq"
    public static final String TOOL_SORT_FASTQ_SINGLE = "sortFastqSingle"
    public static final String TOOL_SORT_FASTQ_PAIR = "sortFastqPair"

    /**
     * Return a list of read-groups identifiers from a bam
     * @param context
     * @param bamfileName
     */
    private final synchronized Map<String,List<String>> cachedBamFileLists = [:]
    List<String> listReadGroups(ExecutionContext context, String bamfileName) {
        String dataSetId = context.dataSet.id
        if (!cachedBamFileLists.containsKey(dataSetId)) {
            cachedBamFileLists[dataSetId] = callSynchronized(context, TOOL_BAM_LIST_READ_GROUPS, ["BAMFILE": bamfileName] as Map<String, Object>)
        }
        return cachedBamFileLists[dataSetId]
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
            def rgFileIndicesParameter = readGroups.collect { String rg -> [rg + "_R1", rg + "_R2"] }.flatten() as List<String>
            return callWithOutputFileGroup(TOOL_BAM2FASTQ, controlBam, rgFileIndicesParameter)
        } else {
            throw new NotImplementedException()
        }
    }

    void sortFastqs(Config cfg, String readGroup, BaseFile fastq1, BaseFile fastq2 = null, BaseFile fastq3 = null) {
        assert(fastq1 != fastq2)
        assert(fastq1 != fastq3)
        assert(fastq2 == null || fastq2 != fastq3)
        if (cfg.pairedEnd) {
            if (!cfg.unpairedFastq) {
                call(TOOL_SORT_FASTQ_PAIR, fastq1, fastq2, [readGroup: readGroup])
            } else {
                throw new NotImplementedException()
            }
        } else {
            call(TOOL_SORT_FASTQ_PAIR, fastq1, [readGroup: readGroup])
        }
    }

    @Override
    boolean setupExecution(ExecutionContext context) {
        bamFiles = (context.runtimeService as BasicCOProjectsRuntimeService).getAllBamFiles(context)
        return bamFiles.size() > 0
    }

    @Override
    boolean execute(ExecutionContext context) {
        Config cfg = new Config(context)

        for (BasicBamFile basicBamFile : bamFiles) {

            if (cfg.outputPerReadGroup) {
                List<String> readGroups = listReadGroups(context, basicBamFile.absolutePath)
                if (!readGroups) {
                    context.addErrorEntry(ExecutionContextError.EXECUTION_NOINPUTDATA.expand("Bam file ${basicBamFile.path} does not contain any readgroup.", Level.WARNING))
                    continue
                }
                FileGroup out = bam2fastq(cfg, basicBamFile, readGroups)

                if (cfg.sortFastqs) {
                    for (int i = 0; i < readGroups.size(); i++) {
                        this.sortFastqs(cfg, readGroups[i], out[i * 2], out[i * 2 + 1]) // All paired end, sorted by ReadGroup.
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

    protected boolean checkBamFiles(ExecutionContext context) {
        if (!bamFiles) {
            context.addErrorEntry(ExecutionContextError.EXECUTION_NOINPUTDATA.expand("Did not find any BAM files."))
            return false
        }
        return bamFiles.collect { file ->
            context.fileIsAccessible(file.path)
        }.inject { res, i -> res && i }
    }

    @Override
    boolean checkExecutability(ExecutionContext context) {
        boolean result = super.checkExecutability(context)
        result &= checkBamFiles(context)
        return result
    }
}