#!/usr/bin/env bash
#
# Copyright (c) 2018 DKFZ.
#
# Distributed under the MIT License (license terms are at https://github.com/TheRoddyWMS/BamToFastqPlugin/blob/master/LICENSE.txt
#

module load bash/"${BASH_VERSION:?BASH_VERSION undefined}"
module load samtools/"${SAMTOOLS_VERSION:?SAMTOOLS_VERSION undefined}"
module load picard/"${PICARD_VERSION:?PICARD_VERSION undefined}"
module load java/"${JAVA_VERSION:?JAVA_VERSION undefined}"

export SAMTOOLS_BINARY=samtools
export PICARD_BINARY=picard
export JAVA_BINARY=java8
export MBUFFER_BINARY=mbuffer
export PERL_BINARY=perl
