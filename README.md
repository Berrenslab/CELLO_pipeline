```
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
                                             
```    

Nextflow based CELLO-seq pipeline optimised for SLURM clusters. This specific code take raw fastq reads from ONT sequencing runs and outputs qc and and demultiplexed files. Note that if steps have same number, they are synchronous. Please see XXX for mroe details. 
* This has been optimised for the genoa cluster. 

### Dealing with pipeline errors 
Each run creates a html report (run_report_YYYY-MM-DD_hh-ss.html). If there are issues, you look for the error codes. If this is not enough, you can identify the problematic processes and cd ```work/problematic/process``` and ```ls -lha``` to see all files: .command.out and .command.err are the most useful. 

## Step I: pre demultiplexing 
### How to run
1. cd to your directory with your raw CELLO-seq fastq files
2. Edit step_1_parameters.json : see below an example for a large dataset. 
* The parameters file specifies the resources to be used by each process 
* note that the cpus / time / memory you ask is per task
* The values below have been optimised for a promethION on the Genoa cluster
```
{
    "singularity": "/home/bioc1647/images/sarlacc.img",
    "path": "YOUR/HOME/DIR",
    "queue_size":  "0",

    "queue": "cpu-gen",
    "cpus": "1",
    "time": "00:30:30",
    "memory": "20 GB",

    "queue_merging": "cpu-gen",
    "cpus_merging": "1",
    "time_merging": "23:59:30",
    "memory_merging": "20 GB",

    "queue_mapping": "cpu-gen",
    "cpus_mapping": "1",
    "time_mapping": "23:59:30",
    "memory_mapping": "50 GB",


    "queue_adaptor_qc": "cpu-gen",
    "cpus_adaptor_qc": "1",
    "time_adaptor_qc": "23:59:30",
    "memory_adaptor_qc": "300 GB",

    "queue_demultiplex": "himem-gen24",
    "cpus_demultiplex": "24",
    "time_demultiplex": "6d 23h 59m",
    "memory_demultiplex": "1200 GB",

    "minimap_reference_index": "YOUR/GENOME/.mmi",
    "experiment_name": "YOUR/EXPERIMENT/NAME",
    "input_files" : "*.fastq.gz OR *fastq"

}
```
* Minimap reference index is the index used for mapping contaminations, note it needs to end in fa.mmi
* Experiment name is your experiment name, it is only for organizational purposes
* input file is the "common denominator" across your raw files. This can also be a directory with all your files, like fastq/*fastq.gz
* queue_size = maximum jobs to be sent at once. Not important for step 1. 0 Means no maximum. 

2. Run nextflow
```
module load Nextflow # or nextflow for CCB
nextflow -bg run https://github.com/Berrenslab/CELLO_pipeline.git -main-script /CCB/step_1.nf -params-file 1_params.json -r main -latest > step_1.log
```
- bg: background, enables run to continue even if you log out from cluster
- -r means : which branch do you want to use? In most cases use main. 
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
    "singularity": "/home/bioc1647/images/sarlacc.img",
    "path": "YOUR/HOME/DIR",
    "queue_size": "100",

    "queue": "himem-gen24",
    "time": "00:09:30",
    "memory": "20 GB",

    "dt_queue": "himem-gen48",
    "dt_cpus": "1",
    "dt_time": "23:59:00",
    "dt_mem": "30GB",

    "tso_queue": "himem-gen48",
    "tso_cpus": "1",
    "tso_time": "23:59:00",
    "tso_mem": "30GB",

    "align_queue": "himem-gen48",
    "align_cpus": "2",
    "align_time": "23:59:00",
    "align_mem": "55GB",

    "grouping_queue": "himem-gen48",
    "grouping_cpus": "1",
    "grouping_time": "60:00:00",
    "grouping_mem": "30GB",

    "err_queue": "himem-gen48",
    "err_cpus": "1",
    "err_time": "60:00:00",
    "err_mem": "30GB",

    "merge_queue": "himem-gen4",
    "merge_cpus": "1",
    "merge_time": "12:00:00",
    "merge_mem": "10 GB",


    "minimap_reference_index": "YOUR/TRANSCRIPTOME/REFERENCEfa.mmi",
    "experiment_name": "YOUR/EXPERIMENT/NAME",
    "input_files" : "LEAVE/UNCHANGED"

}
```
2. Run nextflow (see above for description)
```
module load nextflow # or Nextflow
nextflow -bg run https://github.com/Berrenslab/CELLO_pipeline.git -main-script /CCB/step_2.nf -params-file 2_step_params.json -r main -latest > step_2.log
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
