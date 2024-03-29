## Lab 7 - RNA-Seq Workflow

# BioConducter is a large group of bioinformatics R packages that are often used together
# to create workflows for bioinformatics data, including RNA-Seq analysis, NGS analysis,
# and more. 

# To install BioConducter and related packages, 
if (!requireNamespace('BiocManager', quietly = TRUE))
  install.packages("BiocManager")
BiocManager::install("rnaseqGene")

# rnaseqGene is a vignette (workflow?) that presents an example of an RNA-Seq workflow
# to show how it works. The format to download rnaseqGene is the same format to download
# any BioConducter package/vignette.

# The following is the script for the workflow for the rnaseqGene vignette. The Lab 7 
# RMarkdown file contains this script converted to RMarkdown format and with additional 
# notes made by me. 


## RNA-Seq Workflow script from rnaseqGene package to test that the package is working properly

## ----style, echo=FALSE, message=FALSE, warning=FALSE, results="asis"----------
library("BiocStyle")
library("knitr")
library("rmarkdown")
opts_chunk$set(message = FALSE, error = FALSE, warning = FALSE,
               cache = FALSE, fig.width = 5, fig.height = 5)

## ----loadairway---------------------------------------------------------------
library("airway")

## ----dir----------------------------------------------------------------------
dir <- system.file("extdata", package="airway", mustWork=TRUE)

## ----list.files---------------------------------------------------------------
list.files(dir)
list.files(file.path(dir, "quants"))

## ----sampleinfo---------------------------------------------------------------
csvfile <- file.path(dir, "sample_table.csv")
coldata <- read.csv(csvfile, row.names=1, stringsAsFactors=FALSE)
coldata

## ----makecoldata--------------------------------------------------------------
coldata <- coldata[1:2,]
coldata$names <- coldata$Run
coldata$files <- file.path(dir, "quants", coldata$names, "quant.sf.gz")
file.exists(coldata$files)

## ----tximeta, message=TRUE----------------------------------------------------
library("tximeta")
se <- tximeta(coldata)

## ----lookse-------------------------------------------------------------------
dim(se)
head(rownames(se))

## ----summarize, message=TRUE--------------------------------------------------
gse <- summarizeToGene(se)

## ----lookgse------------------------------------------------------------------
dim(gse)
head(rownames(gse))

## ----sumexp, echo=FALSE-------------------------------------------------------
par(mar=c(0,0,0,0))
plot(1,1,xlim=c(0,100),ylim=c(0,100),bty="n",
     type="n",xlab="",ylab="",xaxt="n",yaxt="n")
polygon(c(45,90,90,45),c(5,5,70,70),col="pink",border=NA)
polygon(c(45,90,90,45),c(68,68,70,70),col="pink3",border=NA)
text(67.5,40,"assay(s)")
text(67.5,35,'e.g. "counts", ...')
polygon(c(10,40,40,10),c(5,5,70,70),col="skyblue",border=NA)
polygon(c(10,40,40,10),c(68,68,70,70),col="skyblue3",border=NA)
text(25,40,"rowRanges")
polygon(c(45,90,90,45),c(75,75,95,95),col="palegreen",border=NA)
polygon(c(45,47,47,45),c(75,75,95,95),col="palegreen3",border=NA)
text(67.5,85,"colData")

## ----loadfullgse--------------------------------------------------------------
data(gse)
gse

## ----assaysgse----------------------------------------------------------------
assayNames(gse)
head(assay(gse), 3)
colSums(assay(gse))

## ----rowrangesgse-------------------------------------------------------------
rowRanges(gse)

## ----lookseqinfo--------------------------------------------------------------
seqinfo(rowRanges(gse))

## ----coldatagse---------------------------------------------------------------
colData(gse)

## ----gsevars------------------------------------------------------------------
gse$donor
gse$condition

## ----gsevarsrename------------------------------------------------------------
gse$cell <- gse$donor
gse$dex <- gse$condition

## ----renamelevels-------------------------------------------------------------
levels(gse$dex)
# when renaming levels, the order must be preserved!
levels(gse$dex) <- c("untrt", "trt")

## ----gsedex-------------------------------------------------------------------
library("magrittr")
gse$dex %<>% relevel("untrt")
gse$dex

## ----explaincmpass, eval = FALSE----------------------------------------------
#  gse$dex <- relevel(gse$dex, "untrt")

## ----countreads---------------------------------------------------------------
round( colSums(assay(gse)) / 1e6, 1 )

## ----loaddeseq2---------------------------------------------------------------
library("DESeq2")

## ----makedds------------------------------------------------------------------
dds <- DESeqDataSet(gse, design = ~ cell + dex)

## -----------------------------------------------------------------------------
countdata <- round(assays(gse)[["counts"]])
head(countdata, 3)

## -----------------------------------------------------------------------------
coldata <- colData(gse)

## -----------------------------------------------------------------------------
ddsMat <- DESeqDataSetFromMatrix(countData = countdata,
                                 colData = coldata,
                                 design = ~ cell + dex)

## -----------------------------------------------------------------------------
nrow(dds)
keep <- rowSums(counts(dds)) > 1
dds <- dds[keep,]
nrow(dds)

## -----------------------------------------------------------------------------
# at least 3 samples with a count of 10 or higher
keep <- rowSums(counts(dds) >= 10) >= 3

## ----meanSdCts----------------------------------------------------------------
lambda <- 10^seq(from = -1, to = 2, length = 1000)
cts <- matrix(rpois(1000*100, lambda), ncol = 100)
library("vsn")
meanSdPlot(cts, ranks = FALSE)

## ----meanSdLogCts-------------------------------------------------------------
log.cts.one <- log2(cts + 1)
meanSdPlot(log.cts.one, ranks = FALSE)

## ----vst----------------------------------------------------------------------
vsd <- vst(dds, blind = FALSE)
head(assay(vsd), 3)
colData(vsd)

## ----rlog---------------------------------------------------------------------
rld <- rlog(dds, blind = FALSE)
head(assay(rld), 3)

## ----transformplot, fig.width = 6, fig.height = 2.5---------------------------
library("dplyr")
library("ggplot2")

dds <- estimateSizeFactors(dds)

df <- bind_rows(
  as_data_frame(log2(counts(dds, normalized=TRUE)[, 1:2]+1)) %>%
    mutate(transformation = "log2(x + 1)"),
  as_data_frame(assay(vsd)[, 1:2]) %>% mutate(transformation = "vst"),
  as_data_frame(assay(rld)[, 1:2]) %>% mutate(transformation = "rlog"))

colnames(df)[1:2] <- c("x", "y")  

lvls <- c("log2(x + 1)", "vst", "rlog")
df$transformation <- factor(df$transformation, levels=lvls)

ggplot(df, aes(x = x, y = y)) + geom_hex(bins = 80) +
  coord_fixed() + facet_grid( . ~ transformation)  

## -----------------------------------------------------------------------------
sampleDists <- dist(t(assay(vsd)))
sampleDists

## -----------------------------------------------------------------------------
library("pheatmap")
library("RColorBrewer")

## ----distheatmap, fig.width = 6.1, fig.height = 4.5---------------------------
sampleDistMatrix <- as.matrix( sampleDists )
rownames(sampleDistMatrix) <- paste( vsd$dex, vsd$cell, sep = " - " )
colnames(sampleDistMatrix) <- NULL
colors <- colorRampPalette( rev(brewer.pal(9, "Blues")) )(255)
pheatmap(sampleDistMatrix,
         clustering_distance_rows = sampleDists,
         clustering_distance_cols = sampleDists,
         col = colors)

## -----------------------------------------------------------------------------
library("PoiClaClu")
poisd <- PoissonDistance(t(counts(dds)))

## ----poisdistheatmap, fig.width = 6.1, fig.height = 4.5-----------------------
samplePoisDistMatrix <- as.matrix( poisd$dd )
rownames(samplePoisDistMatrix) <- paste( dds$dex, dds$cell, sep=" - " )
colnames(samplePoisDistMatrix) <- NULL
pheatmap(samplePoisDistMatrix,
         clustering_distance_rows = poisd$dd,
         clustering_distance_cols = poisd$dd,
         col = colors)

## ----plotpca, fig.width=6, fig.height=4.5-------------------------------------
plotPCA(vsd, intgroup = c("dex", "cell"))

## -----------------------------------------------------------------------------
pcaData <- plotPCA(vsd, intgroup = c( "dex", "cell"), returnData = TRUE)
pcaData
percentVar <- round(100 * attr(pcaData, "percentVar"))

## ----ggplotpca, fig.width=6, fig.height=4.5-----------------------------------
ggplot(pcaData, aes(x = PC1, y = PC2, color = dex, shape = cell)) +
  geom_point(size =3) +
  xlab(paste0("PC1: ", percentVar[1], "% variance")) +
  ylab(paste0("PC2: ", percentVar[2], "% variance")) +
  coord_fixed() +
  ggtitle("PCA with VST data")

## -----------------------------------------------------------------------------
library("glmpca")
gpca <- glmpca(counts(dds), L=2)
gpca.dat <- gpca$factors
gpca.dat$dex <- dds$dex
gpca.dat$cell <- dds$cell

## ----glmpca, fig.width=6, fig.height=4.5--------------------------------------
ggplot(gpca.dat, aes(x = dim1, y = dim2, color = dex, shape = cell)) +
  geom_point(size =3) + coord_fixed() + ggtitle("glmpca - Generalized PCA")

## ----mdsvst, fig.width=6, fig.height=4.5--------------------------------------
mds <- as.data.frame(colData(vsd))  %>%
  cbind(cmdscale(sampleDistMatrix))
ggplot(mds, aes(x = `1`, y = `2`, color = dex, shape = cell)) +
  geom_point(size = 3) + coord_fixed() + ggtitle("MDS with VST data")

## ----mdspois, fig.width=6, fig.height=4.5-------------------------------------
mdsPois <- as.data.frame(colData(dds)) %>%
  cbind(cmdscale(samplePoisDistMatrix))
ggplot(mdsPois, aes(x = `1`, y = `2`, color = dex, shape = cell)) +
  geom_point(size = 3) + coord_fixed() + ggtitle("MDS with PoissonDistances")

## ----airwayDE-----------------------------------------------------------------
dds <- DESeq(dds)

## -----------------------------------------------------------------------------
res <- results(dds)
res

## -----------------------------------------------------------------------------
res <- results(dds, contrast=c("dex","trt","untrt"))

## -----------------------------------------------------------------------------
mcols(res, use.names = TRUE)

## -----------------------------------------------------------------------------
summary(res)

## -----------------------------------------------------------------------------
res.05 <- results(dds, alpha = 0.05)
table(res.05$padj < 0.05)

## -----------------------------------------------------------------------------
resLFC1 <- results(dds, lfcThreshold=1)
table(resLFC1$padj < 0.1)

## -----------------------------------------------------------------------------
results(dds, contrast = c("cell", "N061011", "N61311"))

## ----sumres-------------------------------------------------------------------
sum(res$pvalue < 0.05, na.rm=TRUE)
sum(!is.na(res$pvalue))

## -----------------------------------------------------------------------------
sum(res$padj < 0.1, na.rm=TRUE)

## -----------------------------------------------------------------------------
resSig <- subset(res, padj < 0.1)
head(resSig[ order(resSig$log2FoldChange), ])

## -----------------------------------------------------------------------------
head(resSig[ order(resSig$log2FoldChange, decreasing = TRUE), ])

## ----plotcounts---------------------------------------------------------------
topGene <- rownames(res)[which.min(res$padj)]
plotCounts(dds, gene = topGene, intgroup=c("dex"))

## ----ggplotcountsjitter, fig.width = 4, fig.height = 3------------------------
library("ggbeeswarm")
geneCounts <- plotCounts(dds, gene = topGene, intgroup = c("dex","cell"),
                         returnData = TRUE)
ggplot(geneCounts, aes(x = dex, y = count, color = cell)) +
  scale_y_log10() +  geom_beeswarm(cex = 3)

## ----ggplotcountsgroup, fig.width = 4, fig.height = 3-------------------------
ggplot(geneCounts, aes(x = dex, y = count, color = cell, group = cell)) +
  scale_y_log10() + geom_point(size = 3) + geom_line()

## ----plotma-------------------------------------------------------------------
library("apeglm")
resultsNames(dds)
res <- lfcShrink(dds, coef="dex_trt_vs_untrt", type="apeglm")
plotMA(res, ylim = c(-5, 5))

## ----plotmaNoShr--------------------------------------------------------------
res.noshr <- results(dds, name="dex_trt_vs_untrt")
plotMA(res.noshr, ylim = c(-5, 5))

## ----plotmalabel--------------------------------------------------------------
plotMA(res, ylim = c(-5,5))
topGene <- rownames(res)[which.min(res$padj)]
with(res[topGene, ], {
  points(baseMean, log2FoldChange, col="dodgerblue", cex=2, lwd=2)
  text(baseMean, log2FoldChange, topGene, pos=2, col="dodgerblue")
})

## ----histpvalue2--------------------------------------------------------------
hist(res$pvalue[res$baseMean > 1], breaks = 0:20/20,
     col = "grey50", border = "white")

## -----------------------------------------------------------------------------
library("genefilter")
topVarGenes <- head(order(rowVars(assay(vsd)), decreasing = TRUE), 20)

## ----genescluster-------------------------------------------------------------
mat  <- assay(vsd)[ topVarGenes, ]
mat  <- mat - rowMeans(mat)
anno <- as.data.frame(colData(vsd)[, c("cell","dex")])
pheatmap(mat, annotation_col = anno)

## ----sensitivityovermean, fig.width=6-----------------------------------------
qs <- c(0, quantile(resLFC1$baseMean[resLFC1$baseMean > 0], 0:6/6))
bins <- cut(resLFC1$baseMean, qs)
levels(bins) <- paste0("~", round(signif((qs[-1] + qs[-length(qs)])/2, 2)))
fractionSig <- tapply(resLFC1$pvalue, bins, function(p)
  mean(p < .05, na.rm = TRUE))
barplot(fractionSig, xlab = "mean normalized count",
        ylab = "fraction of small p values")

## ---- eval=FALSE--------------------------------------------------------------
#  library("IHW")
#  res.ihw <- results(dds, filterFun=ihw)

## -----------------------------------------------------------------------------
library("AnnotationDbi")
library("org.Hs.eg.db")

## -----------------------------------------------------------------------------
columns(org.Hs.eg.db)

## -----------------------------------------------------------------------------
ens.str <- substr(rownames(res), 1, 15)
res$symbol <- mapIds(org.Hs.eg.db,
                     keys=ens.str,
                     column="SYMBOL",
                     keytype="ENSEMBL",
                     multiVals="first")
res$entrez <- mapIds(org.Hs.eg.db,
                     keys=ens.str,
                     column="ENTREZID",
                     keytype="ENSEMBL",
                     multiVals="first")

## -----------------------------------------------------------------------------
resOrdered <- res[order(res$pvalue),]
head(resOrdered)

## ----eval=FALSE---------------------------------------------------------------
#  resOrderedDF <- as.data.frame(resOrdered)[1:100, ]
#  write.csv(resOrderedDF, file = "results.csv")

## ----eval=FALSE---------------------------------------------------------------
#  library("ReportingTools")
#  htmlRep <- HTMLReport(shortName="report", title="My report",
#                        reportDirectory="./report")
#  publish(resOrderedDF, htmlRep)
#  url <- finish(htmlRep)
#  browseURL(url)

## -----------------------------------------------------------------------------
resGR <- lfcShrink(dds, coef="dex_trt_vs_untrt", type="apeglm", format="GRanges")
resGR

## -----------------------------------------------------------------------------
ens.str <- substr(names(resGR), 1, 15)
resGR$symbol <- mapIds(org.Hs.eg.db, ens.str, "SYMBOL", "ENSEMBL")

## -----------------------------------------------------------------------------
library("Gviz")

## -----------------------------------------------------------------------------
window <- resGR[topGene] + 1e6
strand(window) <- "*"
resGRsub <- resGR[resGR %over% window]
naOrDup <- is.na(resGRsub$symbol) | duplicated(resGRsub$symbol)
resGRsub$group <- ifelse(naOrDup, names(resGRsub), resGRsub$symbol)

## -----------------------------------------------------------------------------
status <- factor(ifelse(resGRsub$padj < 0.05 & !is.na(resGRsub$padj),
                        "sig", "notsig"))

## ----gvizplot-----------------------------------------------------------------
options(ucscChromosomeNames = FALSE)
g <- GenomeAxisTrack()
a <- AnnotationTrack(resGRsub, name = "gene ranges", feature = status)
d <- DataTrack(resGRsub, data = "log2FoldChange", baseline = 0,
               type = "h", name = "log2 fold change", strand = "+")
plotTracks(list(g, d, a), groupAnnotation = "group",
           notsig = "grey", sig = "hotpink")

## -----------------------------------------------------------------------------
library("sva")

## -----------------------------------------------------------------------------
dat  <- counts(dds, normalized = TRUE)
idx  <- rowMeans(dat) > 1
dat  <- dat[idx, ]
mod  <- model.matrix(~ dex, colData(dds))
mod0 <- model.matrix(~   1, colData(dds))
svseq <- svaseq(dat, mod, mod0, n.sv = 2)
svseq$sv

## ----svaplot------------------------------------------------------------------
par(mfrow = c(2, 1), mar = c(3,5,3,1))
for (i in 1:2) {
  stripchart(svseq$sv[, i] ~ dds$cell, vertical = TRUE, main = paste0("SV", i))
  abline(h = 0)
}

## -----------------------------------------------------------------------------
ddssva <- dds
ddssva$SV1 <- svseq$sv[,1]
ddssva$SV2 <- svseq$sv[,2]
design(ddssva) <- ~ SV1 + SV2 + dex

## -----------------------------------------------------------------------------
library("RUVSeq")

## -----------------------------------------------------------------------------
set <- newSeqExpressionSet(counts(dds))
idx  <- rowSums(counts(set) > 5) >= 2
set  <- set[idx, ]
set <- betweenLaneNormalization(set, which="upper")
not.sig <- rownames(res)[which(res$pvalue > .1)]
empirical <- rownames(set)[ rownames(set) %in% not.sig ]
set <- RUVg(set, empirical, k=2)
pData(set)

## ----ruvplot------------------------------------------------------------------
par(mfrow = c(2, 1), mar = c(3,5,3,1))
for (i in 1:2) {
  stripchart(pData(set)[, i] ~ dds$cell, vertical = TRUE, main = paste0("W", i))
  abline(h = 0)
}

## -----------------------------------------------------------------------------
ddsruv <- dds
ddsruv$W1 <- set$W_1
ddsruv$W2 <- set$W_2
design(ddsruv) <- ~ W1 + W2 + dex

## -----------------------------------------------------------------------------
library("fission")
data("fission")
ddsTC <- DESeqDataSet(fission, ~ strain + minute + strain:minute)

## ----fissionDE----------------------------------------------------------------
ddsTC <- DESeq(ddsTC, test="LRT", reduced = ~ strain + minute)
resTC <- results(ddsTC)
resTC$symbol <- mcols(ddsTC)$symbol
head(resTC[order(resTC$padj),], 4)

## ----fissioncounts, fig.width=6, fig.height=4.5-------------------------------
fiss <- plotCounts(ddsTC, which.min(resTC$padj), 
                   intgroup = c("minute","strain"), returnData = TRUE)
fiss$minute <- as.numeric(as.character(fiss$minute))
ggplot(fiss,
       aes(x = minute, y = count, color = strain, group = strain)) + 
  geom_point() + stat_summary(fun.y=mean, geom="line") +
  scale_y_log10()

## -----------------------------------------------------------------------------
resultsNames(ddsTC)
res30 <- results(ddsTC, name="strainmut.minute30", test="Wald")
res30[which.min(resTC$padj),]

## -----------------------------------------------------------------------------
betas <- coef(ddsTC)
colnames(betas)

## ----fissionheatmap-----------------------------------------------------------
topGenes <- head(order(resTC$padj),20)
mat <- betas[topGenes, -c(1,2)]
thr <- 3 
mat[mat < -thr] <- -thr
mat[mat > thr] <- thr
pheatmap(mat, breaks=seq(from=-thr, to=thr, length=101),
         cluster_col=FALSE)

## -----------------------------------------------------------------------------
sessionInfo()