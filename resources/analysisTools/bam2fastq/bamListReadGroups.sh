#!/usr/bin/env bash
#
# Copyright (c) 2018 DKFZ.
#
# Distributed under the MIT License (license terms are at https://github.com/TheRoddyWMS/BamToFastqPluginLICENSE.txt).
#
set -ue
$SAMTOOLS_BINARY view -H "${BAMFILE:?No input file given}" | grep -P '^@RG\s' | perl -ne 's/^\@RG\s+ID:(\S+).*?$/$1/; print'