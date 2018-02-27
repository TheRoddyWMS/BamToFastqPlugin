# BamToFastqPlugin

The plugin contains a workflow for converting multi-read-group BAMs into name-sorted FASTQs. The name-sorting is a time-consuming step that however ensures that tools like BWA, which estimate parameters from batches of reads, unbiased results (consider estimates of e.g. insert size depending on the genomic regions).

Basically two simple steps are taken. First the BAM is converted to one or multiple FASTQs, each with the order of reads exactly as in the BAM (e.g. position-sorted). Then the FASTQs are sorted by FASTQ entry name.

# Software Requirements

