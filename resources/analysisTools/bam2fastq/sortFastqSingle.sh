#!/usr/bin/env bash
#
# Copyright (c) 2018 DKFZ.
#
# Distributed under the MIT License (license terms are at https://github.com/TheRoddyWMS/BamToFastqPluginLICENSE.txt).
#

source ${CONFIG_FILE}
source "$TOOL_WORKFLOW_LIB"
printInfo
set -o pipefail
set -vux

sortFastq () {
    local infile="${1:?No input FASTQ}"
    local outfile="${2:?No output FASTQ}"
    fastqInputStreamLinearize "$infile" /dev/stdout \
        | sortLinearizedFastqStream \
        | linearizedFastqOutputStream /dev/stdin "$outfile" \
        || throw 101 "Error processing '$infile'"
}

sortFastqWithMd5Check () {
    local infile="${1:?No input FASTQ file to sort}"
    local outfile="${2:?No output FASTQ file}"
    local referenceMd5File="$infile.md5"
    if [[ ! -r "$referenceMd5File" ]]; then
        throw 50 "Cannot read MD5 file '$referenceMd5File'"
    else
        local tmpInputMd5="$infile.md5.check"
        cat "$infile" \
            | md5file /dev/stdin "$tmpInputMd5" \
            | sortFastq /dev/stdin "$outfile" \
            || throw 2 "Sorting '$infile' failed"
        checkMd5Files "$referenceMd5File" "$tmpInputMd5" \
            || throw 10 "Actual MD5 sum of unsorted input FASTQ did not match the expected MD5 for '$infile'"
        rm "$tmpInputMd5" || warn "Could not deleted '$tmpInputMd5'"
    fi
}


## NOTE: Single-end reads may also occur in an otherwise paired-end bam and are produced by bam2fastq if
##       unpairedReads=true.

tmpSortedFastq="$FILENAME_SORTED_FASTQ.tmp"
if [[ "${checkMd5:-false}" == true ]]; then
    sortFastqWithMd5Check "$FILENAME_FASTQ" "$tmpSortedFastq"
else
    sortFastq "$FILENAME_FASTQ" "$tmpSortedFastq"
fi
mv "$tmpSortedFastq" "$FILENAME_SORTED_FASTQ" || throw 35 "Could not move '$tmpSortedFastq' to '$FILENAME_SORTED_FASTQ'"