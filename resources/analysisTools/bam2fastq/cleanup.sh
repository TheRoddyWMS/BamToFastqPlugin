#!/usr/bin/env bash
#
# Copyright (c) 2018 DKFZ.
#
# Distributed under the MIT License (license terms are at https://github.com/TheRoddyWMS/BamToFastqPlugin/LICENSE.txt).
#

# Truncate all unsorted fastqs to empty files. The modification timestamp is changed.

declare -a FILENAME_UNSORTED_FASTQ="$FILENAME_UNSORTED_FASTQ"

for f in "${FILENAME_UNSORTED_FASTQ[@]}"; do
    truncate -c -s 0 "$f"
done