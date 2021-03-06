#!/usr/bin/env nextflow

// TODO: Update based on NASA storage conventions
params.rsem_prefix = "/data/home/snagar9/data/covirt-nextflow/data/Homo_sapiens_GRCh38_rsem"

// TODO: Integrate into worflow so that the Channel doesn't need to be populated from a path
aligned_reads_files_ch = Channel.fromPath("/data/home/snagar9/data/covirt-nextflow/data/Fastq_Input_Files_for_Testing/aligned_reads/*_Aligned.toTranscriptome.out.bam")

// TODO: Change paths as needed
params.aligned_reads_count_dir = "/data/home/snagar9/data/covirt-nextflow/data/aligned_reads_counts"

// TODO: Automate setting of this value
params.numberOfThreads = 16

process countAlignedReads {
    label "covirt_rsem"

    publishDir params.aligned_reads_count_dir, mode: "copy"

    input:
      file aligned_reads_file from aligned_reads_files_ch

    output:
      file "*genes.results" into rsem_gene_counts_ch
      file "*isoforms.results" into rsem_isoform_counts_ch

    """
    sample=`echo ${aligned_reads_file} | sed 's/_Aligned.toTranscriptome.out.bam//'`

    echo Sample \$sample

    rsem-calculate-expression --num-threads ${params.numberOfThreads} \
        --alignments \
        --bam \
        --paired-end \
        --seed 12345 \
        --estimate-rspd \
        --no-bam-output \
        --strandedness reverse \
        --append-names \
            ${aligned_reads_file} \
            ${params.rsem_prefix} \
            ./\${sample}
    """
}

process generateRSEMCountsTables {

    publishDir params.aligned_reads_count_dir, mode: "copy"

    input:
      file "*" from rsem_gene_counts_ch.collect()
    
    output:
      file "*Gene_Counts.csv" into gene_counts_table_file_ch
      file "*Isoform_Counts.csv" into isoform_counts_table_file_ch

    """
    #!/usr/bin/env Rscript

    # Importing required library
    library(tximport)

    # Printing messages
    print("Make RSEM gene and isoform counts tables")
    print("")

    # Importing files matching pattern "*.genes.results"
    gene_files <- list.files(
                    path = "${params.aligned_reads_count_dir}", 
                    pattern = ".genes.results", 
                    full.name = T
                    )

    # Getting samples names from files
    // TODO: Define sample naming scheme - might have to change regex for this
    samples <- sub(".genes.results", "",
                    sub("split_", "", basename(gene_files))
                )

    # Naming files by sample name
    names(gene_files) <- samples

    # Importing gene count data
    gene.txi.rsem <- tximport(gene_files, type = "rsem", txIn = FALSE, txOut = FALSE)

    # Writitng out data to report file
    // TODO: Check whether output format needs to be cleaned up.  Currently has quotes.
    write.csv(gene.txi.rsem\$counts, file='RSEM_Unnormalized_Gene_Counts.csv')

    # Repeat process with isoforms
    isoform_files <- list.files(
                        path = "${params.aligned_reads_count_dir}", 
                        pattern = ".isoforms.results", 
                        full.name = T
                        )

    samples <- sub(".isoforms.results", "",
                    sub("split_", "", basename(isoform_files))
                )
    
    names(isoform_files) <- rownames(samples)

    isoform.txi.rsem <- tximport(isoform_files, type = "rsem", txIn = FALSE, txOut = FALSE)

    write.csv(isoform.txi.rsem\$counts,file='RSEM_Unnormalized_Isoform_Counts.csv')

    print("Session Info below: ")
    print("")
    sessionInfo()
    """
}
