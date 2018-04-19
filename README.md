# BamToFastqPlugin

This [Roddy](https://github.com/TheRoddyWMS/Roddy) plugin contains a workflow for converting multi-read-group BAMs into name-sorted FASTQs. The name-sorting is a time-consuming step that however ensures that tools like BWA, which estimate parameters from batches of reads, produce unbiased results (consider estimates of e.g. insert size depending on the genomic regions).

Basically two simple steps are taken. First the BAM is converted to one or multiple FASTQs, each with the order of reads exactly as in the BAM (e.g. position-sorted). Then the FASTQs are sorted by FASTQ entry name.

# Software Requirements

The workflow has very few requirements. Beyond a working [Roddy](https://github.com/TheRoddyWMS/Roddy) installation, it uses Picard for the actual BAM-to-FASTQ conversion and coreutils sort for the name-sorting of fastqs.

## Conda

The workflow contains a description of a [Conda](https://conda.io/docs/) environment. A number of Conda packages from [BioConda](https://bioconda.github.io/index.html) are required. You should set up the Conda environment at a centralized position available from all compute hosts. 

First install the BioConda channels:
```
conda config --add channels r
conda config --add channels defaults
conda config --add channels conda-forge
conda config --add channels bioconda
```

Then install the environment

```
conda env create -n BamToFastqWorkflow -f $PATH_TO_PLUGIN_DIRECTORY/resources/analysisTools/bam2fastq/environments/conda.yml
```

The name of the Conda environment is arbitrary but needs to be consistent with the `condaEnvironmentName` variable. The default for that variable is set in `resources/configurationFiles/bam2fastq.xml`.
