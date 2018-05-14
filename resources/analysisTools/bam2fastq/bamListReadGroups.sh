#!/usr/bin/env bash
#
# Copyright (c) 2018 DKFZ.
#
# Distributed under the MIT License (license terms are at https://github.com/TheRoddyWMS/BamToFastqPluginLICENSE.txt).
#
set -ue

## Always return a default read group, in case the file has no read groups annotated. This ensures that Roddy will create appropriate directories.
## But we need to make sure that there is no 'default' group already in the BAM header!
assertNoDefaultReadGroup() {
    declare -a groups=($@)
    if (echo "${groups[@]}" | grep -w default); then
        echo "BAM mentions a 'default' read group in its header. This clashes with the default read-group name in Biobambam"
        exit 2
    fi
}



if [[ $($TOOL_BAM_IS_COMPLETE "$BAMFILE") == "OK" ]]; then
    declare -a groups=$($SAMTOOLS_BINARY view -H "${BAMFILE:?No input file given}" | grep -P '^@RG\s' | perl -ne 's/^\@RG\s+ID:(\S+).*?$/$1/; print' 2> /dev/null)
    assertNoDefaultReadGroup "${groups[@]}"
    echo "${groups[@]}"
    echo "default"
else
    echo "BAM sanity check failed" > /dev/stderr
    exit 1
fi

