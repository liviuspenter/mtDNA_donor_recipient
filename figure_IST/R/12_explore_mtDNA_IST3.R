# create ArchR object just for patient IST3 (samples IST4_1, IST4_2) and explore mtDNA mutations

library(ArchR)
library(ggplot2)
library(ggrepel)
library(gplots)
library(grid)
library(parallel)
library(Signac)
library(Seurat)
library(BuenColors)
library(dplyr)

IST.asap.mito = loadArchRProject('./data/IST/IST.asap.mito/')
combined.mutation.frequencies = readRDS('./data/IST/mtDNA/20220110_IST4_combined_mutation_frequencies.rds')

germline.variants = read.csv2(file='./data/IST/objects/20220117_IST_germline_variants.csv')
# germline variants with incomplete coverage
exclude.variants = c('310T>C')
non.germline.variants = setdiff(rownames(combined.mutation.frequencies), c(exclude.variants, germline.variants$variant[which(germline.variants$sample == 'IST4')]))

IST.asap.mito.4 = subsetArchRProject(ArchRProj = IST.asap.mito, 
                                     cells = IST.asap.mito$cellNames[which(IST.asap.mito$patient == 'IST4')],
                                     outputDirectory = './data/IST/IST.asap.mito.4/', threads = 12, force = T)
IST.asap.mito.4 = addClusters(input = IST.asap.mito.4, reducedDims = 'IterativeLSI', method = 'Seurat', name = 'Clusters', resolution = 0.3, force = T)
IST.asap.mito.4 = addUMAP(ArchRProj = IST.asap.mito.4, reducedDims = 'IterativeLSI', name = 'UMAP', nNeighbors = 30, minDist = 0.5, metric = 'cosine', force = T)

IST.asap.mito.4$manual.cluster[which(IST.asap.mito.4$Clusters %in% c('C5', 'C6'))] = 'TNK'
IST.asap.mito.4$manual.cluster[which(IST.asap.mito.4$Clusters %in% c('C3', 'C4'))] = 'B cell'
IST.asap.mito.4$manual.cluster[which(IST.asap.mito.4$Clusters %in% c('C1','C2'))] = 'Myeloid'
IST.asap.mito.4 = addImputeWeights(IST.asap.mito.4)
saveArchRProject(IST.asap.mito.4)

# plot mitochondrial barcodes
for (mutation in rownames(combined.mutation.frequencies)) {
  IST.asap.mito.4$vaf = unlist(combined.mutation.frequencies[mutation, IST.asap.mito.4$cellNames])
  IST.asap.mito.4$vaf[which(IST.asap.mito.4$vaf > 0.1)] = 0.1
  p= plotEmbedding(IST.asap.mito.4, name = 'vaf', pal = c('grey','red'), plotAs = 'points', na.rm=T) + 
    ggtitle(mutation) + theme(plot.title = element_text(hjust = 0.5))
  plotPDF(p, name = paste0('IST4.mito.',mutation), ArchRProj = IST.asap.mito.4, addDOC = F, width = 4, height = 4)
}

# % cells marked by mtDNA mutations in donor and recipient, pre and post per celltype
donor.cells = IST.asap.mito.4$cellNames[which(IST.asap.mito.4$individual == 'donor')]
recipient.cells = IST.asap.mito.4$cellNames[which(IST.asap.mito.4$individual == 'recipient')]
mtDNA.statistics.all = data.frame()
mtDNA.statistics = list()
for (celltype in unique(IST.asap.mito.4$manual.cluster)) {
  mtDNA.statistics = append(mtDNA.statistics, list(data.frame(mtDNA.mutation = as.character(), sample = as.character(), 
                                                              cells = as.numeric(), frequency = as.numeric())))
}
names(mtDNA.statistics) = unique(IST.asap.mito.4$manual.cluster)

# number of mtDNA mutations per celltype
for (sample in unique(IST.asap.mito.4$Sample)) {
  for (celltype in unique(IST.asap.mito.4$manual.cluster)) {
    cells = intersect(IST.asap.mito.4$cellNames[which(IST.asap.mito.4$Sample == sample & IST.asap.mito.4$manual.cluster == celltype)], donor.cells)
    cells.2 = intersect(IST.asap.mito.4$cellNames[which(IST.asap.mito.4$Sample == sample & IST.asap.mito.4$manual.cluster == celltype)], recipient.cells)
    for (mtDNA.mutation in non.germline.variants) {
      mtDNA.statistics[celltype][[1]] = rbind(mtDNA.statistics[celltype][[1]], 
                                         data.frame(mtDNA.mutation = mtDNA.mutation, sample = sample, 
                                                    cells = length(which(combined.mutation.frequencies[mtDNA.mutation,cells] > 0.05)),
                                                    frequency = length(which(combined.mutation.frequencies[mtDNA.mutation,cells] > 0.05)) / length(cells)))
      mtDNA.statistics.all = rbind(mtDNA.statistics.all, data.frame(mtDNA.mutation = mtDNA.mutation, 
                                                                    sample = sample, 
                                                                    cells = length(which(combined.mutation.frequencies[mtDNA.mutation,cells] > 0.05)),
                                                                    frequency = length(which(combined.mutation.frequencies[mtDNA.mutation,cells] > 0.05)) / 
                                                                      length(cells),
                                                                    celltype = celltype, 
                                                                    individual = 'donor'))
      mtDNA.statistics.all = rbind(mtDNA.statistics.all, data.frame(mtDNA.mutation = mtDNA.mutation, 
                                                                    sample = sample, 
                                                                    cells = length(which(combined.mutation.frequencies[mtDNA.mutation,cells.2] > 0.05)),
                                                                    frequency = length(which(combined.mutation.frequencies[mtDNA.mutation,cells.2] > 0.05)) / 
                                                                      length(cells.2),
                                                                    celltype = celltype, 
                                                                    individual = 'recipient'))
    }
  }
}
write.csv2(mtDNA.statistics.all, file = './data/IST/mtDNA/20220119_IST4_mtDNA_statistics.csv', quote = F, row.names = F)
