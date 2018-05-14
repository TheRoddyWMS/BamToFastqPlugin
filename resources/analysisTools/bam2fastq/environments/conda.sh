#/usr/bin/env bash
#
# Copyright (c) 2018 DKFZ.
#
# Distributed under the MIT License (license terms are at https://github.com/TheRoddyWMS/BamToFastqPlugin/blob/master/LICENSE.txt
#

source activate "${condaEnvironmentName:?No condaEnvironmentName defined}"
if [[ $? -ne 0 ]]; then
    throw 200 "Error activating the conda environment '$condaEnvironmentName'"
fi

export SAMTOOLS_BINARY=samtools
export PICARD_BINARY=picard
export JAVA_BINARY=java
export MBUFFER_BINARY=mbuffer
export CHECKSUM_BINARY=md5sum
export PERL_BINARY=perl
export BIOBAMBAM_BAM2FASTQ_BINARY=bamtofastq