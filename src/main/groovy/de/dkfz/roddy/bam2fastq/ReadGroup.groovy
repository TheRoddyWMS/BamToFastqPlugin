package de.dkfz.roddy.bam2fastq

import de.dkfz.roddy.knowledge.files.BaseFile
import groovy.transform.CompileStatic

@CompileStatic
enum ReadFileType {
    READ1('R1', 0),
    READ2('R2', 1),
    UNMATCHED_READ1('U1', 2),
    UNMATCHED_READ2('U2', 3),
    SINGLETON('S', 4),

    final String shortCut
    final Integer index

    private ReadFileType(String shortCut, Integer index) {
        this.shortCut = shortCut
        this.index = index
    }

}


@CompileStatic
class ReadGroup<T> {

    final String name
    final protected Map<ReadFileType, T> files

    ReadGroup(String name, Map<ReadFileType, T> files) {
        this.name = name
        this.files = files
    }

    ReadGroup(String name) {
        this.name = name
        files = ReadFileType.values().collectEntries { type -> new MapEntry(type, null) } as LinkedHashMap<ReadFileType, T>
    }

    List<String> readGroupIds() {
        ReadFileType.values().collect { ReadFileType rft -> readGroupId(rft) }
    }

    String readGroupId(ReadFileType type) {
        name + '_' + type.shortCut
    }

    /** Functional interface function doing a (shallow-)copy-on-write */
    ReadGroup<T> updatedFile(ReadFileType type, T newFile) {
        Map<ReadFileType, T> newFiles = files.collectEntries { iterType, oldFile ->
            new MapEntry(iterType, type == iterType ? newFile : oldFile)
        } as LinkedHashMap<ReadFileType, T>
        ReadGroup newGroup = new ReadGroup(name, newFiles)
        newGroup
    }

    T getAt(ReadFileType type) {
        files[type]
    }

    String toString() {
        "readGroup:$name"
    }

}