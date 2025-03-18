    §                                                         
  *--= :                                                       
-+@.@%@                                                      
      @+@                                
        @:+.  :+*=                       
         .%=@§     §@                    
        @  § :*@     §              ┌─────────────────────────────────────────────────────────────┐
       %     % --@   +@             │                                                             │
       §      ==  @@  *             │               ▀▀█    ▀▀█                                    │
       §@       =   .@@ @   §       │  ▄▄▄    ▄▄▄     █      █     ▄▄▄         ▄▄▄    ▄▄▄    ▄▄▄▄ │
        @ @@:-   @ @  @ @§@. @@     │ █▀  ▀  █▀  █    █      █    █▀ ▀█       █   ▀  █▀  █  █▀ ▀█ │
          .   .@:= = :          @*  │ █      █▀▀▀▀    █      █    █   █  ▀▀▀   ▀▀▀▄  █▀▀▀▀  █   █ │
               =@ @   +@ -        @ │ ▀█▄▄▀  ▀█▄▄▀    ▀▄▄    ▀▄▄  ▀█▄█▀       ▀▄▄▄▀  ▀█▄▄▀  ▀█▄██ │
                @-§    %  -       . │                                                           █ │
              .*@        .+ :     @ │                                                           ▀ │
                *          % @   @+ └─────────────────────────────────────────────────────────────┘ 
                  @          *  @@:       
                  *:@        %@ .         
                     - @@@@@+  §           
                                             
    



Nextflow based CELLO-seq pipeline optimised for SLURM clusters. This specific code take raw fastq reads from ONT sequencing runs and outputs qc and and demultiplexed files. Note that if steps have same number, they are synchronous. Please see XXX for mroe details.

### Dealing with pipeline errors 
Each run creates a html report (run_report_YYYY-MM-DD_hh-ss.html). If there are issues, you look for the error codes. If this is not enough, you can identify the problematic processes and cd ```work/problematic/process``` and ```ls -lha``` to see all files: .command.out and .command.err are the most useful. 

## Step I: pre demultiplexing 
### How to run
1. cd to your directory with your raw CELLO-seq fastq files
2. Edit step_1_parameters.json : see below an example for a large dataset. 
* The parameters file specifies the resources to be used by each process 
* note that the cpus / time / memory you ask is per task
```
{
    "singularity": "/project/CELLOseq/shared/images/sarlacc.img",
    "path": "/ceph/project/CELLOseq",

    "queue": "test",
    "cpus": "1",
    "time": "00:09:30",
    "memory": "20 GB",

    "queue_merging": "short",
    "cpus_merging": "1",
    "time_merging": "23:59:30",
    "memory_merging": "20 GB",

    "queue_mapping": "short",
    "cpus_mapping": "5",
    "time_mapping": "23:59:30",
    "memory_mapping": "50 GB",


    "queue_adaptor_qc": "short",
    "cpus_adaptor_qc": "1",
    "time_adaptor_qc": "23:59:59",
    "memory_adaptor_qc": "300 GB",

    "queue_demultiplex": "long",
    "cpus_demultiplex": "5",
    "time_demultiplex": "4day 0hours 0minutes 30seconds",
    "memory_demultiplex": "1300 GB",
  
    "minimap_reference_index": "/ceph/project/CELLOseq/lmcleand/reference_genomes/Mus_musculus.GRCm39.dna.primary_assembly.fa.mmi",
    "experiment_name": "all_plate",
    "input_files" : "*.fastq.gz"

}
```
* Minimap reference index is the index used for mapping contaminations, note it needs to end in fa.mmi
* Experiment name is your experiment name, it is only for organizational purposes
* input file is the "common denominator" across your raw files. 

2. Run nextflow
```
module load nextflow # or Nextflow
nextflow -bg run https://github.com/Berrenslab/CELLO_pipeline.git -main-script /CCB/step_1.nf -params-file 1_params.json -latest > step_1.log
```
* If on on biochem cluster, you may need to specify repository: -r main
- bg: background, enables run to continue even if you log out from cluster
- latest ensures tnat the latest code is used from GitHub
- stdout is saved into step_1.log
- Pipeline creates output and intermediate folders. (Both are needed for the next step). 
- Only remove work/ dir once you are happy with the outcome
```
rm -rf work/
```

### Ouput 

1. Open the run report file (run_report_YYYY-MM-DD_hh-ss.html)
2. stdout is saved into step_1.log (file name may change)
3. intermediate: directory with intermediate files
   * needed files for step_2
4. output: directory with qc files and run report.

### Description
Input: reads (*fastq.gz)
1. Concatenates them into one file
1. Removes reads >20kb
2. Yields % contamination in .txt
2. Runs dT and TSO adaptor qc (see .html)
2. Demultiplexes plate into barcodes
Output: barcode_\*.fastq and barcode_\*.fastq.rds

## Step II: post demultiplexing
### How to run
1. Create 2_step_params.json (below is an example for a large CELLO-seq run)
```
{
    "singularity": "/project/CELLOseq/shared/images/sarlacc.img",
    "path": "/ceph/project/CELLOseq",

    "queue": "test",
    "time": "00:09:30",
    "memory": "20 GB",

    "dt_queue": "",
    "dt_cpus": "",
    "dt_time": "",
    "dt_mem": "",

    "tso_queue": "",
    "tso_cpus": "",
    "tso_time": "",
    "tso_mem": "",

    "align_queue": "", 
    "align_cpus": "",
    "align_time": "",
    "align_mem": "",

    "grouping_queue": "",
    "grouping_cpus": "",
    "grouping_time": "",
    "grouping_mem": "",

    "err_queue": "",
    "err_cpus": "",
    "err_time": "",
    "err_mem": "",

    "merge_queue": "",
    "merge_cpus": "",
    "merge_time": "",
    "merge_mem": "",

    "minimap_reference_index": "/ceph/project/CELLOseq/lmcleand/reference_genomes/Mus_musculus.GRCm39.dna.primary_assembly.fa.mmi",
    "experiment_name": "all_plate",
    "input_files" : "*.fastq.gz"

}
```
2. Run nextflow (see above for description)
```
module load nextflow # or Nextflow
nextflow -bg run https://github.com/Berrenslab/CELLO_pipeline.git -main-script /CCB/step_2.nf -params-file 2_step_params.json -latest > step_2.log
```
3. Remove work/ only when you are done
4. Continue to FLAIR pipeline

### Description
Input: barcode_\*.fastq, barcode_\*.fastq.rds, tso.rds, dT.rds. 
- Analysis is repeated per barcode
1. dT adaptor filer
1. TSO adaptor filter
1. Align to reference genome
2. Grouping of reads by UMI
3. Error-correction of reads by UMI
Output: error-corrected and demultiplexed fastq reads. 

## Dealing with pipeline errors 
### Run report 
Each run creates a html report (run_report_YYYY-MM-DD_hh-ss.html). 
* At the end there is a table with all the processes and information:
1. Number of attempts
2. Resource usage
3. Resource allocation
4. Exit codes
5. Path to process directories

- If there are issues, you look for the error codes. If this is not enough, you can identify the problematic processes and cd ```work/problematic/process``` and ```ls -lha``` to see all files: .command.out and .command.err are the most useful. 
### work directory 
Nextflow runs each process (task) in a separate folder inside the work/ directory. If you have a failure, you can identify which task and its path either with the log file or the run_report. Do not edit the work directory as if so Nextflow will not be able to resume a failed process. If you are happy with the output, you can do whatever you want. 
```
cd pwd/work/problematic/dir
ls -lha
```
This will print output files and hidden files: 
1. .command.err # stderr of task
2. .comand.out # stdout of task
3. .command.log # graphs of resource usage (WIMM cluster)
4. .command.run # interpreted code , can sbatch it 
5. .exitcode # exitcode

### quitting a background nextflow process
Let's say you ran the pipeline, and you want to stop it:
* scancel job_ID does not work easily. As you are just cancelling a specific task, so the workflow will run it again. 
```
# identify the job ID
pgrep -fl nextflow
# get more information
ps -fp $ID
# cancel the background process
kill $ID
```

### resume a failed process
If the first 2 processes worked, but the last 3 failed. You can fix the issue and just rerun the remaining processes: 
```
nextflow -bg run https://github.com/franci-r/CELLO_pipeline.git -params-file parameters.json -resume > step_1.log
```
* resume flag makes nextflow not re-run successful processes. 


### Da fare 
1. Strategia d'errore - rimuovi aumento?
2. Rallentare per non overwelmare il cluster ?
3. Aggiungi scelta per demu e mapping
4. Demu separa?  

### Da aggiungere
1. Porechop
2. Flaire
