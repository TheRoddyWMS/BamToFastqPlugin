#/usr/bin/env bash

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