#!/usr/bin/env bash
#
# Copyright (c) 2018 DKFZ.
#
# Distributed under the MIT License (license terms are at https://github.com/TheRoddyWMS/BamToFastqPlugin/LICENSE.txt).
#

source "$TOOL_BASH_LIB"

WORKFLOWLIB___SHELL_OPTIONS=$(set +o)
set +o verbose
set +o xtrace


debug() {
    test "${debug:-false}" == "true"
}

mkFifo() {
    local fifo="${1:?No fifo name given}"
    if [[ ! -p "$fifo" ]]; then
        mkfifo "$fifo"
    fi
}

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
    # Note that the array is build in reversed order, which simplifies the deletion of nested directories.
    declare -gax tmpFiles=("$tmpFile" "${tmpFiles[@]}")
}

reverseArray() {
    local c=""
    for b in "$@"; do
        c="$b $c"
    done
    echo $c
}

# Bash sucks. An empty array does not exist! So if there are no tempfiles, then there is no array and set -u will show an error!
# Therefore we put a dummy value into the arrays.
waitForAll_BashSucksVersion() {
    jobs
    declare -a realPids=${pids[@]:1:${#pids[@]}}
    wait ${realPids[@]}
    pids=(dummy)
}
setUp_BashSucksVersion() {
    declare -g -a -x tmpFiles=(dummy)
    declare -g -a -x pids=(dummy)

    # Remove all registered temporary files upon exit
    trap cleanUp_BashSucksVersion EXIT
}
cleanUp_BashSucksVersion() {
    if !debug && [[ -v tmpFiles && ${#tmpFiles[@]} -gt 1 ]]; then
        # Bash sucks, even 4.4. An empty array does not exist! So if there are no tempfiles, then there is no array and set -u will show an error!
        # The following line deletes the last array element (non-sparse arrays), which is the 'dummy' value.
        for f in ${tmpFiles[@]}; do
            if [[ "$f" == "dummy" ]]; then
                continue
	        elif [[ -d "$f" ]]; then
                rmdir "$f"
            elif [[ -e "$f" ]]; then
                rm "$f"
            fi
        done
        tmpFiles=(dummy)
    fi
}

# These versions only works with Bash >4.4. Prior version do not really declare the array variables with empty values and set -u results in error message.
waitForAll() {
    jobs
    wait ${pids[@]}
    pids=()
}
setUp() {
    declare -g -a -x tmpFiles=()
    declare -g -a -x pids=()
}
cleanUp() {
    if !debug && [[ -v tmpFiles && ${#tmpFiles[@]} -gt 0 ]]; then
        for f in "${tmpFiles[@]}"; do
            if [[ -d "$f" ]]; then
                rmdir "$f"
            elif [[ -e "$f" ]]; then
                rm "$f"
            fi
        done
        tmpFiles=()
    fi
}


tmpBaseFile() {
    local name="${1:?No filename given}"
    echo "$RODDY_SCRATCH"/$(basename "$name")
}

createFifo() {
    local name="${1:?No FIFO name given}"
    mkFifo "$name"
    registerTmpFile "$name"
    echo "$name"
}

createTmpFile() {
    local name="${1:?No tempfile name given}"
    registerTmpFile "$name"
    echo "$name"
}

md5File() {
   local md5File="${1:?No MD5 filename given}"
   local inputFile="${2:-/dev/stdin}"
   local outputFile="${3:-/dev/stdout}"

   assertNonEmpty "$inputFile"  "inputFile not defined" || return $?
   assertNonEmpty "$outputFile" "outputFile not defined" || return $?

   local md5Fifo=$(tmpBaseFile "$md5File")".fifo"
   mkFifo "$md5Fifo"
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
    if [[ "${sortCompressor:-}" != "" ]]; then
        echo "--compress-program" $sortCompressor
    fi
}

fastqLinearize() {
    paste - - - -
}

fastqDelinearize() {
    "$PERL_BINARY" -aF\\t -lne '$F[0] =~ s/^(\S+?)(?:\/\d)?(?:\s+.*)?$/$1/o; print join("\n", @F)'
}

sortLinearizedFastqStream() {
    local tmpDir="${1:?No temporary directory prefix given}"
    if [[ "$sortFastqsWith" == "coreutils" ]]; then
        LC_ALL=C sort -t : -k 1d,1 -k 2n,2 -k 3d,3 -k 4n,4 -k 5n,5 -k 6n,6 -k 7n,7 -T "$tmpDir" $(compressionOption) --parallel=${sortThreads:-1} -S "${sortMemory:-100m}"
    else
        throw 150 "Invalid value for sortFastqsWith: '$sortFastqsWith'"
    fi
}

eval "$WORKFLOWLIB___SHELL_OPTIONS"