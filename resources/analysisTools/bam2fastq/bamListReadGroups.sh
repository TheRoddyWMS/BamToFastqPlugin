#!/usr/bin/env bash
#
# Copyright (c) 2018 DKFZ.
#
# Distributed under the MIT License (license terms are at https://github.com/TheRoddyWMS/BamToFastqPluginLICENSE.txt).
#
set -ue

if [[ $($TOOL_BAM_IS_COMPLETE "$BAMFILE") == "OK" ]]; then
    $SAMTOOLS_BINARY view -H "${BAMFILE:?No input file given}" | grep -P '^@RG\s' | perl -ne 's/^\@RG\s+ID:(\S+).*?$/$1/; print' 2> /dev/null
else
    echo "BAM sanity check failed" > /dev/stderr
    exit 1
fi