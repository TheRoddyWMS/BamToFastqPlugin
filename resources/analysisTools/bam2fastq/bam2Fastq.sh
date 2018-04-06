#!/usr/bin/env bash
#
# Copyright (c) 2018 DKFZ.
#
# Distributed under the MIT License (license terms are at https://github.com/TheRoddyWMS/BamToFastqPluginLICENSE.txt).
#
#
# Environment variables:
#
# FILENAME_BAM: input BAM file
# FILENAME_LANEFILES: A bash array containing the filenames of the output files expected to be available after this script ran.
#                     Note that this variable needs do be string, no true Bash-array, because exporting Bash arrays to sub-processes in dysfunctional.
# compressIntermediateResults: Temporary files during sorting are compressed or not (gz), default: true
# PICARD_OPTIONS: Additional options for picard.
# JAVA_BINARY: Java binary name/path.
# JAVA_OPTIONS: Defaults to JAVA_OPTS.
# outputPerReadGroup: Write separate FASTQs for each read group into $outputDir/$basename/ directory. Otherwise
#                     create $outputDir/${basename}_r{1,2}.fastq{.gz,} files.
# unpairedFastq: Additionally write a FASTQ with unpaired reads. Otherwise no such file is written.


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

processPairedEndWithReadGroups() {
    ## Write all read-group FASTQs into a directory.
    tmpReadGroupDir="$outputAnalysisBaseDirectory"/$(basename "$FILENAME_BAM")".fastq"
    registerTmpFile "$tmpReadGroupDir"
    mkdir -p "$tmpReadGroupDir" || throw 1 "Could not create output directory '$tmpReadGroupDir'"


    PICARD_OPTIONS="$PICARD_OPTIONS COMPRESS_OUTPUTS_PER_RG=$compressIntermediateFastqs OUTPUT_PER_RG=true RG_TAG=${readGroupTag:-id} OUTPUT_DIR=${tmpReadGroupDir}"
    JAVA_OPTIONS="${JAVA_OPTIONS:-$JAVA_OPTS}"
    ## Only process the non-supplementary reads (-F 0x800). BWA flags all alternative alignments as supplementary while the full-length
    ## reads are exactly the ones not flagged supplementary.
    "$SAMTOOLS_BINARY" view -u -F 0x800 "$FILENAME_BAM" \
        | "$PICARD_BINARY" $JAVA_OPTIONS SamToFastq $PICARD_OPTIONS INPUT=/dev/stdin

    ## Now make sure that the output files of Picard are renamed correctly.
    for readGroup in $(BAMFILE="${FILENAME_BAM}" "${TOOL_BAM_LIST_READ_GROUPS}"); do
        for read in 1 2; do
            srcName="$tmpReadGroupDir/${readGroup}_${read}.$FASTQ_SUFFIX"

            baseName=$(basename "$FILENAME_BAM" .bam)
            fgindex="${readGroup}_R${read}"
            ## Note that this corresponds to the filename pattern in the XML! We compose the output lane file, because we want to avoid
            ## that read groups are confused or that we have to parse the FILENAME_LANEFILES here.
            tgtName="$outputAnalysisBaseDirectory/${fgindex}_unsorted/${baseName}_${fgindex}.$FASTQ_SUFFIX"

            mv "$srcName" "$tgtName" || throw 10 "Could not move file '$srcName' to '$tgtName'"
        done
    done
}


processPairedEndWithoutReadGroups() {
    ## Extract the output directory from the first lane file path entered.
    outputDir=$(dirname "$outputAnalysisBaseDirectory")/$(basename "$FILENAME_BAM")".fastq"
    registerTmpFile "$outputDir"

    baseName=$(basename "$FILENAME_BAM" .bam)

    ## Write just 2-3 FASTQs, depending on whether unpairedFastq is true.
    ## We need to add the suffix here such that Picard automatically does the compression.
    fastq1BaseName="${baseName}_r1.${FASTQ_SUFFIX}"
    tmpFastq1=$(makeTempName "$outputDir" "$fastq1BaseName")
    fastq2BaseName="${baseName}_r2.${FASTQ_SUFFIX}"
    tmpFastq2=$(makeTempName "$outputDir" "$fastq2BaseName")
    PICARD_OPTIONS="$PICARD_OPTIONS COMPRESS_OUTPUTS_PER_RG=$compressIntermediateFastqs FASTQ=$tmpFastq1 SECOND_END_FASTQ=$tmpFastq2"
    if [[ "${unpairedFastq:-false}" == true ]]; then
        fastq3BaseName="${baseName}_r3.${FASTQ_SUFFIX}"
        tmpFastq3=$(makeTempName "$outputDir" "$fastq3BaseName")
        PICARD_OPTIONS="$PICARD_OPTIONS UNPAIRED_FASTQ=$tmpFastq3"
    fi

    ## Only process the non-supplementary reads (-F 0x800). BWA flags all alternative alignments as supplementary while the full-length
    ## reads are exactly the ones not flagged supplementary.
    JAVA_OPTIONS="${JAVA_OPTIONS:-$JAVA_OPTS}"
    "$SAMTOOLS_BINARY" view -u -F 0x800 "$FILENAME_BAM" \
        | "$PICARD_BINARY" $JAVA_OPTIONS SamToFastq $PICARD_OPTIONS INPUT=/dev/stdin

    ## Now make sure that the output files of Picard are renamed correctly.
    mv "$tmpFastq1" "${FILENAME_LANEFILES[0]}" || throw 10 "Could not move file '$tmpFastq1' to '${FILENAME_LANEFILES[0]}'"
    mv "$tmpFastq2" "${FILENAME_LANEFILES[1]}" || throw 10 "Could not move file '$tmpFastq2' to '${FILENAME_LANEFILES[1]}'"
    if [[ "${unpairedFastq:-false}" == true ]]; then
        mv "$tmpFastq3" "${FILENAME_LANEFILES[2]}" || throw 10 "Could not move file '$tmpFastq3' to '${FILENAME_LANEFILES[2]}'"
    fi
}

processSingleEndWithReadGroups() {
    throw 1 "processSingleEndWithReadGroups not implemented"
}

processSingleEndWithoutReadGroups() {
    throw 1 "processSingleEndWithoutReadGroups not implemented"
}



main() {
    setUp_BashSucksVersion

    # Re-Array the filenames variable (outputs). Bash does not transfer arrays properly to subprocesses. Therefore Roddy encodes arrays as strings.
    declare -ax FILENAME_LANEFILES=${FILENAME_LANEFILES}

    FASTQ_SUFFIX=$(getFastqSuffix)


    if [[ "${pairedEnd:-true}" == true ]]; then
        if [[ "${outputPerReadGroup:-true}" == true ]]; then
            processPairedEndWithReadGroups
        else
            processPairedEndWithoutReadGroups
        fi
    else
        if [[ "${outputPerReadGroup:-true}" == true ]]; then
            processSingleEndWithReadGroups
        else
            processSingleEndWithoutReadGroups
        fi
    fi

    cleanUp_BashSucksVersion
}



main
