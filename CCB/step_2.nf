#!/usr/bin/env nextflow

// channels
// fastqs 
fastqs = Channel.fromPath("${launchDir}/intermediates/barcode_*.fastq")
    .filter(file -> file.size() > 50000) // filter for fastq files larger than 50KB

// fastqs for demu 
fastq_demu = Channel.fromPath("${launchDir}/intermediates/barcode_*.fastq")
    .map {fastq -> tuple(fastq.baseName, fastq)}


// internal adaptor filter 
//adaptor_filter_script = Channel.fromPath("bin/internal_adaptor_filter_dT100k.Rmd")
dt_threshold_rds = Channel.fromPath("${launchDir}/intermediates/adaptor_dT_threshold.rds")
tso_threshold_rds = Channel.fromPath("${launchDir}/intermediates/adaptor_TSO_threshold.rds")

// minimap - print path of reference
reference_index = Channel.fromPath(params.minimap_reference_index)

// grouping rmd 
//grouping_script = Channel.fromPath("${baseDir}/../bin/grouping.Rmd")
barcode_rds = Channel.fromPath("${launchDir}/intermediates/barcode_*.fastq.rds")
    .map {rds -> tuple(rds.baseName.tokenize('.')[0], rds)}

// err_corr rmd 
//errcorr_script = Channel.fromPath("${baseDir}/../bin/errorcorrect.Rmd")
barcode_rds_err = Channel.fromPath("${launchDir}/intermediates/barcode_*.fastq.rds")
    .map {rds -> tuple(rds.baseName.tokenize('.')[0], rds)}

process dT_adaptor_filter {
    clusterOptions '--job-name=dt_internal_filter --nodelist=gen03'
    queue = { task.attempt == 2 ? 'long' : params.dt_queue }
    cpus params.dt_cpus
    time = { task.attempt == 2 ? '6day 23hours 59minutes 30seconds' : params.dt_time }
    memory = { task.attempt == 2 ? '500 GB' : params.dt_mem }
    maxRetries 2
    errorStrategy { task.attempt <= 2 ? 'retry' : 'finish' }

    // input
    input:    
    path fastq_file
    path dt_threshold 

    output: 
    tuple val(fastq_file.baseName), 
    path("${fastq_file}_adaptor_dT.middle.rds")

    script:
    """
    echo $fastq_file
    echo dT
    singularity exec -B $params.path $params.singularity R --vanilla -e "
    rmarkdown::render('${baseDir}/../bin/internal_adaptor_filter_dT100k.Rmd', knit_root_dir = '\$PWD', intermediates_dir = '\$PWD', 
    params = list(barcode = '${fastq_file}', adaptor.type = 'dT'), output_file = '${launchDir}/output/per_barcode_htmls/internal_adaptor_filter_dT_${fastq_file}.html')"
    """
}

process TSO_adaptor_filter {
    clusterOptions '--job-name=tso_internal_filter  --nodelist=gen03'
    queue = { task.attempt == 2 ? 'long' : params.tso_queue }
    cpus params.tso_cpus
    time = { task.attempt == 2 ? '6day 23hours 59minutes 30seconds' : params.tso_time }
    memory = { task.attempt == 2 ? '500 GB' : params.tso_mem }
    maxRetries 2
    errorStrategy { task.attempt <= 2 ? 'retry' : 'finish' }

    // input
    input: 
    path fastq_file
    path tso_threshold 

    output: 
    tuple val(fastq_file.baseName), 
    path("${fastq_file}_adaptor_TSO.middle.rds")


    script:
    """
    echo $fastq_file
    echo TSO
    singularity exec -B $params.path $params.singularity R --vanilla -e "
    rmarkdown::render('${baseDir}/../bin/internal_adaptor_filter_dT100k.Rmd', knit_root_dir = '\$PWD', intermediates_dir = '\$PWD',
    params = list(barcode = '${fastq_file}', adaptor.type = 'TSO'), output_file = '${launchDir}/output/per_barcode_htmls/internal_adaptor_filter_TSO_${fastq_file}.html')"
    """
}

process align {
    clusterOptions '--job-name=minimap'
    queue = { task.attempt == 2 ? 'long' : params.align_queue }
    cpus params.align_cpus
    time = { task.attempt == 2 ? '6day 23hours 59minutes 30seconds' : params.align_time }
    memory = { task.attempt == 2 ? '500 GB' : params.align_mem }
    maxRetries 2
    errorStrategy { task.attempt <= 2 ? 'retry' : 'finish' }

    input: 
    path fastq_file 
    path genome

    output: 
    tuple val(fastq_file.baseName), 
    path("${fastq_file.baseName}.sam")

    script:
    """
    module load minimap2/2.17 2>/dev/null || module load minimap2/2.17-GCC-8.3.0 2>/dev/null
    out=$fastq_file
    minimap2 -ax map-ont $genome $fastq_file > \${out%fastq}sam
    """
}

process grouping{
    clusterOptions '--job-name=grouping'
    queue = { task.attempt == 2 ? 'long' : params.grouping_queue }
    cpus params.grouping_cpus
    time = { task.attempt == 2 ? '6day 23hours 59minutes 30seconds' : params.grouping_time }
    memory = { task.attempt == 2 ? '100 GB' : params.grouping_mem }
    maxRetries 2
    errorStrategy { task.attempt <= 2 ? 'retry' : 'finish' }

    input: 
    tuple val(id), path(dt_rds), path(tso_rds), path(sam), path(fastq_rds) 

    output: 
    path "${id}.groups.*.rds"

    script:
    """
    echo $id
    singularity exec -B $params.path $params.singularity R --vanilla -e "rmarkdown::render('${baseDir}/../bin/grouping.Rmd', 
   knit_root_dir = '\$PWD' , intermediates_dir = '\$PWD', params = 
  list(barcode = '$id', fastq_rds = '$fastq_rds' , sam = '$sam', dt_middle_rds = '$dt_rds', tso_middle_rds = '$tso_rds'), output_file = '${launchDir}/output/per_barcode_htmls/grouping_${id}.html')"
    """
}

process err_corr{
    clusterOptions '--job-name=err_corr'
    queue = { task.attempt == 2 ? 'long' : params.err_queue }
    cpus params.err_cpus
    time = { task.attempt == 2 ? '6day 23hours 59minutes 30seconds' : params.err_time }
    memory = { task.attempt == 2 ? '500 GB' : params.err_mem }
    maxRetries 2
    errorStrategy { task.attempt <= 2 ? 'retry' : 'finish' }

    input: 
    tuple val(id), path(group_rds), path(fastq_rds), path(fastq_fastq)

    output:
    path "barcode_*_*_corrected_all.fastq"

    script:
    """
    singularity exec -B $params.path $params.singularity R --vanilla -e "rmarkdown::render('${baseDir}/../bin/errorcorrect.Rmd', 
   knit_root_dir = '\$PWD' , intermediates_dir = '\$PWD', params = 
  list(barcode = '$id', group_rds = '$group_rds', fastq_rds = '$fastq_rds', fastq_fastq='$fastq_fastq'), output_file = '${launchDir}/output/per_barcode_htmls/error_corr_${group_rds}.html')"

    """

}

process corrected_merge{
    publishDir "${launchDir}/output/", mode: 'copy'
    clusterOptions '--job-name=corr_merge'
    queue = { task.attempt == 2 ? 'long' : params.merge_queue }
    cpus params.merge_cpus
    time = { task.attempt == 2 ? '6day 23hours 59minutes 30seconds' : params.merge_time }
    memory = { task.attempt == 2 ? '500 GB' : params.merge_mem }
    maxRetries 2
    errorStrategy { task.attempt <= 2 ? 'retry' : 'finish' }

    input:
    file correct_fastqs

    output: 
    path "corrected_barcode_*.fastq"

    script:
    """ 
    for barcode in {1..96}; do
        cat barcode_\${barcode}_*_corrected_all.fastq > corrected_barcode_\${barcode}.fastq || echo \$barcode
    done
    
    """
}


// Define the workflow
workflow {
    log.info """\
                                                                    ▐         ▐  
       §                                                         ▞▀▘▜▀ ▞▀▖▛▀▖ ▜▀ ▌  ▌▞▀▖
     *--= :                                                      ▝▀▖▐ ▖▛▀ ▙▄▘ ▐ ▖▐▐▐ ▌ ▌ 
    -+@.@%@                                                      ▀▀  ▀ ▝▀▘▌    ▀  ▘▘ ▝▀ 
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
    // create output dir for per barcode htmls
    new File("${launchDir}/output/per_barcode_htmls").mkdirs()

    // adaptor filter and mapping at once 

    id_dt_tso_sam_fastqrds = dT_adaptor_filter(fastqs, dt_threshold_rds.first()) 
    .join(TSO_adaptor_filter(fastqs, tso_threshold_rds.first()))
    .join(align(fastqs, reference_index.first()))
    .join(barcode_rds) 

    grouping(id_dt_tso_sam_fastqrds).flatten()
    .map {group -> tuple(group.baseName.tokenize('.')[0], group)}
    .combine(barcode_rds_err, by: 0 )
    .combine(fastq_demu, by:0)
    .set {grouping_out}

    corrected_merge(err_corr(grouping_out).collect())


}
