#!/usr/bin/env bash
#
# Copyright (c) 2018 DKFZ.
#
# Distributed under the MIT License (license terms are at https://github.com/TheRoddyWMS/BamToFastqPlugin/blob/master/LICENSE.txt).
#

source "$TOOL_WORKFLOW_LIB"
printInfo
set -o pipefail
set -uvex
# export PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

# Read in two files/stream of paired FASTQ files and sort both together.
# Output is two name-sorted FASTQ files.
sortFastqPair() {
    local infile1="${1:?No input fastq 1 given}"
    local infile2="${2:?No input fastq 2 given}"
    local outfile1="${3:?No output fastq 1 given}"
    local outfile2="${4:?No output fastq 2 given}"

    # Ensure the output file directories exist. They are probably the same but I don't bother checking that.
    ensureDirectoryExists $(dirname "$outfile1")
    ensureDirectoryExists $(dirname "$outfile2")

    local sourceCommand="cat"
    if [[ "${compressIntermediateFastqs:-true}" ]]; then
        sourceCommand="$compressor -d"
    fi

    local linear1Fifo=$(createFifo $(tmpBaseFile "$infile1")".linearized.fifo")
    local linear2Fifo=$(createFifo $(tmpBaseFile "$infile2")".linearized.fifo")
    local sorted1Fifo=$(createFifo $(tmpBaseFile "$outfile1")".sorted.fifo")
    local sorted2Fifo=$(createFifo $(tmpBaseFile "$outfile2")".sorted.fifo")

    $sourceCommand "$infile1" \
        | fastqLinearize \
        > "$linear1Fifo" \
        & registerPid \
        || throw 1 "Error linearization 1"

    $sourceCommand "$infile2" \
        | fastqLinearize \
        > "$linear2Fifo" \
        & registerPid \
        || throw 2 "Error linearization 2"


    cat "$sorted1Fifo" \
        | fastqDelinearize \
        | "$compressor" \
        | md5File "$outfile1.md5" \
        > "$outfile1" \
        & registerPid \
        || throw 3 "Error delinearization 1"

    cat "$sorted2Fifo" \
        | fastqDelinearize \
        | "$compressor" \
        | md5File "$outfile2.md5" \
        > "$outfile2" \
        & registerPid \
        || throw 4 "Error delinearization 2"

    # Note that this temporary file directory must not be node-local. It contains too much data.
    local sortTmp=$(dirname "$outfile1")"/sort_tmp"
    mkdir -p "$sortTmp"
    registerTmpFile "$sortTmp"
    registerTmpFile "$sortTmp/*"

    ## TODO Check here that the two files have the some order (just check the two ID columns 1 == 5)
    paste "$linear1Fifo" "$linear2Fifo" \
        | sortLinearizedFastqStream "$sortTmp" \
        | mbuf 100m \
            -f -o >(cut -f 1-4 > "$sorted1Fifo") \
            -f -o >(cut -f 5-8 > "$sorted2Fifo") \
        & registerPid \
        || throw 5 "Error sorting/splitting"

}

# Read in two files/stream of paired FASTQ files and sort both together. Additionally, compare the file streams
# MD5 sum with the one saved in the existing (!) .md5 files. Throw if the MD5 sums don't match or if an MD5
# is missing for an input file.
# Output is two name-sorted FASTQ files.
sortFastqPairWithMd5Check() {
    local infile1="${1:?No input fastq 1 given}"
    local infile2="${2:?No input fastq 2 given}"
    local outfile1="${3:?No output fastq 1 given}"
    local outfile2="${4:?No output fastq 2 given}"

    local referenceMd5File1="$infile1.md5"
    local referenceMd5File2="$infile2.md5"
    if [[ -r "$referenceMd5File1" && -r "$referenceMd5File2" ]]; then

        local tmpBase1=$(tmpBaseFile "$infile1")
        local tmpBase2=$(tmpBaseFile "$infile2")

        local infile1Fifo=$(createFifo "$tmpBase1.fifo")
        local infile2Fifo=$(createFifo "$tmpBase2.fifo")

        local tmpMd5File1=$(createTmpFile "$tmpBase1.md5.check")
        local tmpMd5File2=$(createTmpFile "$tmpBase2.md5.check")

        cat "$infile1" \
            | md5File "$tmpMd5File1.infile" \
            > "$infile1Fifo" \
            & registerPid \
            || throw 6 "Error md5 2"

        cat "$infile2" \
            | md5File "$tmpMd5File2.infile" \
            > "$infile2Fifo" \
            & registerPid \
            || throw 7 "Error md5 2"

        sortFastqPair "$infile1Fifo" "$infile2Fifo" "$outfile1" "$outfile2" \
            && checkMd5Files "$referenceMd5File1" "$tmpMd5File1" \
            && checkMd5Files "$referenceMd5File2" "$tmpMd5File2" \
            & registerPid \
            || throw 8 "Error sorting & md5-check"

    else
        throw 100 "FASTQ '$infile1' or '$infile2' do not have both a readable MD5 file '$referenceMd5File1' or '$referenceMd5File2'"
    fi
}


if [[ "${pairedEnd:-false}" == "false" ]]; then
    throw 255 "Oops, pairedEnd should be true. Check your plugin code."
fi

setUp_BashSucksVersion

tmpSortedFastq1="$FILENAME_SORTED_FASTQ1.tmp"
tmpSortedFastq2="$FILENAME_SORTED_FASTQ2.tmp"

if [[ "${checkFastqMd5:-false}" == true && "${converter:-biobambam}" == "picard" ]]; then
    sortFastqPairWithMd5Check "$FILENAME_FASTQ1" "$FILENAME_FASTQ2" "$tmpSortedFastq1" "$tmpSortedFastq2"
else
    sortFastqPair "$FILENAME_FASTQ1" "$FILENAME_FASTQ2" "$tmpSortedFastq1" "$tmpSortedFastq2"
fi

waitForRegisteredPids_BashSucksVersion

waitForFile "$tmpSortedFastq1"
mv "$tmpSortedFastq1"     "$FILENAME_SORTED_FASTQ1"     || throw 35 "Could not move '$tmpSortedFastq1' to '$FILENAME_SORTED_FASTQ1'"
mv "$tmpSortedFastq1.md5" "$FILENAME_SORTED_FASTQ1.md5" || throw 35 "Could not move '$tmpSortedFastq1.md5' to '$FILENAME_SORTED_FASTQ1.md5'"

waitForFile "$tmpSortedFastq2"
mv "$tmpSortedFastq2"      "$FILENAME_SORTED_FASTQ2"    || throw 36 "Could not move '$tmpSortedFastq2' to '$FILENAME_SORTED_FASTQ2'"
mv "$tmpSortedFastq2.md5" "$FILENAME_SORTED_FASTQ2.md5" || throw 35 "Could not move '$tmpSortedFastq2.md5' to '$FILENAME_SORTED_FASTQ2.md5'"

cleanUp_BashSucksVersion