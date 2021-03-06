# Raw to Aligned Data Processing Pipeline

> **This page holds an overview and instructions for how COV-IRT generates alignment and STAR count data from raw Illumina RNA-sequencing data of COVID-19 samples. Exact processing commands used for specific cohorts of samples are available in the [Exact_scripts_used](Exact_scripts_used) sub-directory.**  

---

# Table of contents  

- [**Software used**](#software-used)
- [**General processing overview with example commands**](#general-processing-overview-with-example-commands)
  - [**0. Create Sample List**](#0-create-sample-list)
  - [**1. Raw Data QC**](#1-raw-data-qc)
    - [**1a. Raw Data QC**](#1a-raw-data-qc)
    - [**1b. Compile Raw Data QC**](#1b-compile-raw-data-qc)
  - [**2. Trim/Filter Raw Data and Trimmed Data QC**](#2-trimfilter-raw-data-and-trimmed-data-qc)
    - [**2a. Trim/Filter Raw Data**](#2a-trimfilter-raw-data)
    - [**2b. Trimmed Data QC**](#2b-trimmed-data-qc)
    - [**2c. Compile Trimmed Data QC**](#2c-compile-trimmed-data-qc)
  - [**3. Split Fastq Files Based on Sequencing Run/Lane**](#3-split-fastq-files-based-on-sequencing-runlane)
  - [**4. Remove Ribosomal RNA Reads from Split Fastq Files**](#4-remove-ribosomal-rna-reads-from-split-fastq-files)
  - [**5. Retrieve Genome/Annotation Files and Build STAR Reference**](#5-retrieve-genomeannotation-files-and-build-star-reference)
    - [**5a. Get Genome and Annotation Files**](#5a-get-genome-and-annotation-files)
    - [**5b. Build STAR Reference**](#5b-build-star-reference)
  - [**6. Align Reads to Reference Genome with STAR and Generate STAR Counts Table**](#6-align-reads-to-reference-genome-with-star-and-generate-star-counts-table)
    - [**6a. Align Reads to Reference Genome with STAR**](#6a-align-reads-to-reference-genome-with-star)
    - [**6b. Generate STAR Counts Table in R**](#6b-generate-star-counts-table-in-r) 
  - [**7. Sort and Index Genome-Aligned Data**](#7-sort-and-index-genome-aligned-data)
    - [**7a. Sort Genome-Aligned Data**](#7a-sort-genome-aligned-data)
    - [**7b. Index Sorted Genome-Aligned Data**](#7b-index-sorted-genome-aligned-data)
  - [**8. Alignment Data QC**](#8-alignment-data-qc)
    - [**8a. Create Reference Files**](#8a-create-reference-files)
    - [**8b. Generate Alignment Data QC Metrics**](#8b-generate-alignment-data-qc-metrics)

---

<br>

# Software used  

|Program|Version*|Relevant Links|
|:------|:------:|:-------------|
|FastQC|`fastqc -v`|[https://www.bioinformatics.babraham.ac.uk/projects/fastqc/](https://www.bioinformatics.babraham.ac.uk/projects/fastqc/)|
|MultiQC|`multiqc -v`|[https://multiqc.info/](https://multiqc.info/)|
|Trimmomatic|`trimmomatic -version`|[http://www.usadellab.org/cms/?page=trimmomatic](http://www.usadellab.org/cms/?page=trimmomatic)|
|gdc-fastq-splitter|`gdc-fastq-splitter --version`|[https://github.com/kmhernan/gdc-fastq-splitter](https://github.com/kmhernan/gdc-fastq-splitter)|
|STAR|`STAR --version`|[https://github.com/alexdobin/STAR](https://github.com/alexdobin/STAR)|
|Samtools|`samtools --version`|[http://www.htslib.org/](http://www.htslib.org/)|
|HTStream|`hts_SeqScreener --version`|[https://s4hts.github.io/HTStream/](https://s4hts.github.io/HTStream/)|
|gtfToGenePred|No `version` command listed|[https://bioconda.github.io/recipes/ucsc-gtftogenepred/README.html](https://bioconda.github.io/recipes/ucsc-gtftogenepred/README.html)
|gatk|`gatk --version`|[https://gatk.broadinstitute.org/](https://gatk.broadinstitute.org/)|

>**\*** Exact versions used to process specific cohorts are available in the [Exact_scripts_used](Exact_scripts_used) sub-directory. 
>
>**\*** All tools needed (except gdc-fastq-splitter) can be installed via conda with the following [conda environments](https://github.com/asaravia-butler/COV-IRT/tree/main/RNAseq/Conda_Environments):
>  - COVIRT_GATK
>  - COVIRT_HTStream
>  - COVIRT_fastq_to_alignment
>  - COVIRT_gtfToGenePred

---

<br>

# General processing overview with example commands  

> Exact processing commands used for specific cohorts are provided in the [Exact_scripts_used](Exact_scripts_used) sub-directory.  

---

## 0. Create Sample List

Create a single column list of all the samples to process. Each line in the list is a sample name that will be added to all processed data for that sample using the variable ${sample} in each processing command.

```
ls -1 *R1.fastq.gz | sed "s/.R1.fastq.gz//" > samples.txt
```

**Input Data:**
- Single column list of the forward reads (*R1.fastq.gz) of each sample to be processed

**Output Data:**
- samples.txt (text file containg a list of all sample names)

---

<br>

## 1. Raw Data QC

### 1a. Raw Data QC  

```
fastqc -o /path/to/raw_fastqc/output/directory *.fastq.gz
```

**Input Data:**
- *fastq.gz (raw reads)

**Output Data:**
- *fastqc.html (FastQC report)
- *fastqc.zip (FastQC data)

<br>

### 1b. Compile Raw Data QC  

```
multiqc -n raw_multiqc -o /path/to/raw_multiqc/output/directory /path/to/directory/containing/raw_fastqc/files
```

**Input Data:**
- *fastqc.zip (FastQC data from step 1a)

**Output Data:**
- raw_multiqc.html (multiqc report)
- raw_multiqc_data (directory containing multiqc data)

---

<br>

## 2. Trim/Filter Raw Data and Trimmed Data QC

### 2a. Trim/Filter Raw Data  

```
trimmomatic PE \
  -threads NumberOfThreads \
  -phred33 \
  -trimlog /path/to/trimming/log/outputs/${sample}_trimming.log \
  -summary /path/to/trimming/log/outputs/${sample}_trimming_summary.txt \
  -validatePairs \
  /path/to/raw/reads/${sample}.R1.fastq.gz \ 
  /path/to/raw/reads/${sample}.R2.fastq.gz \
  /path/to/ouput/trimmed/reads/${sample}_R1_P_trimmed.fq.gz \
  /path/to/ouput/trimmed/reads/${sample}_R1_U_trimmed.fq.gz \
  /path/to/ouput/trimmed/reads/${sample}_R2_P_trimmed.fq.gz \
  /path/to/ouput/trimmed/reads/${sample}_R2_U_trimmed.fq.gz \
  ILLUMINACLIP:/path/to/trimmomatic/adapter/fasta/files/TruSeq3-PE-2.fa:2:30:10:2:keepBothReads \
  LEADING:20 \
  TRAILING:20 \
  MINLEN:15
```

**Input Data:**
- *fastq.gz (raw reads)

**Output Data:**
- *_P_trimmed.fq.gz (paired trimmed reads)
- *_U_trimmed.fq.gz (unpaired trimmed reads)
- *trimming.log (trimming log file)
- *trimming_summary.txt (trimming summary file)

<br>

### 2b. Trimmed Data QC  

```
fastqc -o /path/to/trimmed_fastqc/output/directory *trimmed.fq.gz
```

**Input Data:**
- *_P_trimmed.fq.gz (paired trimmed reads from step 2a)
- *_U_trimmed.fq.gz (unpaired trimmed reads from step 2a)

**Output Data:**
- *fastqc.html (FastQC report)
- *fastqc.zip (FastQC data)

<br>

### 2c. Compile Trimmed Data QC  

```
multiqc -n trimmed_multiqc -o /path/to/trimmed_multiqc/output/directory /path/to/directory/containing/trimmed_fastqc/files
```

**Input Data:**
- *fastqc.zip (FastQC data from step 2b)

**Output Data:**
- trimmed_multiqc.html (multiqc report)
- trimmed_multiqc_data (directory containing multiqc data)

---

<br>

## 3. Split Fastq Files Based on Sequencing Run/Lane

```
gdc-fastq-splitter -o /path/to/ouput/split/trimmed/reads/${sample}/${sample}_ \
  /path/to/trimmed/reads/${sample}_R1_P_trimmed.fq.gz /path/to/trimmed/reads/${sample}_R2_P_trimmed.fq.gz
```

**Input Data:**
- *_P_trimmed.fq.gz (paired trimmed reads from step 2a)

**Output Data:**
- \*flowcell_lane#_R\*.fq.gz (trimmed reads split according to flowcell (i.e. sequencing run) and lane number)
- \*flowcell_lane#_R\*.report.jason (trimmed reads splitting report)

---

<br>

## 4. Remove Ribosomal RNA Reads from Split Fastq Files

Create list of split fastq files for all samples that will be held in the ${sample_fqsplit} variable below:

```
ls -1 *flowcell_lane#_R1.fq.gz | sed "s/_R1.fq.gz//" > samples_fqsplit.txt
```

Remove rRNA reads from each fastq file listed in `samples_fqsplit.txt`

```
hts_SeqScreener -L /path/to/HTStream_logs/${sample_fqsplit}_htsStats.log \
  -1 /path/to/split/trimmed/reads/${sample_fqsplit}_R1.fq.gz \
  -2 /path/to/split/trimmed/reads/${sample_fqsplit}_R2.fq.gz \
  -s /path/to/Hsapiens_rRNA_RefSeq_seq_w_mitrRNA_ITS_ETS.fasta \
  -x 0.20 \
  -f /path/to/ouput/rRNA-removed/split/trimmed/reads/${sample_fqsplit}
```

**Input Data:**
- \*flowcell_lane#_R\*.fq.gz (trimmed reads split according to flowcell (i.e. sequencing run) and lane number from step 3)
- Hsapiens_rRNA_RefSeq_seq_w_mitrRNA_ITS_ETS.fasta (fasta file containing rRNA genes as well as ITS1 and ITS2 and 5' and 3' ETS rRNA regions, and mitochondrial 12S and 16S genes - you can download this reference [here](https://github.com/asaravia-butler/COV-IRT/blob/main/RNAseq/Reference_Files/Hsapiens_rRNA_RefSeq_seq_w_mitrRNA_ITS_ETS.fasta))

**Output Data:**
- \*flowcell_lane#_R\*.fastq.gz (trimmed reads split according to flowcell (i.e. sequencing run) and lane number with rRNA reads removed)
- \*flowcell_lane#_R\*.htsStats.log (rRNA removal report)

---

<br>

## 5. Retrieve Genome/Annotation Files and Build STAR Reference

### 5a. Get Genome and Annotation Files 

Get human fasta and gtf files from [Ensembl](https://www.ensembl.org/) - used for processing human-filtered data and needed to process unfiltered data

```
wget ftp://ftp.ensembl.org/pub/release-100/fasta/homo_sapiens/dna/Homo_sapiens.GRCh38.dna.primary_assembly.fa.gz

wget ftp://ftp.ensembl.org/pub/release-100/gtf/homo_sapiens/Homo_sapiens.GRCh38.100.gtf.gz
```

Get SARS-CoV-2 fasta and gtf files from [Ensembl](https://www.ensembl.org/) - needed to process unfiltered data

```
wget ftp://ftp.ensemblgenomes.org/pub/viruses/fasta/sars_cov_2/dna/Sars_cov_2.ASM985889v3.dna.toplevel.fa.gz 

wget ftp://ftp.ensemblgenomes.org/pub/viruses/gtf/sars_cov_2/Sars_cov_2.ASM985889v3.101.gtf.gz
```

Concatenate human and SARS-CoV-2 fasta and gtf files - concatenated files used for processing unfiltered data

```
zcat Homo_sapiens.GRCh38.dna.primary_assembly.fa.gz Sars_cov_2.ASM985889v3.dna.toplevel.fa.gz > Homo_sapiens.GRCh38.dna.primary_assembly_and_Sars_cov_2.ASM985889v3.dna.primary_assembly.MN908947.3.fa

zcat Homo_sapiens.GRCh38.100.gtf.gz Sars_cov_2.ASM985889v3.101.gtf.gz > Homo_sapiens.GRCh38.100_and_Sars_cov_2.ASM985889v3.100.gtf 
```

<br>

### 5b. Build STAR Reference  

```
STAR --runThreadN NumberOfThreads \
  --runMode genomeGenerate \
  --limitGenomeGenerateRAM 55000000000 \
  --genomeSAindexNbases 14 \
  --genomeDir /path/to/STAR/genome/directory \
  --genomeFastaFiles /path/to/genome/fasta/file \
  --sjdbGTFfile /path/to/annotation/gtf/file \
  --sjdbOverhang ReadLength-1

```

**Input Data:** 

For processing human-filtered data
- Homo_sapiens.GRCh38.dna.primary_assembly.fa (genome sequence)
- Homo_sapiens.GRCh38.100.gtf (genome annotation)

For processing unfiltered data
- Homo_sapiens.GRCh38.dna.primary_assembly_and_Sars_cov_2.ASM985889v3.dna.primary_assembly.MN908947.3.fa (genome sequence)
- Homo_sapiens.GRCh38.100_and_Sars_cov_2.ASM985889v3.100.gtf (genome annotation)

**Output Data:**

STAR genome reference, which consists of the following files:
- chrLength.txt
- chrNameLength.txt
- chrName.txt
- chrStart.txt
- exonGeTrInfo.tab
- exonInfo.tab
- geneInfo.tab
- Genome
- genomeParameters.txt
- SA
- SAindex
- sjdbInfo.txt
- sjdbList.fromGTF.out.tab
- sjdbList.out.tab
- transcriptInfo.tab

---

<br>

## 6. Align Reads to Reference Genome with STAR and Generate STAR Counts Table

### 6a. Align Reads to Reference Genome with STAR

```
STAR --twopassMode Basic \
  --limitBAMsortRAM 65000000000 \
  --genomeDir /path/to/STAR/genome/directory \
  --outSAMunmapped Within \
  --outFilterType BySJout \
  --outSAMattributes NH HI AS nM NM MD jM jI MC ch \ #same as All
  --outSAMattrRGline ID:flowcell.laneX PL:ILLUMINA PU:flowcell.laneX.${index} LB:${sample} SM:${sample} , ID:flowcell.laneY PL:ILLUMINA PU:flowcell.laneY.${index} LB:${sample} SM:${sample} \
  --outFilterMultimapNmax 20 \
  --outFilterMismatchNmax 999 \
  --outFilterMismatchNoverReadLmax 0.04 \
  --alignIntronMin 20 \
  --alignIntronMax 1000000 \
  --alignMatesGapMax 1000000 \ # for PE only
  --alignSJoverhangMin 8 \
  --alignSJDBoverhangMin 1 \
  --sjdbScore 1 \
  --readFilesCommand zcat \
  --runThreadN NumberOfThreads \
  --chimOutType Junctions SeparateSAMold WithinBAM SoftClip \
  --chimOutJunctionFormat 1 \
  --chimSegmentMin 20 \
  --outSAMtype BAM SortedByCoordinate \
  --quantMode TranscriptomeSAM GeneCounts \
  --outSAMheaderHD @HD VN:1.4 SO:coordinate \
  --outFileNamePrefix /path/to/STAR/output/directory/${sample}/${sample}_ \
  --readFilesIn /path/to/split/trimmed/reads/${sample}/${sample}_flowcell_laneX_R1.fastq.gz,/path/to/split/trimmed/reads/${sample}/${sample}_flowcell_laneY_R1.fastq.gz /path/to/split/trimmed/reads/${sample}/${sample}_flowcell_laneX_R2.fastq.gz,/path/to/split/trimmed/reads/${sample}/${sample}_flowcell_laneY_R2.fastq.gz
```

**Input Data:**
- STAR genome reference (output from step 5b)
- \*flowcell_lane#_R\*.fastq.gz (trimmed reads split according to flowcell (i.e. sequencing run) and lane number with rRNA reads removed from step 4)
  
  Note: To process without removing rRNA reads, use \*flowcell_lane#_R\*.fq.gz (trimmed reads split according to flowcell (i.e. sequencing run) and lane number from step 3) as the input fastq files

**Output Data:**
- *Aligned.sortedByCoord.out.bam (sorted mapping to genome)
- *Aligned.toTranscriptome.out.bam (sorted mapping to transcriptome)
- *Chimeric.out.junction (chimerically aligned read data)
- *Chimeric.out.sam (sam file containing chimeric alignments)
- *Log.final.out (log file conting alignment info/stats such as reads mapped, etc)
- *Log.out
- *Log.progress.out
- *ReadsPerGene.out.tab (STAR read counts per gene)
- *SJ.out.tab (high confidence collapsed splice junctions)
- *_STARgenome (directory containing the following:)
  - sjdbInfo.txt
  - sjdbList.out.tab
- *_STARpass1 (directory containing the following:)
  - Log.final.out
  - SJ.out.tab
- *_STARtmp (directory containing the following:)
  - BAMsort (directory containing subdirectories that are empty – this was the location for temp files that were automatically removed after successful completion)

<br>

### 6b. Generate STAR Counts Table in R

```R
print("Make STAR counts table")
print("")

work_dir="/path/to/directory/containing/samples.txt/file"
align_dir="/path/to/directory/containing/STAR/counts/data"

setwd(file.path(work_dir))

### Pull in sample names ###
study <- read.csv(Sys.glob(file.path(work_dir,"samples.txt")), header = FALSE, row.names = 1, stringsAsFactors = TRUE)

##### Import Data
ff <- list.files(file.path(align_dir),pattern = "ReadsPerGene.out.tab", full.names = TRUE)
# Remove the first 4 lines
counts.files <- lapply( ff, read.table, skip = 4 )
# Get counts aligned to the second, reverse, strand
counts <- as.data.frame( sapply( counts.files, function(x) x[ , 4 ] ) )
# Add column and row names
colnames(counts) <- rownames(study)
row.names(counts) <- counts.files[[1]]$V1


##### Export unnormalized counts table
setwd(file.path(align_dir))
write.csv(counts,file='STAR_Unnormalized_Counts.csv')


## print session info ##
print("Session Info below: ")
print("")
sessionInfo()
```

**Input Data:**
- *ReadsPerGene.out.tab (STAR read counts per gene from step 6a)
- samples.txt (text file containing a single column list of all samples generated in [step 0](#0-create-sample-list))

**Output Data:**
- STAR_Unnormalized_Counts.csv (table containing STAR read counts per gene for all samples)

---

<br>

## 7. Sort and Index Genome-Aligned Data

Due to issues with the sorted genome bam file from STAR (step 6a) this file must be subsequently sorted and indexed with samtools prior to downstream analyses.

### 7a. Sort Genome-Aligned Data

```
samtools sort -m AvailableMemoryPerThread \
	--threads NumberOfThreads \
  -o /path/to/STAR/output/directory/${sample}/${sample}_Aligned.sortedByCoord_sorted.out.bam \
	/path/to/STAR/output/directory/${sample}/${sample}_Aligned.sortedByCoord.out.bam
```

**Input Data:**
- *Aligned.sortedByCoord.out.bam (sorted mapping to genome file from step 6a)

**Output Data:**
- *Aligned.sortedByCoord_sorted.out.bam (samtools sorted mapping to genome file)

<br>

### 7b. Index Sorted Genome-Aligned Data

```
samtools index -@ NumberOfThreads \
  /path/to/STAR/output/directory/${sample}/${sample}_Aligned.sortedByCoord_sorted.out.bam 
```

**Input Data:**
- *Aligned.sortedByCoord_sorted.out.bam (samtools sorted mapping to genome file from step 6a)

**Output Data:**
- *Aligned.sortedByCoord_sorted.out.bam.bai (samtools sorted mapping to genome index)

---

<br>

## 8. Alignment Data QC

### 8a. Create Reference Files

Reference files used can be found in the [Reference_Files](Reference_Files) sub-directory. The commands used to create these reference files are below:

**Create refFlat Reference**

```
gtfToGenePred -genePredExt -geneNameAsName2 Homo_sapiens.GRCh38.100_and_Sars_cov_2.ASM985889v3.100.gtf refFlat.tmp.txt
paste <(cut -f 12 refFlat.tmp.txt) <(cut -f 1-10 refFlat.tmp.txt) > Homo_sapiens.GRCh38_and_Sars_cov_2.ASM985889v3_refFlat.txt
rm refFlat.tmp.txt
```

**Input Data:**
- Homo_sapiens.GRCh38.100_and_Sars_cov_2.ASM985889v3.100.gtf (gtf file containing human and SARS-CoV-2 annotated genes from [step 5a](#5a-get-genome-and-annotation-files))

**Output Data:**
- Homo_sapiens.GRCh38_and_Sars_cov_2.ASM985889v3_refFlat.txt (gene annotations in refFlat format - you can download this reference [here](Reference_Files/Homo_sapiens.GRCh38_and_Sars_cov_2.ASM985889v3_refFlat.txt.gz))

<br>

**Define Genomic Location of rRNA Sequences in interval_list Format**

```
samtools view -H sample_Aligned.sortedByCoord_sorted.out.bam | grep '^@HD*' > Homo_sapiens.GRCh38.100_and_SARS-CoV-2_rRNA_interval_list.txt
samtools view -H sample_Aligned.sortedByCoord_sorted.out.bam | grep '^@SQ*' >> Homo_sapiens.GRCh38.100_and_SARS-CoV-2_rRNA_interval_list.txt
cat Homo_sapiens.GRCh38.100_and_Sars_cov_2.ASM985889v3.100.gtf | grep 'rRNA' | cut -s -f 1,4,5,7,9 >> Homo_sapiens.GRCh38.100_and_SARS-CoV-2_rRNA_interval_list.txt
```

**Input Data:**
- sample_Aligned.sortedByCoord_sorted.out.bam (sorted bam file of one sample generated from the samtools sorted mapping to genome [step 7a](#7a-sort-genome-aligned-data); Note: In does not matter which sample you use since the @HD and @SQ lines will be the same for each sample)
- Homo_sapiens.GRCh38.100_and_Sars_cov_2.ASM985889v3.100.gtf (gtf file containing human and SARS-CoV-2 annotated genes from [step 5a](#5a-get-genome-and-annotation-files))

**Output Data:**
- Homo_sapiens.GRCh38.100_and_SARS-CoV-2_rRNA_interval_list.txt (genomic locations of rRNA sequences in interval_list format - you can download this reference [here](Reference_Files/Homo_sapiens.GRCh38.100_and_SARS-CoV-2_rRNA_interval_list.txt))

<br>

### 8b. Generate Alignment Data QC Metrics

Generate RNAseq metrics for each sample with [GATK CollectRnaSeqMetrics](https://gatk.broadinstitute.org/hc/en-us/articles/360037057492-CollectRnaSeqMetrics-Picard-)

```
gatk CollectRnaSeqMetrics -I /path/to/STAR/output/directory/${sample}/${sample}_Aligned.sortedByCoord_sorted.out.bam \
  -O /path/to/STAR/output/directory/${sample}/${sample}_Metrics \
  --REF_FLAT /path/to/Homo_sapiens.GRCh38_and_Sars_cov_2.ASM985889v3_refFlat.txt \
  -STRAND SECOND_READ_TRANSCRIPTION_STRAND \
  --METRIC_ACCUMULATION_LEVEL ALL_READS \
  --RIBOSOMAL_INTERVALS /path/to/Homo_sapiens.GRCh38.100_and_SARS-CoV-2_rRNA_interval_list.txt
```

**Input Data:**
- *Aligned.sortedByCoord_sorted.out.bam (samtools sorted mapping to genome file from step 7a)
- Homo_sapiens.GRCh38_and_Sars_cov_2.ASM985889v3_refFlat.txt (gene annotations in refFlat format - you can download this reference [here](Reference_Files/Homo_sapiens.GRCh38_and_Sars_cov_2.ASM985889v3_refFlat.txt.gz))

  Note: This file needs to be gunzipped prior to running this command.
- Homo_sapiens.GRCh38.100_and_SARS-CoV-2_rRNA_interval_list.txt (genomic locations of rRNA sequences in interval_list format - you can download this reference [here](Reference_Files/Homo_sapiens.GRCh38.100_and_SARS-CoV-2_rRNA_interval_list.txt))

**Output Data:**
- \*_Metrics (file containing metrics about the alignment of RNAseq reads, complete list of metrics generated can be found [here](http://broadinstitute.github.io/picard/picard-metric-definitions.html#RnaSeqMetrics))
