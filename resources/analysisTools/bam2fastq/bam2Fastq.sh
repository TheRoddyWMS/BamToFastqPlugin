#!/usr/bin/env bash
#
# Copyright (c) 2018 DKFZ.
#
# Distributed under the MIT License (license terms are at https://github.com/TheRoddyWMS/BamToFastqPlugin/blob/master/LICENSE.txt).
#
#
# Environment variables:
#
# FILENAME_BAM:
#   input BAM file
#
# FILENAME_UNSORTED_FASTQ:
#   A bash array containing the filenames of the output files expected to be available after this script ran.
#   Note that this variable needs do be string, no true Bash-array, because exporting Bash arrays to sub-processes in dysfunctional.
#
# compressIntermediateResults:
#   Temporary files during sorting are compressed or not (gz), default: true
#
# PICARD_OPTIONS:
#   Additional options for picard.
#
# JAVA_BINARY:
#   Java binary name/path.
#
# JAVA_OPTIONS:
#   Defaults to JAVA_OPTS.
#
# excludedReadFlags:
#   space delimited list flags for reads to exclude during processing of: secondary, supplementary
#
# outputPerReadGroup:
#   Write separate FASTQs for each read group into $outputDir/$basename/ directory. Otherwise
#   create $outputDir/${basename}_r{1,2}.fastq{.gz,} files.
#
# writeUnpairedFastq:
#   Additionally write a FASTQ with unpaired reads. Otherwise no such file is written.

source "$TOOL_WORKFLOW_LIB"
printInfo
set -o pipefail
set -uvex

makeTempName() {
    local dir="${1:?Missing argument}"
    local baseName="${2:?Missing argument}"
    # We use a tmp. prefix because Picard depends on the .gz suffix for determining the compression.
    local tempName="$dir/tmp.$baseName"
    registerTmpFile "$tempName"
    echo "$tempName"
}

getFastqSuffix() {
    if [[ "$compressIntermediateFastqs" == true ]]; then
        compressionSuffix=".gz"
    else
        compressionSuffix=""
    fi
    echo "fastq${compressionSuffix}"
}

fastqForGroupIndex() {
    local fgindex="${1:?No filegroup index}"
    declare -a files=$(for fastq in ${FILENAME_UNSORTED_FASTQ[@]}; do
        echo "$fastq"
    done | grep --color=no "$fgindex")
    if [[ ${#files[@]} != 1 ]]; then
        throw 10 "Expected to find exactly 1 FASTQ for file-group index '$fgindex' -- found ${#files[@]}: ${files[@]}"
    fi
    echo "${files[0]}"
}

biobambamCompressIntermediateFastqs() {
    if [[ "$compressIntermediateFastqs" == true ]]; then
        echo 1
    else
        echo 0
    fi
}

checkExclusions() {
    declare -a flagList=($@)
    for flag in "${flagList[@]}"; do
       if [[ "$flag" != "secondary" && "$flag" != "supplementary" ]]; then
          throw 20 "Cannot set '$flag' flag."
       fi
    done
}

bamtofastqExclusions() {
    declare -a _excludedReadFlags=("${excludedReadFlags[@]:-}")
    checkExclusions "${_excludedReadFlags[@]}"
    stringJoin "," "${_excludedReadFlags[@]^^}"
}

processPairedEndWithReadGroupsBiobambam() {
    local baseName=$(basename "$FILENAME_BAM" .bam)

    ## Write all read-group FASTQs into a directory.
    local tmpReadGroupDir="${fastqOutputDirectory}/${baseName}_bam2fastq_temp"
    registerTmpFile "$tmpReadGroupDir"
    mkdir -p "$tmpReadGroupDir" || throw 1 "Could not create output directory '$tmpReadGroupDir'"

    ## Only process the non-supplementary (-F 0x800), primary (-F 0x100) alignments. BWA flags chimeric alignments as supplementary while the
    ## full-length reads are exactly the ones not flagged supplementary. See http://seqanswers.com/forums/showthread.php?t=40239
    ##
    ## Biobambam bam2fastq (2.0.87)
    ##
    ## * takes care of restricting to non-supplementary, primary reads
    ## * requires collation to produce files split by read-groups
    ##
    "$BIOBAMBAM_BAM2FASTQ_BINARY" \
        filename="$FILENAME_BAM" \
        T="$tmpReadGroupDir/$baseName.bamtofastq_tmp" \
        outputperreadgroup=1 \
        outputperreadgrouprgsm=1 \
        outputdir="$tmpReadGroupDir" \
        collate=1 \
        colsbs=268435456 \
        colhlog=19 \
        gz=$(biobambamCompressIntermediateFastqs) \
        outputperreadgroupsuffixF=_R1."$FASTQ_SUFFIX" \
        outputperreadgroupsuffixF2=_R2."$FASTQ_SUFFIX" \
        outputperreadgroupsuffixO=_U1."$FASTQ_SUFFIX" \
        outputperreadgroupsuffixO2=_U2."$FASTQ_SUFFIX" \
        outputperreadgroupsuffixS=_S."$FASTQ_SUFFIX" \
        outputperreadgrouprgsm=0 \
        exclude=$(bamtofastqExclusions)

    # Reads without group are assigned to 'default' group.

    ## Now make sure that the output files are renamed correctly.
    for readGroup in "${readGroups[@]}"; do
        ## TODO Also rescue O1, O2 (singleton "orphan" read 1/2), S (single-end reads) files.
        for read in R1 R2; do
            local srcName="$tmpReadGroupDir/${readGroup}_${read}.$FASTQ_SUFFIX"
            local fgindex="${readGroup}_${read}"
            local tgtName=$(fastqForGroupIndex "$fgindex")
            if [[ -f "$srcName" ]]; then
                ## The file for the "default" read group is only produced if reads exist that are not assigned to a group. Everything produced
                ## can be moved, though.
                mv "$srcName" "$tgtName" || throw 10 "Could not move file '$srcName' to '$tgtName'"
            else
                ## Furthermore, for read groups in the SAM header without reads, no FASTQ is produced. Such read group produce problems
                ## downstream. So here we create an empty dummy FASTQ. Note that this may include the 'default' read group that is added
                ## by "bamListReadGroups.sh".
                cat /dev/null | gzip -c - > "$tgtName"
            fi
        done
    done
}

samtoolsExclusions() {
    declare -a excludedReadFlagsArray=("${excludedReadFlags[@]:-}")
    checkExclusions "${excludedReadFlagsArray[@]}"
    declare exclusionFlag=0
    declare exclusionsString=$(stringJoin "," "${excludedReadFlagsArray[@]}")
    if (echo "$exclusionsString" | grep -wq "supplementary"); then
        let exclusionFlag=($exclusionFlag + 2048)
    fi
    if (echo "$exclusionsString" | grep -wq "secondary"); then
        let exclusionFlag=($exclusionFlag + 256)
    fi
    if [[ $exclusionFlag -gt 0 ]]; then
        echo "-F $exclusionFlag"
    fi
}

processPairedEndWithReadGroupsPicard() {
    local baseName=$(basename "$FILENAME_BAM" .bam)

    ## Write all read-group FASTQs into a directory.
    local tmpReadGroupDir="${fastqOutputDirectory}/${baseName}_bam2fastq_temp"
    registerTmpFile "$tmpReadGroupDir"
    mkdir -p "$tmpReadGroupDir" || throw 1 "Could not create output directory '$tmpReadGroupDir'"

    local PICARD_OPTIONS="$PICARD_OPTIONS COMPRESS_OUTPUTS_PER_RG=$compressIntermediateFastqs OUTPUT_PER_RG=true RG_TAG=${readGroupTag:-id} OUTPUT_DIR=${tmpReadGroupDir}"
    local JAVA_OPTIONS="${JAVA_OPTIONS:-$JAVA_OPTS}"
    ## Only process the non-supplementary (-F 0x800), primary (-F 0x100) alignments. BWA flags chimeric alignments as supplementary while the
    ## full-length reads are exactly the ones not flagged supplementary. See http://seqanswers.com/forums/showthread.php?t=40239.
    "$SAMTOOLS_BINARY" view -u $(samtoolsExclusions) "$FILENAME_BAM" \
        | "$PICARD_BINARY" $JAVA_OPTIONS SamToFastq $PICARD_OPTIONS INPUT=/dev/stdin

    ## Now make sure that the output files of Picard are renamed correctly.
    for readGroup in "${readGroups[@]}"; do
        for read in 1 2; do
            local srcName="$tmpReadGroupDir/${readGroup}_${read}.$FASTQ_SUFFIX"
            local fgindex="${readGroup}_R${read}"
            local tgtName=$(fastqForGroupIndex "$fgindex")
            if [[ -f "$srcName" ]]; then
                ## The file for the "default" read group is only produced if reads exist that are not assigned to a group. Everything produced
                ## can be moved, though.
                mv "$srcName" "$tgtName" || throw 10 "Could not move file '$srcName' to '$tgtName'"
            else
                ## Furthermore, for read groups in the SAM header without reads, no FASTQ is produced. Such read group produce problems
                ## downstream. So here we create an empty dummy FASTQ. Note that this may include the 'default' read group that Roddy adds
                ## See "bamListReadGroups.sh".
                cat /dev/null | gzip -c - > "$tgtName"
            fi
        done
    done
}


processPairedEndWithoutReadGroupsPicard() {
    local baseName=$(basename "$FILENAME_BAM" .bam)

    ## Extract the output directory from the first lane file path entered.
    local outputDir="$outputAnalysisBaseDirectory/${baseName}_temp"
    registerTmpFile "$outputDir"

    ## Write just 2-3 FASTQs, depending on whether unpairedFastq is true.
    ## We need to add the suffix here such that Picard automatically does the compression.
    local fastq1BaseName="${baseName}_r1.${FASTQ_SUFFIX}"
    local tmpFastq1=$(makeTempName "$outputDir" "$fastq1BaseName")
    local fastq2BaseName="${baseName}_r2.${FASTQ_SUFFIX}"
    local tmpFastq2=$(makeTempName "$outputDir" "$fastq2BaseName")
    local PICARD_OPTIONS="$PICARD_OPTIONS COMPRESS_OUTPUTS_PER_RG=$compressIntermediateFastqs FASTQ=$tmpFastq1 SECOND_END_FASTQ=$tmpFastq2"
    if [[ "${writeUnpairedFastq:-false}" == true ]]; then
        local fastq3BaseName="${baseName}_r3.${FASTQ_SUFFIX}"
        local tmpFastq3=$(makeTempName "$outputDir" "$fastq3BaseName")
        local PICARD_OPTIONS="$PICARD_OPTIONS UNPAIRED_FASTQ=$tmpFastq3"
    fi

    ## Only process the non-supplementary reads (-F 0x800). BWA flags all alternative alignments as supplementary while the full-length
    ## reads are exactly the ones not flagged supplementary.
    local JAVA_OPTIONS="${JAVA_OPTIONS:-$JAVA_OPTS}"
    "$SAMTOOLS_BINARY" view -u $(samtoolsExclusions) "$FILENAME_BAM" \
        | "$PICARD_BINARY" $JAVA_OPTIONS SamToFastq $PICARD_OPTIONS INPUT=/dev/stdin

    ## Now make sure that the output files of Picard are renamed correctly.
    mv "$tmpFastq1" "${FILENAME_UNSORTED_FASTQ[0]}" || throw 10 "Could not move file '$tmpFastq1' to '${FILENAME_UNSORTED_FASTQ[0]}'"
    mv "$tmpFastq2" "${FILENAME_UNSORTED_FASTQ[1]}" || throw 10 "Could not move file '$tmpFastq2' to '${FILENAME_UNSORTED_FASTQ[1]}'"
    if [[ "${writeUnpairedFastq:-false}" == true ]]; then
        mv "$tmpFastq3" "${FILENAME_UNSORTED_FASTQ[2]}" || throw 10 "Could not move file '$tmpFastq3' to '${FILENAME_UNSORTED_FASTQ[2]}'"
    fi
}

processSingleEndWithReadGroupsPicard() {
    throw 1 "processSingleEndWithReadGroups not implemented"
}

processSingleEndWithoutReadGroupsPicard() {
    throw 1 "processSingleEndWithoutReadGroups not implemented"
}



main() {
    ## See workflowLib.sh
    setUp_BashSucksVersion

    "$TOOL_BAM_IS_COMPLETE" "$FILENAME_BAM"

    # Re-Array the filenames variable (outputs). Bash does not transfer arrays properly to subprocesses. Therefore Roddy encodes arrays as strings
    # with enclosing parens. That is "(a b c)", with spaces as separators.
    declare -ax FILENAME_UNSORTED_FASTQ=${FILENAME_UNSORTED_FASTQ}
    declare -ax readGroups=${readGroups}

    FASTQ_SUFFIX=$(getFastqSuffix)


    if [[ "${pairedEnd:-true}" == true ]]; then
        if [[ "${outputPerReadGroup:-true}" == true ]]; then
            if [[ "$converter" == "picard" ]]; then
                processPairedEndWithReadGroupsPicard
            elif [[ "$converter" == "biobambam" ]]; then
                processPairedEndWithReadGroupsBiobambam
            else
                throw 10 "Unknown bam-to-fastq converter: '$converter'"
            fi
        else
            processPairedEndWithoutReadGroupsPicard
        fi
    else
        if [[ "${outputPerReadGroup:-true}" == true ]]; then
            processSingleEndWithReadGroupsPicard
        else
            processSingleEndWithoutReadGroupsPicard
        fi
    fi

    ## See workflowLib.sh
    cleanUp_BashSucksVersion
}



main
