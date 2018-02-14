#!/usr/bin/env bash
#
# Copyright (c) 2018 DKFZ.
#
# Distributed under the MIT License (license terms are at https://github.com/TheRoddyWMS/BamToFastqPluginLICENSE.txt).
#

source "$TOOL_WORKFLOW_LIB"
printInfo
set -o pipefail
set -vux


# Read in two files/stream of paired FASTQ files and sort both together.
# Output is two name-sorted FASTQ files.
sortFastqPair () {
    local infile1="${1:?No input fastq 1 given}"
    local infile2="${2:?No input fastq 2 given}"
    local outfile1="${3:?No output fastq 1 given}"
    local outfile2="${4:?No output fastq 2 given}"

    local TMP_outfile1="$outfile1.sort.tmp"
    local TMP_outfile2="$outfile2.sort.tmp"

    local NP_infile1="$infile1.linearized.fifo"
    mkfifo "$NP_infile1"
    local NP_infile2="$infile2.linearized.fifo"
    mkfifo "$NP_infile2"

    local NP_outfile1="$outfile1.sorted.fifo"
    mkfifo "$NP_outfile1"
    local NP_outfile2="$outfile2.sorted.fifo"
    mkfifo "$NP_outfile2"


    fastqInputStreamLinearize "$infile1" "$NP_infile1" & fastq1Pid=$!
    fastqInputStreamLinearize "$infile2" "$NP_infile2" & fastq2Pid=$!

    ## No check here, that the two files have the some order!
    paste "$NP_infile1" "$NP_infile2" \
        | sortLinearizedFastqStream "$outfile1.sort.tmp" \
        | tee >(cut -f 1-4 > "$NP_outfile1") \
        | cut -f 5-8 > "$NP_outfile2" & sortPid=$!

    linearizedFastqOutputStream "$NP_outfile1" "$outfile1" & fastq1OutPid=$!
    linearizedFastqOutputStream "$NP_outfile2" "$outfile2" & fastq2OutPid=$!

    wait $fastq1Pid || throw 30 "Error reading FASTQ '$infile1'"
    wait $fastq2Pid || throw 31 "Error reading FASTQ '$infile2'"
    wait $sortPid   || throw 32 "Error sorting stream"
    wait $fastq1OutPid || throw 33 "Error writing FASTQ '$TMP_outfile1'"
    wait $fastq2OutPid || throw 34 "Error writing FASTQ '$TMP_outfile2'"

    mv "$TMP_outfile1" "$outfile1" || throw 41 "Could not move file '$TMP_outfile1'"
    mv "$TMP_outfile2" "$outfile2" || throw 42 "Could not move file '$TMP_outfile2'"
}


# Read in two files/stream of paired FASTQ files and sort both together. Additionally, compare the file streams
# MD5 sum with the one saved in the existing (!) .md5 files. Throw if the MD5 sums don't match or if an MD5
# is missing for an input file.
# Output is two name-sorted FASTQ files.
sortFastqPairWithMd5Check () {
    local infile1="${1:?No input fastq 1 given}"
    local infile2="${2:?No input fastq 2 given}"
    local outfile1="${3:?No output fastq 1 given}"
    local outfile2="${4:?No output fastq 2 given}"

    local referenceMd5File1="$infile1.md5"
    local referenceMd5File2="$infile2.md5"
    if [[ -r "$referenceMd5File1" && -r "$referenceMd5File2" ]]; then
        local tmpInputMd5_1="$infile1.md5.check"
        local tmpInputMd5_2="$infile2.md5.check"

        local NP_md5_1="$infile1.md5.fifo"
        mkfifo "$NP_md5_1"
        local NP_md5_2="$infile2.md5.fifo"
        mkfifo "$NP_md5_2"

        sortFastqPair "$NP_md5_1" "$NP_md5_2" "$outfile1" "$outfile2" & local sortPid=$!

        md5file "$infile1" "$tmpInputMd5_1" > "$NP_md5_1" & local md5pid1=$!
        md5file "$infile2" "$tmpInputMd5_2" > "$NP_md5_2" & local md5pid2=$!

        wait "$md5pid1" || throw 50 "MD5 check 1 failed on '$infile1'"
        wait "$md5pid2" || throw 50 "MD5 check 2 failed on '$infile2'"
        wait "$sortPid" || throw 50 "Sorting failed on '$infile1' and '$infile2'"
    else
        throw 100 "FASTQ '$infile1' or '$infile2' do not have a readable MD5 file '$referenceMd5File1' or '$referenceMd5File2'"
    fi
}


if [[ "${pairedEnd:-false}" == "false" ]]; then
    throw 255 "Oops, pairedEnd should be true. Check your plugin code."
fi

tmpSortedFastq1="$FILENAME_SORTED_FASTQ1.tmp"
tmpSortedFastq2="$FILENAME_SORTED_FASTQ2.tmp"

if [[ "${checkMd5:-false}" == true ]]; then
    sortFastqPairWithMd5Check "$FILENAME_FASTQ1" "$FILENAME_FASTQ2" "$tmpSortedFastq1" "$tmpSortedFastq2"
else
    sortFastqPair "$FILENAME_FASTQ1" "$FILENAME_FASTQ2" "$tmpSortedFastq1" "$tmpSortedFastq2"
fi

mv "$tmpSortedFastq1" "$FILENAME_SORTED_FASTQ1" || throw 35 "Could not move '$tmpSortedFastq1' to '$FILENAME_SORTED_FASTQ1'"
mv "$tmpSortedFastq2" "$FILENAME_SORTED_FASTQ2" || throw 36 "Could not move '$tmpSortedFastq2' to '$FILENAME_SORTED_FASTQ2'"

