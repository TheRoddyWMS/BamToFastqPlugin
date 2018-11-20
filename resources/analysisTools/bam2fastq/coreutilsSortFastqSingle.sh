#!/usr/bin/env bash
#
# Copyright (c) 2018 DKFZ.
#
# Distributed under the MIT License (license terms are at https://github.com/TheRoddyWMS/BamToFastqPlugin/blob/master/LICENSE.txt).
#

# FILENAME_FASTQ: Path of the input FASTQ to process.
# FILENAME_SORTED_FASTQ: Path of the unsorted output FASTQ.
# checkFastqMd5: Create MD5 file of output FASTQs


## NOTE: Single-end reads may also occur in an otherwise paired-end bam and are produced by bam2fastq if
##       unpairedReads=true.

source "$TOOL_WORKFLOW_LIB"

printInfo
set -o pipefail
set -uvex
# export PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

sortFastq() {
    local infile="${1:-/dev/stdin}"
    local outfile="${2:-/dev/stdout}"
    local sourceCommand="cat"
    if [[ "${compressIntermediateFastqs:-true}" ]]; then
        sourceCommand="gunzip -c"
    fi
    $sourceCommand "$infile" \
        | fastqLinearize \
        | sortLinearizedFastqStream $(basename "$infile") \
        | fastqDelinearize \
        | gzip \
        | md5File "$outfile.md5" \
        > "$outfile" \
        & registerPid \
        || throw 1 "Error linearization/sorting/delinearization"
}

sortFastqWithMd5Check() {
    local infile="${1:?No input FASTQ file to sort}"
    local outfile="${2:?No output FASTQ file}"
    local referenceMd5File="$infile.md5"
    if [[ ! -r "$referenceMd5File" ]]; then
        throw 50 "Cannot read MD5 file '$referenceMd5File'"
    else
        local tmpInputMd5=$(createTmpFile $(tmpBaseFile "$infile")".md5.check")
        cat "$infile" \
            | md5File "$tmpInputMd5" \
            | sortFastq /dev/stdin "$outfile" \
            && \
            checkMd5Files "$referenceMd5File" "$tmpInputMd5" \
            & registerPid \
            || throw 8 "Error sorting & md5 check"
    fi
}

setUp_BashSucksVersion

tmpSortedFastq="$FILENAME_SORTED_FASTQ.tmp"

if [[ "${checkFastqMd5:-false}" == true && "${converter:-biobambam}" == "picard" ]]; then
    sortFastqWithMd5Check "$FILENAME_FASTQ" "$tmpSortedFastq"
else
    sortFastq "$FILENAME_FASTQ" "$tmpSortedFastq"
fi

waitForAll_BashSucksVersion

sleep 5    # Wait for network filesystem delays

mv "$tmpSortedFastq" "$FILENAME_SORTED_FASTQ" || throw 35 "Could not move '$tmpSortedFastq' to '$FILENAME_SORTED_FASTQ'"
mv "$tmpSortedFastq.md5" "$FILENAME_SORTED_FASTQ.md5" || throw 35 "Could not move '$tmpSortedFastq.md5' to '$FILENAME_SORTED_FASTQ.md5'"

cleanUp_BashSucksVersion
