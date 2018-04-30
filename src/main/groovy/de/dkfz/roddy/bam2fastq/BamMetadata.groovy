/*
 * Copyright (c) 2018 German Cancer Research Center (DKFZ).
 *
 * Distributed under the MIT License (license terms are at https://www.github.com/eilslabs/Roddy/LICENSE.txt).
 */
package de.dkfz.roddy.bam2fastq

class BamMetadata {

    final String bamFile
    final String dataSetId
    final List<String> readGroupNames

    BamMetadata(String dataSet, String bamFile, List<String> readGroupNames) {
        this.dataSetId = dataSet
        this.bamFile = bamFile
        this.readGroupNames = Collections.unmodifiableList(readGroupNames)
    }

}
