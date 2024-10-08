library(ArchR)
library(Rsamtools)
library(gplots)

# fix for ArchR 
source('./R/20200708_filter_doublets_archr_fix.R')

addArchRGenome('hg38')

AML.input.files = createArrowFiles(inputFiles = c('./data/10026/AML1026_12/fragments.tsv.gz',
                                                  './data/10026/AML1026_34/fragments.tsv.gz'),
                                   sampleNames = c('AML1026_12','AML1026_34'),
                                   minTSS = 4, minFrags = 1000, addTileMat = T, addGeneScoreMat = T, threads = 12)

doubScores <- addDoubletScores(input = AML.input.files, k = 10, knnMethod = "UMAP", LSIMethod = 1, threads = 1)

# create ArchR Project
AML.1026 = ArchRProject(ArrowFiles = AML.input.files, outputDirectory = './data/10026/AML.1026', copyArrows = F)

# filter doublets
AML.1026 = filterDoublets(AML.1026)

# basic clustering to identify CLL cells
AML.1026 = addIterativeLSI(ArchRProj = AML.1026, useMatrix = 'TileMatrix', name = 'IterativeLSI', 
                           iterations = 4, clusterParams = list(resolution = 1, sampleCells = 10000, n.start = 10),
                           varFeatures = 25000, dimsToUse = 1:30)
AML.1026 = addClusters(input = AML.1026, reducedDims = 'IterativeLSI', method = 'Seurat', name = 'Clusters', resolution = 1)
set.seed(1987)
AML.1026 = addUMAP(ArchRProj = AML.1026, reducedDims = 'IterativeLSI', name = 'UMAP', nNeighbors = 30, minDist = 0.5, metric = 'cosine', force = T)
AML.1026 = addImputeWeights(AML.1026)

saveArchRProject(AML.1026)

### subset cells with available mitochondrial barcoding 
combined.mutation.frequencies = readRDS('./data/10026/mtDNA/20210429_AML1026_combined_mutation_frequencies.rds')
AML.1026.mito = subsetArchRProject(ArchRProj = AML.1026, 
                                     cells = AML.1026$cellNames[which(AML.1026$cellNames %in% colnames(combined.mutation.frequencies))],
                                     outputDirectory = './data/10026/AML.1026.mito/', threads = 12)
AML.1026.mito = addClusters(input = AML.1026.mito, reducedDims = 'IterativeLSI', method = 'Seurat', name = 'Clusters', resolution = 0.3, force = T)
AML.1026.mito = addUMAP(ArchRProj = AML.1026.mito, reducedDims = 'IterativeLSI', name = 'UMAP', nNeighbors = 30, minDist = 0.5, metric = 'cosine', force = T)
AML.1026.mito = addImputeWeights(AML.1026.mito)
saveArchRProject(AML.1026.mito)

# plot mitochondrial barcodes
p=plotEmbedding(AML.1026.mito)
plotPDF(p, name = 'AML.1026.mito.umap', ArchRProj = AML.1026.mito, width = 4, height = 4, addDOC = F)
for (mutation in rownames(combined.mutation.frequencies)) {
  AML.1026.mito$vaf = unlist(combined.mutation.frequencies[mutation, AML.1026.mito$cellNames])
  AML.1026.mito$vaf[which(AML.1026.mito$vaf > 0.1)] = 0.1
  p= plotEmbedding(AML.1026.mito, name = 'vaf', pal = c('grey','red'), plotAs = 'points', na.rm=T) + 
    ggtitle(mutation) + theme(plot.title = element_text(hjust = 0.5))
  plotPDF(p, name = paste0('AML.1026.mito.',mutation), ArchRProj = AML.1026.mito, addDOC = F, width = 4, height = 4)
}

# import TSB 
TSB.so = readRDS('./data/10026/objects/20210601_TSB.so.rds')

ADT.data = t(GetAssayData(TSB.so)[,gsub(AML.1026.mito$cellNames, pattern = '-1', replacement = '')])
for (protein in colnames(ADT.data)) {
  AML.1026.mito = addCellColData(AML.1026.mito, data = ADT.data[,protein], cells = rownames(AML.1026.mito), name = protein)
}

p <- plotEmbedding(
  ArchRProj = AML.1026.mito, 
  name = rownames(TSB.so)
)
plotPDF(plotList = p, name = "ASAP.seq", ArchRProj = AML.1026.mito, addDOC = FALSE, width = 5, height = 5)

# add information on samples
cells.by.sample = read.table('./data/10026/20210611_cells_by_sample.csv')
AML.1026.mito = addCellColData(AML.1026.mito, 
                               data = cells.by.sample$sample[which(cells.by.sample$barcode %in% AML.1026.mito$cellNames)], 
                               cells = cells.by.sample$barcode[which(cells.by.sample$barcode %in% AML.1026.mito$cellNames)],
                               name = 'Sample.hash')
