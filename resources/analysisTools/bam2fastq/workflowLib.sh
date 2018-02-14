#!/usr/bin/env bash
#
# Copyright (c) 2018 DKFZ.
#
# Distributed under the MIT License (license terms are at https://github.com/TheRoddyWMS/BamToFastqPluginLICENSE.txt).
#

source "$TOOL_BASH_LIB"

WORKFLOWLIB___SHELL_OPTIONS=$(set +o)
set +o verbose
set +o xtrace


mbuf () {
    local bufferSize="$1"
    assertNonEmpty "$1" "No buffer size defined for mbuf()" || return $?
    "$MBUFFER_BINARY" -m "$bufferSize" -q -l /dev/null
}


md5File () {
   local inputFile="${1-/dev/stdin}"
   local outputFile="${2-/dev/stdout}"
   assertNonEmpty "$inputFile"  "inputFile not defined" || return $?
   assertNonEmpty "$outputFile" "outputFile not defined" || return $?
   cat "$inputFile" \
        | ${CHECKSUM_BINARY} \
        | cut -d ' ' -f 1 \
        > "$outputFile"
}

checkMd5Files () {
    local referenceFile="${1}"
    assertNonEmpty "$referenceFile" "No reference MD5 file given"
    local queryMd5File="$2"
    assertNonEmpty "$queryMd5File" "No query MD5 file given"
    referMd5=$(cat "$referenceMd5File" | cut -f 1 -d ' ')
    queryMd5=$(cat "$queryMd5File" | cut -f 1 -d ' ')
    if [[ "$referMd5" != "$queryMd5" ]]; then
        throw 10 "Reference MD5 in '$referenceMd5File' did not match actual MD5"
    fi
}

compressionOption () {
    if [[ "$sortTmpCompressor" == "" ]]; then
        echo ""
    else
        echo "--compress-program '$sortTmpCompressor'"
    fi
}

fastqLinearize () {
    paste - - - -
}

fastqDelinearize () {
    perl -aF\\t -lne '$F[0] =~ s/^(\S+?)(?:\/\d)?(?:\s+.*)?$/$1/o; print join("\n", @F)'
}

fastqInputStreamLinearize () {
    local infile="${1:?No infile given}"
    assertFileReadable "$infile"
    local outfile="${2:?No outfile given}"
    assertFileWritable "$outfile"
    cat "$infile" \
        | mbuf 10m \
        | gunzip -c \
        | fastqLinearize \
        > "$outfile" \
        || throw 55 "Error linearizing FASTQ '$infile'"
}

sortLinearizedFastqStream () {
    local fastq="${1:?No FASTQ file given}"
    if [[ "$sortFastqsWith" == "coreutils" ]]; then
        LC_ALL=C sort -t : -k 1d,1 -k 2n,2 -k 3d,3 -k 4n,7 -T "$fastq.sorting_tmp" $(compressionOption) -S "${sortMemory:-100m}"
    else
        throw 150 "Invalid value for sortFastqsWith: '$sortFastqsWith'"
    fi
}

linearizedFastqOutputStream() {
    local infile="${1:?No infile given}"
    assertFileReadable "$infile"
    local outfile="${2:?no outfile given}"
    assertFileWritable "$outfile"
    cat "$infile" \
        | fastqDelinearize \
        | gzip -c - \
        | md5file /dev/stdin "$outfile.md5" \
        | mbuf 10m \
        > "$outfile" \
        || throw 56 "Error delinearizing and calculating MD5 sum for FASTQ '$infile'"
}

eval "$WORKFLOWLIB___SHELL_OPTIONS"