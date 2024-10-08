# Generation and processing of in-silico mixing experiment data with CLL4 and CLL5

For historical reasons during the data analyses, the sample CLL4 is called CLL_relapse1_1 (mtDNA) or Pool91-1_22 (scRNA-seq),
while the sample from CLL5 is called CLL_relapse3_1 (mtDNA) or Pool91-1_24 (scRNA-seq) in the scripts. 

The mixing itself and variant calling were performed using shell scripts on the HMS O2 cluster.

## mtDNA-based deconvolution (mtscATAC-seq) 
To perform the mixing titration, first download the raw data (CLL4_1 and CLL5_1) from NCBI Geo (GSE163579) and process with cellranger-atac
as CLL_relapse1_1 and CLL_relapse3_1. Next, create an ArchR object ([```00_create_archr.R```](R/00_create_archr.R))

To generate the mixing steps, I first generated a list of cell barcodes from each sample for each titration step 
([```01_create_barcode_lists_atac.R```](R/01_create_barcode_lists_atac.R)).

Second, I used [sinto](https://github.com/timoast/sinto) to extract reads belonging to the cell barcodes 
([```01_processing.sh```](mtDNA/01_processing.sh)) into a new bam file for each sample and titration step.

Third, I merged the two bam files of each titration step using ([```02_merge_reads.sh```](mtDNA/02_merge_reads.sh)) 
and indexed the bam file.

Finally, I ran [mgatk](https://github.com/caleblareau/mgatk) on the merged bam files to perform discovery of 
mitochondrial DNA mutations ([```03_start_mgatk.sh```](mtDNA/03_start_mgatk.sh)).

## SNP-based deconvolution (scRNA-seq)
To perform the mixing titration, first download the raw data (CLL4_1 and CLL5_1) from NCBI Geo (GSE165087) and process with cellranger
as Pool91-1_22 and Pool91-1_24 for CLL4 and CLL5, respectively. Next, create a Seurat object 
([```10_create_seurat_object.R```](R/10_create_seurat_object.R)).

To generate the mixing steps, I first generated a list of cell barcodes from each sample for each titration step 
([```11_create_barcode_list_seurat.R```](R/11_create_barcode_list_seurat.R)).

Second, I used [sinto](https://github.com/timoast/sinto) to extract reads belonging to the cell barcodes 
([```01_processing.sh```](SNP/01_processing.sh)) into a new bam file for each sample and titration step.

Third, I merged the two bam files of each titration step using ([```02_merge_reads.sh```](mtDNA/02_merge_reads.sh)) 
and indexed the bam file.

Finally, I ran [souporcell](https://github.com/wheaton5/souporcell) and [vireo](https://github.com/single-cell-genetics/vireo)
for deconvolution with and without a germline reference. 

### souporcell without germline reference
Run souporcell ([```03_start_souporcell.sh```](SNP/03_start_souporcell.sh)).

### souporcell with germline reference
I was unable to make this work despite contacting Haynes Heaton directly. 

### vireo without germline reference
Run [cellsnp-lite](https://github.com/single-cell-genetics/cellsnp-lite) ([```04_start_cellsnp.sh```](SNP/04_start_cellsnp.sh)) 
followed by vireo ([```06_start_vireo_no_reference.sh```](SNP/06_start_vireo_no_reference.sh)).

### vireo with germline reference
Generate germline reference ([```cellsnp-lite.sh```](SNP/cellsnp-lite.sh)), then run 
vireo ([```05_start_vireo.sh```](SNP/05_start_vireo.sh)).
