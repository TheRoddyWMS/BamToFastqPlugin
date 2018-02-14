package de.dkfz.roddy.bam2fastq
/*
 * Copyright (c) 2018 DKFZ - ODCF
 *
 * Distributed under the MIT License (license terms are at https://www.github.com/eilslabs/Roddy/LICENSE.txt).
 */

import de.dkfz.b080.co.files.COConstants
import de.dkfz.roddy.config.Configuration
import de.dkfz.roddy.config.RecursiveOverridableMapContainerForConfigurationValues
import de.dkfz.roddy.core.ExecutionContext
import groovy.transform.CompileStatic

@CompileStatic
class Config {

    public static final String FLAG_SPLIT_BY_READ_GROUP = "outputPerReadGroup"
    public static final String FLAG_SORT_FASTQS = "sortFastqs"
    public static final String FLAG_COMPRESS_INTERMEDIATE_FASTQS = "compressIntermediateFastqs"
    public static final String FLAG_PAIRED_END = "pairedEnd"
    private RecursiveOverridableMapContainerForConfigurationValues configValues

    Config(ExecutionContext executionContext) {
        this.configValues = executionContext.getConfigurationValues()
    }

    boolean outputPerReadGroup() {
        this.configValues.getBoolean(this.FLAG_SPLIT_BY_READ_GROUP, true)
    }

    boolean sortFastqs() {
        this.configValues.getBoolean(this.FLAG_SORT_FASTQS, true)
    }

    boolean compressIntermediateFastqs() {
        this.configValues.getBoolean(this.FLAG_COMPRESS_INTERMEDIATE_FASTQS, true)
    }

    boolean pairedEnd() {
        this.configValues.getBoolean(this.FLAG_PAIRED_END, true)

    }
}