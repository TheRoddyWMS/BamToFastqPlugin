package de.dkfz.roddy.bam2fastq

import de.dkfz.roddy.StringConstants
import de.dkfz.roddy.config.RecursiveOverridableMapContainerForConfigurationValues

/*
 * Copyright (c) 2018 DKFZ - ODCF
 *
 * Distributed under the MIT License (license terms are at https://www.github.com/eilslabs/Roddy/LICENSE.txt).
 */
import de.dkfz.roddy.core.ExecutionContext
import groovy.transform.CompileStatic

@CompileStatic
class Config {

    public static final String FLAG_SPLIT_BY_READ_GROUP = "outputPerReadGroup"
    public static final String FLAG_SORT_FASTQS = "sortFastqs"
    public static final String FLAG_COMPRESS_INTERMEDIATE_FASTQS = "compressIntermediateFastqs"
    public static final String FLAG_PAIRED_END = "pairedEnd"
    public static final String FLAG_WRITE_UNPAIRED_FASTQ = "writeUnpairedFastq"
    public static final String CVALUE_BAMFILE_LIST = "bamfile_list"

    private RecursiveOverridableMapContainerForConfigurationValues configValues

    Config(ExecutionContext executionContext) {
        this.configValues = executionContext.getConfigurationValues()
    }

    private List<String> checkAndSplitListFromConfig(String listID) {
        String list = configValues.getString(listID, null)
        if(list)
            return list.split(StringConstants.SPLIT_SEMICOLON) as List<String>
        return []
    }

    List<String> getBamList() {
        return checkAndSplitListFromConfig(CVALUE_BAMFILE_LIST)
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

    boolean getWriteUnpairedFastq() {
        this.configValues.getBoolean(FLAG_WRITE_UNPAIRED_FASTQ, false)
    }
}