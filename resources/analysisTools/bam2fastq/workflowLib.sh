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
    shift
    assertNonEmpty "$bufferSize" "No buffer size defined for mbuf()" || return $?
    "$MBUFFER_BINARY" -m "$bufferSize" -q -l /dev/null ${@}
}

registerPid() {
    local pid="${1:-$!}"
    declare -gax pids=(${pids[@]} $pid)
}

registerTmpFile() {
    local tmpFile="${1:?No temporary file name to register}"
    declare -gax tmpFiles=(${tmpFiles[@]} "$tmpFile")
}

waitForAll() {
    jobs
    wait ${pids[@]}
    pids=()
}

cleanUp() {
    if [[ -v tmpFiles && ${#tmpFiles} -gt 0 ]]; then
        # Bash sucks, even 4.4. An empty array does not exist! So if there are no tempfiles, then there is no array and set -u will show an error!
        rm ${tmpFiles[@]}
    fi
}

setUp() {
    declare -g -a -x tmpFiles=()
    declare -g -a -x pids=()
}

tmpBaseFile() {
    local name="${1:?No filename given}"
    echo "$RODDY_SCRATCH"/$(basename "$name")
}

md5File() {
   local md5File="${1:?No MD5 filename given}"
   local inputFile="${2:-/dev/stdin}"
   local outputFile="${3:-/dev/stdout}"

   assertNonEmpty "$inputFile"  "inputFile not defined" || return $?
   assertNonEmpty "$outputFile" "outputFile not defined" || return $?

   local md5Fifo=$(tmpBaseFile "$md5File")".fifo"
   mkfifo "$md5Fifo"
   registerTmpFile "$md5Fifo"

   cat $md5Fifo \
        | md5sum \
        | cut -d ' ' -f 1 \
        > "$md5File" \
        & registerPid

   cat "$inputFile" \
        | mbuf 10m \
            -f -o "$md5Fifo" \
            -f -o "$outputFile" \
        & registerPid
}

checkMd5Files() {
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

compressionOption() {
    if [[ "${sortTmpCompressor:-}" != "" ]]; then
        echo "--compress-program \"$sortTmpCompressor\""
    fi
}

fastqLinearize() {
    paste - - - -
}

fastqDelinearize() {
    "$PERL_BINARY" -aF\\t -lne '$F[0] =~ s/^(\S+?)(?:\/\d)?(?:\s+.*)?$/$1/o; print join("\n", @F)'
}

sortLinearizedFastqStream() {
    local tmpFile="${1:?No tempfile prefix given}"
    if [[ "$sortFastqsWith" == "coreutils" ]]; then
        LC_ALL=C sort -t : -k 1d,1 -k 2n,2 -k 3d,3 -k 4n,7 -T "$tmpFile.sorting_tmp" $(compressionOption) -S "${sortMemory:-100m}"
    else
        throw 150 "Invalid value for sortFastqsWith: '$sortFastqsWith'"
    fi
}

eval "$WORKFLOWLIB___SHELL_OPTIONS"