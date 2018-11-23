/*
 * Copyright (c) 2018 German Cancer Research Center (DKFZ).
 *
 * Distributed under the MIT License (https://opensource.org/licenses/MIT).
 */
package de.dkfz.roddy.bam2fastq

import spock.lang.Specification

class ReadGroupTest extends Specification {

    def "GetName"() {
        when:
        def rg = new ReadGroup("da group")
        then:
        rg.name == "da group"
    }


    def "long constructor"() {
        when:
        def rg = new ReadGroup("da group", [
            (ReadFileType.READ1) : "r1" ,
            (ReadFileType.READ2) : "r2" ,
            (ReadFileType.UNMATCHED_READ1) : "u1" ,
            (ReadFileType.UNMATCHED_READ2) : "u2" ,
            (ReadFileType.SINGLETON) : "s"
        ])
        then:
        rg[ReadFileType.READ1] == "r1"
        rg[ReadFileType.READ2] == "r2"
        rg[ReadFileType.UNMATCHED_READ1] == "u1"
        rg[ReadFileType.UNMATCHED_READ2] == "u2"
        rg[ReadFileType.SINGLETON] == "s"
    }

    def "ReadGroupIds"() {
        when:
        def rg = new ReadGroup("da group")
        then:
        rg.readGroupId(ReadFileType.READ1) == "da group_R1"
        rg.readGroupIds() == ReadFileType.values().collect { rg.readGroupId(it) }
    }

    def "UpdatedFile"() {
        given:
        def rg1 = new ReadGroup("da group", [(ReadFileType.READ1): "r1"])
        when:
        def rg2 = rg1.updatedFile(ReadFileType.READ1, "r1b")
        then:
        rg1 != rg2
        rg1[ReadFileType.READ1] == "r1"
        rg2[ReadFileType.READ1] == "r1b"
    }

    def "GetAt"() {
    }

}
