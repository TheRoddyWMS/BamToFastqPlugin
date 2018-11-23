package de.dkfz.roddy.bam2fastq

import de.dkfz.roddy.knowledge.files.BaseFile
import de.dkfz.roddy.knowledge.files.FileGroup
import groovy.transform.CompileStatic

/** Streamlined handling of a set of ReadGroups. */
@CompileStatic
class ReadGroupGroup<T> {

    final List<ReadGroup<T>> readGroups = []

    ReadGroupGroup(final List<ReadGroup<T>> readGroups) {
        this.readGroups = readGroups
    }

    List<String> allReadGroupIds() {
        readGroups*.readGroupIds().flatten() as List<String>
    }

    Integer size() {
        readGroups.size()
    }

    ReadGroup<T> getAt(int i) {
        readGroups.get(i)
    }

    ReadGroup<T> getAt(String name) {
        def res = readGroups.find { it.name == name }
        if (res == null) {
            throw new IndexOutOfBoundsException("Cannot access ReadGroup '$name'")
        } else {
            res
        }
    }

}

