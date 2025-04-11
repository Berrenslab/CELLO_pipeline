#!/usr/bin/env nextflow

// channels
// zip_fastqs 
fastq_zip = Channel.fromPath("$params.input_files")
    .collect()


process merging{
    publishDir "${launchDir}/output/", mode: 'copy'
    debug true 
    clusterOptions '--job-name=pre_processing'
    queue = { task.attempt == 2 ? 'long' : params.queue_merging }
    cpus params.cpus_merging
    time = { task.attempt == 2 ? '6day 23hours 59minutes 30seconds' : params.time_merging }
    memory = { task.attempt == 2 ? '500 GB' : params.memory_merging }
    maxRetries 2
    errorStrategy { task.attempt <= 2 ? 'retry' : 'finish' }

    input: 
    path fastq_zip

    output: 
    path "${params.experiment_name}_less20kb.fastq"
    path 'step_1.txt'

    script:    
    """
    # outdir 
    # code
    echo 1. Combine and unzip all fastq files > step_1.txt
    echo Total reads before merge: >> step_1.txt
    
    if [[ ${params.input_files} == *.gz ]]; then
      zcat *fastq.gz | wc -l >> step_1.txt
      zcat *fastq.gz > ${params.experiment_name}.fastq
    elif [[ ${params.input_files} == *.fastq ]]; then
      cat *fastq | wc -l >> step_1.txt
      cat *fastq > ${params.experiment_name}.fastq
    else
      echo Unknown file extension: fastq and fastq.gz are accepted! >> step_1.txt
    fi  

    echo Total reads after merge: >> step_1.txt
    cat ${params.experiment_name}.fastq | wc -l >> step_1.txt

    echo 2. Filter for reads longer than 20kb  >> step_1.txt
    max_read_length=20000
    awk -v max_read_length="\$max_read_length" '\$1 ~ /^@/ {header = \$0; getline; seq = \$0; getline; sep = \$0; getline; qual = \$0; if (length(seq) < max_read_length) {print header; print seq; print sep; print qual}}' "${params.experiment_name}.fastq" > "${params.experiment_name}_less20kb.fastq"
    echo longest line after filtering:  >> step_1.txt
    wc -L "${params.experiment_name}_less20kb.fastq"  >> step_1.txt
    """
}

process contamination_map{
    debug true 
    publishDir "${launchDir}/output/", mode: 'copy'
    clusterOptions '--job-name=contamination_map'
    queue = { task.attempt == 2 ? 'long' : params.queue_mapping }
    cpus params.cpus_mapping
    time = { task.attempt == 2 ? '6day 23hours 59minutes 30seconds' : params.time_mapping }
    memory = { task.attempt == 2 ? '500 GB' : params.memory_mapping }
    maxRetries 2
    errorStrategy { task.attempt <= 2 ? 'retry' : 'finish' }
    input: 
    path "${params.experiment_name}_less20kb.fastq"

    output: 
    path 'map_contaminations.txt'
    path "${params.experiment_name}_unmapped.sam"

    script: 
    """
    echo Map to reference genome to check for contaminations > map_contaminations.txt
    realpath $params.minimap_reference_index >> map_contaminations.txt
    
    module load minimap2/2.17 2>/dev/null || module load minimap2/2.17-GCC-8.3.0 2>/dev/null
    module load samtools 2>/dev/null || module load SAMtools 2>/dev/null

    minimap2 -ax map-ont "$params.minimap_reference_index" ${params.experiment_name}_less20kb.fastq > ${params.experiment_name}.sam

    mapped_n=\$(samtools view -c -F 4 ${params.experiment_name}.sam)
    total_n=\$(samtools view -c ${params.experiment_name}.sam)
    echo Percentage of mapped reads: \$((mapped_n *100 / total_n)) >> map_contaminations.txt
    
    echo unmapped reads saved to ${params.experiment_name}_unmapped.sam  >> map_contaminations.txt
    samtools view -f 4 ${params.experiment_name}.sam > ${params.experiment_name}_unmapped.sam

    """ 
}

process dt_qc{
    debug true 
    publishDir "${launchDir}/intermediates/", mode: 'copy'
    clusterOptions '--job-name=dt_qc'
    queue = { task.attempt == 2 ? 'long' : params.queue_adaptor_qc }
    cpus params.cpus_adaptor_qc
    time = { task.attempt == 2 ? '6day 23hours 59minutes 30seconds' : params.time_adaptor_qc }
    memory = { task.attempt == 2 ? '500 GB' : params.memory_adaptor_qc }
    maxRetries 2
    errorStrategy { task.attempt <= 2 ? 'retry' : 'finish' }

    input: 
    path "${params.experiment_name}_less20kb.fastq"

    output:
    path "adaptor_dT_stat.rds"
    path "adaptor_dT_threshold.rds"

    script:
    """
    singularity exec -B $params.path $params.singularity R --vanilla -e "
    rmarkdown::render('${baseDir}/../bin/internal_adaptor_QC.Rmd', knit_root_dir = '\$PWD' , intermediates_dir = '\$PWD',
    params = list(input = '${params.experiment_name}_less20kb.fastq', adaptor.type = 'dT'), output_file = '${launchDir}/output/internal_adaptor_QC_dT.html')"
    
    """

}

process tso_qc{
    debug true 
    publishDir "${launchDir}/intermediates/", mode: 'copy'
    clusterOptions '--job-name=tso_qc'
    queue = { task.attempt == 2 ? 'long' : params.queue_adaptor_qc }
    cpus params.cpus_adaptor_qc
    time = { task.attempt == 2 ? '6day 23hours 59minutes 30seconds' : params.time_adaptor_qc }
    memory = { task.attempt == 2 ? '500 GB' : params.memory_adaptor_qc }
    maxRetries 2
    errorStrategy { task.attempt <= 2 ? 'retry' : 'finish' }

    input: 
    path "${params.experiment_name}_less20kb.fastq"

    output:
    path "adaptor_TSO_stat.rds"
    path "adaptor_TSO_threshold.rds"

    script:
    """
    singularity exec -B $params.path $params.singularity R --vanilla -e "
    rmarkdown::render('${baseDir}/../bin/internal_adaptor_QC.Rmd', knit_root_dir = '\$PWD', intermediates_dir = '\$PWD',
    params = list(input = '${params.experiment_name}_less20kb.fastq', adaptor.type = 'TSO'), output_file = '${launchDir}/output/internal_adaptor_QC_TSO.html')"
    
    """


}

process splitter{
    debug true 
    clusterOptions '--job-name=splitter'
    queue = { task.attempt == 2 ? 'long' : params.queue_merging }
    cpus params.cpus_merging
    time = { task.attempt == 2 ? '6day 23hours 59minutes 30seconds' : params.time_merging }
    memory = { task.attempt == 2 ? '500 GB' : params.memory_merging }
    maxRetries 2
    errorStrategy { task.attempt <= 2 ? 'retry' : 'finish' }

    input: 
    path "${params.experiment_name}_less20kb.fastq"

    output: 
    path "${params.experiment_name}_less20kb.part_00?.fastq"

    script:    
    """
    module load seqkit 

    seqkit split -p 2 ${params.experiment_name}_less20kb.fastq -O .

    """
}

process demultiplex{
    debug true 
    publishDir "${launchDir}/intermediates/", mode: 'copy'
    clusterOptions '--job-name=demu'
    queue = { task.attempt == 2 ? 'long' : params.queue_demultiplex }
    cpus params.cpus_demultiplex
    time = { task.attempt == 2 ? '6day 23hours 59minutes 30seconds' : params.time_demultiplex }
    memory = { task.attempt == 2 ? '500 GB' : params.memory_demultiplex }
    maxRetries 2
    errorStrategy { task.attempt <= 2 ? 'retry' : 'finish' }

    input: 
    path "${params.experiment_name}_less20kb.fastq"

    output:
    path "barcode_*.fastq"
    path "barcode_*.fastq.rds"


    script: 
    """
    singularity exec -B $params.path $params.singularity R --vanilla -e "rmarkdown::render('${baseDir}/../bin/demultiplex_multiparam.Rmd', 
   knit_root_dir = '\$PWD', intermediates_dir = '\$PWD', params = 
  list(fastq_file = '${params.experiment_name}_less20kb.fastq'), output_file = '${launchDir}/output/${params.experiment_name}_demultiplex.html')"

    """

}

process demu_postsplit{
    debug true 
    clusterOptions '--job-name=demu'
    queue = { task.attempt == 2 ? 'long' : params.queue_demultiplex }
    cpus params.cpus_demultiplex
    time = { task.attempt == 2 ? '6day 23hours 59minutes 30seconds' : params.time_demultiplex }
    memory = { task.attempt == 2 ? '500 GB' : params.memory_demultiplex }
    maxRetries 2
    errorStrategy { task.attempt <= 2 ? 'retry' : 'finish' }

    input: 
    path fastq 

    output:
//    tuple path("*_barcode_*.fastq"), path("*_barcode_*.fastq.rds")
    path("*_barcode_*.fastq")
    path("*_barcode_*.fastq.rds")

    script: 
    """
    part=\$(basename "$fastq" .fastq)
    echo \$part

    singularity exec -B $params.path $params.singularity R --vanilla -e "rmarkdown::render('${baseDir}/../bin/demultiplex_multiparam.Rmd', 
   knit_root_dir = '\$PWD', intermediates_dir = '\$PWD', params = 
  list(fastq_file = '$fastq'), output_file = '${launchDir}/output/${fastq}_demultiplex.html')"

    for f in *.fastq; do mv "\$f" "\${part}_\$f"; done
    for f in *.fastq.rds; do mv "\$f" "\${part}_\$f"; done

    """

}

process de_splitter{
    debug true 
    clusterOptions '--job-name=de_split'
    queue = { task.attempt == 2 ? 'long' : params.queue_merging }
    cpus params.cpus_merging
    time = { task.attempt == 2 ? '6day 23hours 59minutes 30seconds' : params.time_merging }
    memory = { task.attempt == 2 ? '500 GB' : params.memory_merging }
    maxRetries 2
    errorStrategy { task.attempt <= 2 ? 'retry' : 'finish' }

    input: 
    tuple path(fastq), path(rds) 

//    output: 

    script:    
    """
    for barcode in {1..96}; do
    cat ${params.experiment_name}_less20kb.part_00?_barcode_\${barcode}.fastq > barcode_\${barcode}.fastq || echo \$barcode
    done

    """
}

// Define the workflow
workflow {
    log.info """    
                                                                    ▐ 
       §                                                         ▞▀▘▜▀ ▞▀▖▛▀▖ ▞▀▖▛▀▖▞▀▖
     *--= :                                                      ▝▀▖▐ ▖▛▀ ▙▄▘ ▌ ▌▌ ▌▛▀ 
    -+@.@%@                                                      ▀▀  ▀ ▝▀▘▌   ▝▀ ▘ ▘▝▀▘
          @+@                                
            @:+.  :+*=                       
             .%=@§     §@                    
            @  § :*@     §                   ┌───────────────────────────────────────────────────────────────┐
           %     % --@   +@                  │                                                               │
           §      ==  @@  *                  │               ▀▀█    ▀▀█                                      │
           §@       =   .@@ @   §            │  ▄▄▄    ▄▄▄     █      █     ▄▄▄           ▄▄▄    ▄▄▄    ▄▄▄▄ │
            @ @@:-   @ @  @ @§@. @@          │ █▀  ▀  █▀  █    █      █    █▀ ▀█         █   ▀  █▀  █  █▀ ▀█ │
              .   .@:= = :          @*       │ █      █▀▀▀▀    █      █    █   █   ▀▀▀    ▀▀▀▄  █▀▀▀▀  █   █ │
                   =@ @   +@ -        @      │ ▀█▄▄▀  ▀█▄▄▀    ▀▄▄    ▀▄▄  ▀█▄█▀         ▀▄▄▄▀  ▀█▄▄▀  ▀█▄██ │
                    @-§    %  -       .      │                                                             █ │
                  .*@        .+ :     @      │                                                             ▀ │
                    *          % @   @+      └───────────────────────────────────────────────────────────────┘ 
                     @          *  @@:       
                     *:@        %@ .         
                       - @@@@@+  §           
                                             
    
                                            Singularity: $params.singularity
                Reference genome: $params.minimap_reference_index
                                                    Experiment: $params.experiment_name
                                                        *Transposomic slay*
  """
    
    // create output dirs 
    new File("${launchDir}/output").mkdirs()
    new File("${launchDir}/intermediates").mkdirs()

    // start pipeline
    fastq_merged = merging(fastq_zip)

   // contamination_map(fastq_merged[0])
   // dt_qc(fastq_merged[0])
   // tso_qc(fastq_merged[0])


// add fuser after
// need to make another demu
    if (params.split == 'yes') {

    splitter(fastq_merged[0])
        .flatten()
        | demu_postsplit
        | set { demu_split_out }

    demu_split_out.view()
 //       .collect()
//        | set { demu_split_joint }

//    demu_split_joint.view()

 //   de_splitter(demu_split_joint)

    } else if (params.split == 'no') {
        demultiplex(fastq_merged[0])
    }

    
}
