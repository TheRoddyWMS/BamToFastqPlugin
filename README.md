# BamToFastqPlugin

This [Roddy](https://github.com/TheRoddyWMS/Roddy) plugin contains a workflow for converting multi-read-group BAMs into name-sorted FASTQs. The name-sorting is a time-consuming step that however ensures that tools like BWA, which estimate parameters from batches of reads, produce unbiased results (consider estimates of e.g. insert size depending on the genomic regions).

Basically two simple steps are taken. First the BAM is converted to one or multiple FASTQs, each with the order of reads exactly as in the BAM (e.g. position-sorted). Then the FASTQs are sorted by FASTQ entry name.

## Software Requirements

The workflow has very few requirements. Beyond a working [Roddy](https://github.com/TheRoddyWMS/Roddy) installation, it uses Biobambam or Picard for the actual BAM-to-FASTQ conversion and coreutils sort for the name-sorting of FASTQs.

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

The simplest way to start the workflow is without a dedicated configuration file by using the plugin-internal configuration:

```bash
roddy.sh run BamToFastqPlugin_$version:bam2fastqAnalysis $pid \
  --useiodir=$inputDir,$outputDir \
  --cvalues="bamfile_list:/path/to/your/data.bam"
```

The string `BamToFastqPlugin_$version:bam2fastqAnalysis` here is the name of the plugin -- that should also be used as part of the name of the plugin directory and the version of the plugin as found in the plugin directory. Thus, if you plugin's installation directory is called `BamToFastqPlugin_1.0.2`, then the used configuration would be `BamToFastqPlugin_1.0.2:bam2fastqAnalysis`.

### Using a Configuration File

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
* outputPerReadGroup: By default, read in the BAM and produce one set of FASTQs (single, pair, unsorted) for each read-group. Splitting by read-groups allows parallelization of sorting on different nodes and, because of the smaller files, is more performant (due to O(n*log(n)) sorting cost).
* readGroupTag: The tag in the BAM header that identifies the name of the read-group. Defaults to "id"
* sortFastqs: Do you want to run the sortFastq step?
* checktFastqMd5: While reading in intermediate FASTQs, check that the MD5 is the same as in the accompanied '.md5' file.

Tuning parameters are

* sortMemory: Defaults to "10g"
* sortThreads: Defaults to 4
* sortCompressor: Compress temporary files during the sorting. By default `pigz.sh` -- a wrapper for pigz in the plugin -- is used for parallel compression/decompression. See the corutils sort documentation for requirements on the interface of the compression tool.
* compressorThreads: Used by `pigz` for temporary file compression. Currently defaulting to 4 cores.

The workflow is not yet fully tuned and may anyway profit from tuning to the specific I/O and CPU characteristics of your environment. E.g. in a cloud environment CPU may be similar, but I/O may perform much worse than in our HPC environment.

Dependent on the actual BAM to FASTQ converter other tuning options may be available (e.g. for the JVM).

### `run`/`rerun`

With the configuration XML from above the call for a single BAM file would be:

```bash
roddy.sh run bam2fastq.any@convert testpid --useconfig=$pathToYourAppIni --useiodir=$inPath,$outPath --cvalues="bamfile_list:/path/to/tumor_testpid_merged.mdup.bam"
```

The list of BAM files is taken from the `bamfile_list` configuration value. The BAMs do not have to reside below the `$inPath` and no further metadata are required, except for the read-groups, which are directly taken from the BAM headers. Multiple BAMs can be specified with semicolons `;` as separators:

```bash
roddy.sh run bam2fastq.any@convert testpid --useconfig=$pathToYourAppIni --useiodir=$inPath,$outPath --cvalues="bamfile_list:/path/to/tumor_testpid_merged.mdup.bam;/path/to/normal_testpid_merged.mdup.bam"
```

Concerning the "datasets" (here `testpid`): The above command will read in the directories in the `$inPath` and interpret them as datasets (e.g. patients). Among these subdirectories one needs to be called "testpid", like the requested dataset in the call above. This is the current situation but we plan to make the workflow able to e.g. retrieve BAM files following some filter critia (glob, regex) from the input directory and interpret the path from the input directory to the BAM as dataset name. 

Use the `rerun` mode to restart a failed workflow while keeping already generated old results.

### `cleanup`

Remove the unsorted FASTQ files. Currently, these files are not actually removed but truncated to size 0. The call is identical to the one for `run` or `rerun` but uses the `cleanup` mode of Roddy.

```bash
roddy.sh cleanup $configName@convert --useconfig=$pathToYourAppIni
```

## Unsorted Notes

### Handling of Read-Group Special Cases

* For read groups mentioned in the header but without reads, the workflow produces (possibly empty) FASTQs.
* For reads without a group, Biobambam's  `bamtofastq` produces a 'default' group. The Roddy workflow always produces (possibly empty) FASTQs for this group. The reason is that such reads can only be recognized by traversing the whole file, but output directories and jobs are fixed during submission time, where we do not want to traverse more than the BAM header.
* When splitting by read groups, Picard's (2.14.1) `SamToFastq` dies if there are reads that are not assigned to a read group.

## TODOs

* Single-end BAM processing is not yet supported. Parameter "pairedEnd" is currently set to "true".
* Unpaired FASTQs ("writeUnpairedFastq" is currently defaulting to "false"), for reads from the original BAM that are not paired, can be written, but there is no facility in the workflow yet to sort it by name.
