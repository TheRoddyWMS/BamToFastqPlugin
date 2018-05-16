# BamToFastqPlugin

This [Roddy](https://github.com/TheRoddyWMS/Roddy) plugin contains a workflow for converting multi-read-group BAMs into name-sorted FASTQs. The name-sorting is a time-consuming step that however ensures that tools like BWA, which estimate parameters from batches of reads, produce unbiased results (consider estimates of e.g. insert size depending on the genomic regions).

Basically two simple steps are taken. First the BAM is converted to one or multiple FASTQs, each with the order of reads exactly as in the BAM (e.g. position-sorted). Then the FASTQs are sorted by FASTQ entry name.

## Software Requirements

The workflow has very few requirements. Beyond a working [Roddy](https://github.com/TheRoddyWMS/Roddy) installation, it uses Picard for the actual BAM-to-FASTQ conversion and coreutils sort for the name-sorting of fastqs.

### Conda

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
conda env create -n BamToFastqPlugin -f $PATH_TO_PLUGIN_DIRECTORY/resources/analysisTools/bam2fastq/environments/conda.yml
```

The name of the Conda environment is arbitrary but needs to be consistent with the `condaEnvironmentName` variable. The default for that variable is set in `resources/configurationFiles/bam2fastq.xml`.

## Using the Workflow

In terms of Roddy "modes", the workflow has two targets, namely `run`/`rerun` to run the actual workflow and `cleanup` to remove the unsorted FASTQ files.

### Basic Config

A basic configuration may look like this:

```xml
<configuration configurationType="project" name="bam2fastq">

    <configurationvalues>
	<cvalue name="pairedEnd" value="true" type="boolean"/>
	<cvalue name="checkFastqMd5" value="false" type="boolean"/>
    </configurationvalues>

    <subconfigurations>
	<configuration name="any">
	    <availableAnalyses>
		<analysis id='convert' configuration='bam2fastqAnalysis'/>
	    </availableAnalyses>
	</configuration>
    </subconfigurations>

</configuration>
```

Have a look at the `resources/configurationFiles/bam2fastq.xml` file for a complete list of parameters. The most important options are:

* converter: Actual tool used for the BAM to FASTQ conversion. Currently, supported are `biobambam` (bamtofastq) and `picard` (SamToFastq).
* outputPerReadGroup: By default, read in the BAM an produce one set of FASTQs (single, pair, unsorted) for each read-group. Splitting by read-groups allows parallelization of sorting on different nodes and is more performant (due to O(n*log(n)) sorting cost).
* readGroupTag: The tag in the BAM header that identifies the name of the read-group. Defaults to "id"
* sortFastqs: Do you want to run the sortFastq step?
* checktFastqMd5: While reading in intermediate FASTQs, check that the MD5 is the same as in the accompanied '.md5' file.

Tuning parameters are

* sortCompressor: Compress temporary files during the sorting. By default `pigz` is used for parallel compression/decompression.
* compressorThreads: Used by `pigz` for temporary file compression. Currently defaulting to 4 cores.
* sortMemory: Defaults to "10g"
* sortThreads: Defaults to 4

Dependent on the actual BAM to FASTQ converter other tuning options may be available (e.g. for the JVM).

### `run`/`rerun`

With the configuration XML from above the call for a single BAM file would be:

```bash
roddy.sh run bam2fastq.any@convert testpid --useconfig=$pathToYourAppIni --useiodir=$inPath,$outPath --cvalues="bamfile_list:tumor_testpid_merged.mdup.bam"
```

This will read in the directories in the `$inPath` and interpret them as datasets (e.g. patients). This call provides the list of BAM files and a matching list of sample types (`sample_list`) via a `--cvalue` parameter, that is as configuration value. Note that if multiple BAM files and corresponding sample types should be provided, these need to be separated with semi-colons. e.g.:

```bash
roddy.sh run bam2fastq.any@convert testpid --useconfig=$pathToYourAppIni --useiodir=$inPath,$outPath --cvalues="bamfile_list:tumor_testpid_merged.mdup.bam;normal_testpid_merged.mdup.bam"
```

The `extractSamplesFromOutputFiles:false` makes sure that the sample types are not extracted from the BAM files (in most workflows these are output files of an alignment workflow, which explains the name of the configuration value).

Use `rerun` to restart a failed workflow keeping old results.


### `cleanup`

Remove the unsorted FASTQ files. Currently, these files are not actually removed but truncated to size 0. The call is the identical to the one for `run` or `rerun` but uses the `cleanup` mode of Roddy.

```bash
roddy.sh cleanup $configName@convert --useconfig=$pathToYourAppIni
```



```bash
roddy.sh rerun $configName@convert \
  --useconfig=$pathToYourAppIni \
  --cvalues="sample_list:tumor;tumor;tumor;tumor;tumor;normal;normal;normal,possibleControlSampleNamePrefixes:normal,possibleTumorSampleNamePrefixes:tumor,bamfile_list:/icgc/dkfzlsdf/analysis/B080/kensche/tests/AlignmentAndQCWorkflows_1.2.73-OTPConfig-1.5-Roddy-2.4/OTPTest-AQCWF-WGS-1-2-Roddy-2-4.Picard.SoftwareBwa.WGS/tumor_testpid_merged.mdup.bam,extractSamplesFromOutputFiles:false"
```

## Unsorted Notes

### Handling of Read-Group Special Cases

* For read groups mentioned in the header but without reads, the workflow produces (possibly empty) FASTQs.
* For reads without a group, Biobambam's  `bamtofastq` produces a 'default' group. The Roddy workflow always produces (possibly empty) FASTQs for this group. The reason is that such reads can only be recognized by traversing the whole file, but output directories and jobs are fixed during submission time, where we do not want to traverse more than the BAM header.
* When splitting by read groups, Picard's (2.14.1) `SamToFastq` dies if there are reads that are not assigned to a read group.

## TODOs

* Single-end BAM processing is not yet supported. Parameter "pairedEnd" is currently set to "true".
* Unpaired FASTQs ("writeUnpairedFastq" is currently defaulting to "false"), for reads from the original BAM that are not paired, can be written, but there is no facility in the workflow yet to sort it by name.
