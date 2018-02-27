package de.dkfz.roddy.bam2fastq

import de.dkfz.b080.co.common.WorkflowUsingMergedBams

/*
 * Copyright (c) 2018 DKFZ - ODCF
 *
 * Distributed under the MIT License (license terms are at https://www.github.com/eilslabs/Roddy/LICENSE.txt).
 */
import de.dkfz.b080.co.files.BasicBamFile
import de.dkfz.roddy.core.ExecutionContext
import de.dkfz.roddy.core.ExecutionContextError
import de.dkfz.roddy.knowledge.files.BaseFile
import de.dkfz.roddy.knowledge.files.FileGroup
import de.dkfz.roddy.tools.LoggerWrapper
import groovy.transform.CompileStatic

import java.util.logging.Level

@CompileStatic
class BamToFastqWorkflow extends WorkflowUsingMergedBams {

    public static final LoggerWrapper logger = LoggerWrapper.getLogger("BamToFastqWorkflow")

    public static final String TOOL_BAM_LIST_READ_GROUPS = "bamListReadGroups"
    public static final String TOOL_BAM2FASTQ = "bam2fastq"
    public static final String TOOL_SORT_FASTQ_SINGLE = "sortFastqSingle"
    public static final String TOOL_SORT_FASTQ_PAIR = "sortFastqPair"

    /**
     * Return a list of read-groups identifiers from a bam
     * @param context
     * @param bamfileName
     */
    List<String> listReadGroups(ExecutionContext context, String bamfileName) {
        return this.callSynchronized(context, this.TOOL_BAM_LIST_READ_GROUPS, ["BAMFILE": bamfileName] as Map<String, Object>)
    }

    String getFastqName(Config cfg, String prefix, String readGroup, String index) {
        String result = prefix + readGroup + "_r" + index + ".fastq"
        if (cfg.compressIntermediateFastqs())
            result += ".gz"
        return result
    }

    /**
     * Extract FASTQs from a BAM. This may be with or without read-groups. The names of the output files depend on the parameters.
     */
    FileGroup extractFastqsFromBam(Config config, BasicBamFile controlBam, List<String> readGroups) {
        // Now it depends if we have single or paired end data... Let's start with paired end and create proper indices for it.

        def rgFileIndicesParameter = readGroups.collect { String rg -> [rg + "_R1", rg + "_R2"] }.flatten() as List<String>
//        def readGroupsParameter = "READGROUPS='${readGroups.join(" ")}'"
        return callWithOutputFileGroup(TOOL_BAM2FASTQ, controlBam, rgFileIndicesParameter)
    }

    void sortFastqs(Config cfg, String readGroup, BaseFile fastq1, BaseFile fastq2) {
        String toolId = cfg.pairedEnd() ? TOOL_SORT_FASTQ_PAIR : TOOL_SORT_FASTQ_SINGLE
        call(toolId, fastq1, fastq2, [READGROUP: readGroup])
    }

    @Override
    boolean execute(ExecutionContext context) {
        BasicBamFile[] initialBamFiles = loadInitialBamFilesForDataset(context)
        if (!checkInitialFiles(context, initialBamFiles))
            return false

        Config cfg = new Config(context)

        for (BasicBamFile basicBamFile : initialBamFiles) {

            if (cfg.outputPerReadGroup()) {
                List<String> readGroups = listReadGroups(context, basicBamFile.absolutePath)
                if (!readGroups) {
                    context.addErrorEntry(ExecutionContextError.EXECUTION_NOINPUTDATA.expand("Bam file ${basicBamFile.path} does not contain any readgroup.", Level.WARNING))
                    continue;
                }
                FileGroup out = extractFastqsFromBam(cfg, basicBamFile, readGroups)

                if (cfg.sortFastqs()) {
                    for (int i = 0; i < readGroups.size(); i++) {
                        this.sortFastqs(cfg, readGroups[i], out[i * 2], out[i * 2 + 1]) // All paired end, sorted by ReadGroup.
                    }
                }
                println(out)

            } else {
//                FileGroup out = extractFastqsFromBam(cfg, basicBamFile)
//                if (cfg.sortFastqs())
//                    this.sortFastqs(cfg)
            }

            return true
        }
    }

    @Override
    protected boolean execute(ExecutionContext context, BasicBamFile bamControlMerged, BasicBamFile bamTumorMerged) {
        return false
    }
}