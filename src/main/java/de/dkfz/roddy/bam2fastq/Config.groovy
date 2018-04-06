package de.dkfz.roddy.bam2fastq
/*
 * Copyright (c) 2018 DKFZ - ODCF
 *
 * Distributed under the MIT License (license terms are at https://www.github.com/eilslabs/Roddy/LICENSE.txt).
 */
import de.dkfz.roddy.config.RecursiveOverridableMapContainerForConfigurationValues
import de.dkfz.roddy.core.ExecutionContext
import groovy.transform.CompileStatic

@CompileStatic
class Config {

    public static final String FLAG_SPLIT_BY_READ_GROUP = "outputPerReadGroup"
    public static final String FLAG_SORT_FASTQS = "sortFastqs"
    public static final String FLAG_COMPRESS_INTERMEDIATE_FASTQS = "compressIntermediateFastqs"
    public static final String FLAG_PAIRED_END = "pairedEnd"
    public static final String FLAG_UNPAIRED_FASTQ = "unpairedFastq"

    private RecursiveOverridableMapContainerForConfigurationValues configValues

    Config(ExecutionContext executionContext) {
        this.configValues = executionContext.getConfigurationValues()
    }

    boolean getOutputPerReadGroup() {
        this.configValues.getBoolean(FLAG_SPLIT_BY_READ_GROUP, true)
    }

    boolean getSortFastqs() {
        this.configValues.getBoolean(FLAG_SORT_FASTQS, true)
    }

    boolean getCompressIntermediateFastqs() {
        this.configValues.getBoolean(FLAG_COMPRESS_INTERMEDIATE_FASTQS, true)
    }

    boolean getPairedEnd() {
        this.configValues.getBoolean(FLAG_PAIRED_END, true)

    }

    boolean getUnpairedFastq() {
        this.configValues.getBoolean(FLAG_UNPAIRED_FASTQ, false)
    }
}