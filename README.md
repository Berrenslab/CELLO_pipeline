*In development*
# CELLO_pipeline step 1
## Introduction
Nextflow based CELLO-seq pipeline optimised for SLURM clusters. This specific code take raw fastq reads from ONT sequencing runs and outputs qc and and demultiplexed files. Note that if steps have same number, they are synchronous. Please see XXX for mroe details.

## Set-up 
1. cd to your directory with your raw CELLO-seq fastq files
2. Create a parameter file (e.g. 1_parameters.json) to specify how your pipeline should run
* note that the cpus / time / memory you ask is per task
* Note that demultiplexing requires much more memory than the other tasks
* this is an example 1_parameters.json for a large dataset
```
{
    "singularity": "/path/to/sarlacc.img", 
    "path": "/path/to/your/folder",

    "queue": "test/short/long",
    "cpus": "#",
    "time": "#day ##hours ##minutes ##seconds",
    "memory": "### GB",
    "minimap_reference_index": "/path/to/genome.fa.mmi",
    "experiment_name": "experiment_name",
    "input_files" : "Common ending of input files: *.fastq.gz"

}
```
2. Run nextflow
```
module load nextflow
nextflow -bg run /ceph/project/CELLOseq/frivetti/next/code/step_1.nf -params-file parameters.json > output/step_1.log
```
- bg: background, enables run to continue even if you log out from cluster
- stdout is saved into step_1.log
- If you see barcode_\*.fastq and barcode_\*.fastq.rds , process is done.
- Only remove work/ dir once you are happy with the outcome
```
rm -rf work/
```

### Description
Input: reads (*fastq.gz)
1. Concatenates them into one file
1. Removes reads >20kb
2. Yields % contamination in .txt
2. Runs dT and TSO adaptor qc (see .html)
2. Demultiplexes plate into barcodes
Output: barcode_\*.fastq and barcode_\*.fastq.rds

### Dealing with pipeline errors 
Each run creates a html report (run_report_YYYY-MM-DD_hh-ss.html). If there are issues, you look for the error codes. If this is not enough, you can identify the problematic processes and cd ```work/problematic/process``` and ```ls -lha``` to see all files: .command.out and .command.err are the most useful. 


### Da fare 
1. Strategia d'errore - ignore
2. separa cpu e memoria in tipi
4. Porechop
6. Aggiungere FLARE?
10. pachettizza
