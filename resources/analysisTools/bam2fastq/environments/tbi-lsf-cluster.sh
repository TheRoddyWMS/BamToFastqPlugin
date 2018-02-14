#!/usr/bin/env bash
#
# Copyright (c) 2018 DKFZ.
#
# Distributed under the MIT License (license terms are at https://github.com/TheRoddyWMS/BamToFastqPluginLICENSE.txt).
#

module load samtools/"${SAMTOOLS_VERSION:?SAMTOOLS_VERSION undefined}"
module load picard/"${PICARD_VERSION:?PICARD_VERSION undefined}"
module load java/"${JAVA_VERSION:?JAVA_VERSION undefined}"
export SAMTOOLS_BINARY=samtools
export PICARD_BINARY=${TOOL_PICARD}
export JAVA_BINARY=java8
