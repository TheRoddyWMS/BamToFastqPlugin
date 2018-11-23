/*
 * Copyright (c) 2018 German Cancer Research Center (DKFZ).
 *
 * Distributed under the MIT License (https://opensource.org/licenses/MIT).
 */
package de.dkfz.roddy.bam2fastq

import spock.lang.Specification

class ReadGroupGroupTest extends Specification {

    def "AllReadGroupIds"() {
        when:
        def rgA = new ReadGroup<String>("a")
        def rgB = new ReadGroup<String>("b")
        def rgg1 = new ReadGroupGroup([])
        def rgg2 = new ReadGroupGroup([rgA, rgB])

        then:
        rgg1.allReadGroupIds() == []
        rgg2.allReadGroupIds() == [
                "a_R1", "a_R2", "a_U1", "a_U2", "a_S",
                "b_R1", "b_R2", "b_U1", "b_U2", "b_S",
        ]
    }

    def "Size"() {
        when:
        def rgg1 = new ReadGroupGroup([])
        def rgg2 = new ReadGroupGroup([
                new ReadGroup<String>("a"),
                new ReadGroup<String>("b")])
        then:
        rgg1.size() == 0
        rgg2.size() == 2
    }

    def "GetAt"() {
        when:
        def rgA = new ReadGroup<String>("a")
        def rgB = new ReadGroup<String>("b")
        def rgg1 = new ReadGroupGroup([])
        def rgg2 = new ReadGroupGroup([rgA, rgB])

        then:
        rgg2[0] == rgA
        rgg2["a"] == rgA
        rgg2[1] == rgB
        rgg2["b"] == rgB
    }

    def "GetAt throws with invalid index"() {
        given:
        def rgg1 = new ReadGroupGroup([])

        when:
        rgg1[0]

        then:
        IndexOutOfBoundsException ex1 = thrown()
    }

    def "GetAt throws with invalid read group name"() {
        given:
        def rgg1 = new ReadGroupGroup([new ReadGroup<String>("a")])

        when:
        rgg1["c"]

        then:
        IndexOutOfBoundsException ex2 = thrown()
        ex2.message == "Cannot access ReadGroup 'c'"
    }

    def "GetReadGroups"() {
        when:
        def rgA = new ReadGroup<String>("a")
        def rgB = new ReadGroup<String>("b")
        def rgg1 = new ReadGroupGroup([])
        def rgg2 = new ReadGroupGroup([rgA, rgB])

        then:
        rgg1.readGroups == []
        rgg2.readGroups == [rgA, rgB]
    }

    def "SetReadGroups prohibited"() {
        given:
        def rgA = new ReadGroup<String>("a")
        def rgB = new ReadGroup<String>("b")
        def rgg1 = new ReadGroupGroup([])

        when:
        rgg1.readGroups = [rgA, rgB]

        then:
        ReadOnlyPropertyException ex = thrown()
    }
}
