#!/usr/bin/env bash
#
# Copyright (c) 2018 DKFZ.
#
# Distributed under the MIT License (license terms are at https://github.com/TheRoddyWMS/BamToFastqPluginLICENSE.txt).
#
#
# Environment variables:
#
# FILENAME_LANEFILES: A bash array containing all lane files which are expected to be available after this script ran.
# FILENAME_BAM: input BAM file
# compressIntermediateResults: temporary files during sorting are compressed or not (gz), default: true
# PICARD_OPTIONS: additional options to picard. May be overridden by options added here.
# JAVA_BINARY: java binary name/path
# JAVA_OPTIONS: defaults to JAVA_OPTS.
# checkMd5: Create MD5 file of output FASTQs
# outputPerReadGroup: write separate FASTQs for each read group into $outputDir/$basename/ directory. Otherwise
#                     create $outputDir/${basename}_r{1,2}.fastq{.gz,} files.
# unpairedFastq: additionally write a FASTQ with unpaired reads. Otherwise no such file is written.


source "$TOOL_BASH_LIB"

set -uvex

# Re-Array the filenames variable, Bash does not transfer arrays properly to sub processes and the variable is exported in the wrapper.
declare -ax FILENAME_LANEFILES=${FILENAME_LANEFILES}

compressIntermediateFastqs="${compressIntermediateFastqs:-true}"
if [[ "$compressIntermediateFastqs" == true ]]; then
    compressionSuffix=".gz"
else
    compressionSuffix=""
fi
FASTQ_SUFFIX=".fastq${compressionSuffix}"

# Extract the output directory with the first lane file path entered.
outputDir=$(dirname "${FILENAME_LANEFILES[0]}" )
baseName=$(basename "${FILENAME_LANEFILES[0]}" .${FASTQ_SUFFIX})

JAVA_OPTIONS="${JAVA_OPTIONS:-$JAVA_OPTS}"

## Unfortunately, picard only packs the files, if they end in .gz. Therefore the temp-files have to use a different
## naming convention than a suffix.
declare -a coreFilenames=()

makeTempName() {
    local dir="${1:?Missing argument}"
    local baseName="${2:?Missing argument}"
    echo "$dir/tmp.$baseName"
}

makeFinalName() {
    local dir="${1:?Missing argument}"
    local baseName="${2:?Missing argument}"
    echo "$dir/$baseName"
}

## Set up the picard options. That's a bit involved, as it has to follow the involved picard logic.
PICARD_OPTIONS="$PICARD_OPTIONS COMPRESS_OUTPUTS_PER_RG=$compressIntermediateFastqs"
if [[ "${pairedEnd:-true}" == true ]]; then
    if [[ "${outputPerReadGroup:-true}" == true ]]; then
        ## Write all read-group FASTQs into a directory.
        coreFilenames=("$baseName")
        tmpDir=$(makeTempName "$outputDir" "$baseName")
        PICARD_OPTIONS="$PICARD_OPTIONS OUTPUT_PER_RG=$outputPerReadGroup RG_TAG=${readGroupTag:-id} OUTPUT_DIR=${tmpDir}"
        ## RoddyCore does not know anything about the temporary directory. Therefore we need to create it here.
        mkdir -p "$tmpDir" || throw 1 "Could not create output directory '$tmpDir'"
    else
        ## Write just 2-3 FASTQs, depending on whether unpairedFastq is true.
        fastq1="${baseName}_r1.${FASTQ_SUFFIX}"
        fastq2="${baseName}_r2.${FASTQ_SUFFIX}"
        coreFilenames=("$fastq1" "$fastq2")
        PICARD_OPTIONS="$PICARD_OPTIONS FASTQ=$(makeTempName "$outputDir" "$fastq1") SECOND_END_FASTQ=$(makeTempName "$outputDir" "$fastq2")"
        if [[ "${unpairedFastq:-false}" == true ]]; then
            fastq3="${baseName}.${FASTQ_SUFFIX}"
            coreFilenames=(${coreFilenames[@]} $fastq3)
            PICARD_OPTIONS="$PICARD_OPTIONS UNPAIRED_FASTQ=$(makeTempName "$outputDir" "$fastq3")"
        fi
    fi
else
    ## Write just a single FASTQ.
    fastq="${prefix}.${FASTQ_SUFFIX}"
    PICARD_OPTIONS="$PICARD_OPTIONS FASTQ=$(makeTempName "$outputDir" "$fastq}")"
    coreFilenames=("$fastq")
fi

#$JAVA_BINARY" "$JAVA_OPTIONS" -jar "$PICARD_JAR

## Only process the non-supplementary reads. BWA flags all alternative alignments as supplementary while the full-length
## reads are exactly the ones not flagged supplementary.
"$SAMTOOLS_BINARY" view -u -F 0x800 "$FILENAME_BAM" \
    | "$JAVA_BINARY" $JAVA_OPTIONS -jar "${TOOL_PICARD}" \
      SamToFastq \
      $PICARD_OPTIONS \
      INPUT=/dev/stdin

for name in ${coreFilenames[@]}; do
    srcName=$(makeTempName "$outputDir" "$name")
    tgtName=$(makeFinalName "$outputDir" "$name")
    mv "$srcName" "$tgtName" || throw 10 "Could not move file '$srcName' to '$tgtName'"
done
