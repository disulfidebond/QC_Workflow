# Overview
This R notebook details the steps taken for Quality Control (QC) for files transferred from the UW Biotech Center. It is downloadable as an [R Markdown notebook](https://github.com/disulfidebond/QC_Workflow/blob/main/code/generate_QC_report.Rmd) that can be run in RStudio. This Notebook should be run in the same directory as the transferred FASTQ files. Be sure to clone the repository or copy the accompanying Bash scripts that are contained within the Code directory, since these are required to run the R Notebook.

# First Step: Setup
Assign variable names to `demul_QC_report` for the Demultiplex QC Report, and to `multiQC_report` for the MultiQC Report. If you have created a fastq size report, enter this filename for `fqSizeList`, otherwise leave it blank.

```{r}
library(rvest)
library(rvest)
library(dplyr)
library(stringr)

demul_QC_report = c('Churpek_Demultiplex_Stats.htm')
multiQC_report = c('Churpek_multiqc_report.html')
`%notin%` <- Negate(`%in%`)
# See Second Step below for instructions for this
fqSizeList = c('')



# functions
sqlOuterJoin_DM <- function(t, d, c) {
  outerMerged = merge(x = t, y = d, by="Sample", all=TRUE)
  outerMerged[,c] = is.na(outerMerged$Lane.y)
  outerMerged[,c] = ifelse(outerMerged[,c] == FALSE, TRUE, FALSE)
  dropCols <- outerMerged %>% select(ends_with('.y'))
  dropCols <- colnames(dropCols)
  outerMerged = outerMerged[, -which(names(outerMerged) %in% dropCols)]
  tmpColNames = colnames(outerMerged)
  mergedColNames = str_remove(tmpColNames, '.x')
  colnames(outerMerged) = mergedColNames
  return(outerMerged)
}

sqlOuterJoin_MQC <- function(t, d, c, cNew) {
  outerMerged = merge(x = t, y = d, by="Sample Name", all=TRUE)
  outerMerged[,cNew] = is.na(outerMerged[,c])
  outerMerged[,cNew] = ifelse(outerMerged[,cNew] == FALSE, TRUE, FALSE)
  dropCols <- outerMerged %>% select(ends_with('.y'))
  dropCols <- colnames(dropCols)
  outerMerged = outerMerged[, -which(names(outerMerged) %in% dropCols)]
  tmpColNames = colnames(outerMerged)
  mergedColNames = str_remove(tmpColNames, '.x')
  # mergedColNames = str_remove(mergedColNames, ' Name')
  colnames(outerMerged) = mergedColNames
  return(outerMerged)
}
```

# First Step Continued: Check MD5 sums
It is important to verify the MD5 checksums for files that are copied. Very briefly, the md5 checksum is a cryptographic signature with multiple uses. In this context, it scans a file and generates a unique string for it. If the file has been modified in any way (down the the byte-level), then subsequent MD5 checksums will be different. Running MD5 checksums on all transferred or copied files ensures that none of the files were correputed while being copied. 
The fastq files from the Biotech Center have an accompanying file in the same directory as the fastq.gz files with the suffix `_md5sum.txt', for example, `Churpek_md5sum.txt`, which can be imported into R.

There are three ways to generate md5 checksums. First, you can use the md5 library within R, however initial testing showed that R does *not* handle running large checksums well, and doing so will probably cause R to freeze. As such, this method is mentioned but not included in this notebook.

Second, you can run the bash script `generate_md5sums.sh` and then run the python script `checkFiles.py`. You'll receive a one line output indicating if all checksums match. This has been included, but is commented out in the proceeding code block.

Third, you can enter the filename from the Biotech Center that contains the md5 checksums in the code block below, then run the code block below in R. If you see the output `all files correct`, then all md5 checksums matched for the transferred fastq.gz files.

```{r}
# enter filename from Biotech Center here
source_md5 = c('')
cmd0 = paste0('bash sed_script.sh ', source_md5)
system(cmd0)
cmd1 = c('bash generate_md5sums.sh')
print('This will take awhile to run.')
system(cmd1)
print('Finished generating md5 checksums.')
source_fName = str_replace(source_md5, '.txt', '.csv')

# read files
df_checksums = read.csv(source_fName, stringsAsFactors=FALSE)
df_generatedSums = read.csv('generated_md5_checksums.csv', stringsAsFactors=FALSE)

# perform an outer join, then check to see if any filenames are different
df_merge = merge(x=df_checksums, y=df_generatedSums, by="MD5SUM", all=TRUE)
df_check = df_merge[df_merge$FILENAME.x != df_merge$FILENAME.y,]
if (nrow(df_check) == 0) {
  print('all files correct')
} else {
  print('files missing or corrupted')
  print(df_check)
}

# second method of md5 sum comparison using python
# replace FILENAME with the filename
# cmd0 = paste0('bash generate_md5sums.sh)
# source_md5 = ('generated_md5sums.txt')
# convert md5sum text file from Biotech Center to CSV
# cmd1 = paste0('bash sed_script.sh FILENAME')
# cmd2 = c('./checkFiles.py')
# system(cmd1)
# system(cmd2)


```

# Second Step: Check Sizes of Fastq Files

There are two ways to check the file sizes. The codeblock Step 2A below is the default, and allows you to import a CSV file with file sizes. This file must be contain two comma-separated columns, with the headers `Size_in_GB,FileName`. Alternatively, you can use the bash script `generateSizeFile.sh` to generate a CSV file size list, and enter this in the first block the `fqSizeList` variable. 

```{r}
# Step 2A: import CSV file of file sizes
# # must be formatted with header as Size_in_GB,FileName
size_df = read.csv(fqSizeList, stringsAsFactors = FALSE)
fqList = size_df$FileName
fqList = str_remove(fqList, '.fastq.gz$')
size_df$FileName = fqList
sizeVec = size_df$Size_in_GB
```
The second way is in codeblock 2B, and uses R to calculate the file sizes. If you wish to use this method, then skip or comment out codeblock 2A and uncomment codeblock 2B *before* running the notebook.

If using the method in 2B, you must convert the size in bytes to the size in Gigabytes. Size in Gigabytes is commonly calculated as:

`2^30 == 1073741824 bytes == 1 GB`

instead of the SI standard of 1000000000 bytes == 1 GB. Technically it does not matter which method you use, since all values will use the same conversion, however, here we will use `2^30` size conversion, since that is what most Operating Systems (OS) use when displaying file sizes.

```{r}
# Step 2B: scan directory to get file sizes
# fqList = list.files(pattern='fastq.gz$')
# sizeVec = file.info(fqList)$size
# sizeVec = round(sizeVec/1073741824, 2)
```

# Third Step: Check for Size Differences
This step checks for size differences > 200 MB between the R1 and R2 paired end reads, which can be an indicator of potential problems with the workflow.

```{r}
sizeProblemVec_names = vector(mode="character",length=length(fqList)) 
sizeProblemVec_values = vector(mode="logical", length=length(fqList))
for (i in seq.int(1, length(fqList), 2)) {
  sizeCheck = abs(sizeVec[i] - sizeVec[i+1])
  fqR1Name = fqList[i]
  fqR2Name = fqList[i+1]
  sizeProblemVec_names[i] = fqR1Name
  sizeProblemVec_names[i+1] = fqR1Name
  if (sizeCheck > 0.2) {
    sizeProblemVec_values[i] = TRUE
    sizeProblemVec_values[i+1] = TRUE
  } else {
    sizeProblemVec_values[i] = FALSE
    sizeProblemVec_values[i+1] = FALSE
  }
}
size_df_out = data.frame(FileName = sizeProblemVec_names, FailedSizeCheck = sizeProblemVec_values)
size_df_out = size_df_out[c('FileName', 'FailedSizeCheck')]
size_df = merge(x=size_df, y=size_df_out, by="FileName")
colnames(size_df) = c('Sample', 'Size_in_GB', 'FailedSizeCheck')
size_df_filteredCols = size_df[c('Sample', 'FailedSizeCheck')]
```

# Fourth Step: Demultiplex Report
The fourth step imports the Demultiplex QC html file, and parses out the main table. It then looks to see if any mean quality scores are less than 32, and if any samples have less than 90% of the quality scores greater than 30.0

Both of these are indicators of potential problems with the workflow, such as sample degredation, improper library prep, or bad flowcells.

The summary tables are generated using SQL-style outer joins.

```{r}
page <- read_html(demul_QC_report)
dm_tables = page %>% html_table()
dm_table = dm_tables[[3]]
check_mqs = dm_table[dm_table$`Mean QualityScore` < 35,]
check_Q30bases = dm_table[dm_table$`% >= Q30bases` < 90,]

# outer join with Demultiplex QC
df_DM = sqlOuterJoin_DM(dm_table, check_mqs, c('LowMQS_Filter'))
df_DM = sqlOuterJoin_DM(df_DM, check_Q30bases, c('LowQ30_Filter'))
df_DM_filteredCols = df_DM[c('Sample','LowMQS_Filter', 'LowQ30_Filter')]

```

# Fifth Step: Check MultiQC Output
The fifth step imports the MultiQC html report, and scans the initial summary table for disparities in the MSeqs values, as well as scanning for any files that failed any of the tests.

Most of the detailed data in the MultiQC report is generated (static) images and dynamic javascript output, so this step is limited to scanning the summary data and then directing users to investigate possible QC errors in the html file.

The summary tables are generated using SQL-style outer joins.

```{r}
page <- read_html(multiQC_report)
qc_tables = page %>% html_table()
check_mqc = qc_tables[[1]]
failed_samples = check_mqc[check_mqc$`% Failed` != '0%',]

scan_mseqs = check_mqc$`M Seqs`
scan_mseqs_mean = mean(scan_mseqs)
scan_mseqs_sd = sd(scan_mseqs)
upperBound = scan_mseqs_mean + scan_mseqs_sd
lowerBound = scan_mseqs_mean - scan_mseqs_sd

variant_mseqs_u = check_mqc[(check_mqc$`M Seqs` > upperBound),]
variant_mseqs_l = check_mqc[(check_mqc$`M Seqs` < lowerBound),]
variant_mseqs = rbind(variant_mseqs_u,variant_mseqs_l)

# outer join with MultiQC
df_MQC = sqlOuterJoin_MQC(check_mqc, failed_samples, c('% Failed.y'), c('FailedQC'))
df_MQC = sqlOuterJoin_MQC(df_MQC, variant_mseqs, c('% Failed.y'), c('Variant_MSeqs'))
tmpColNames = colnames(df_MQC)
mergedColNames = str_remove(tmpColNames, ' Name')
colnames(df_MQC) <- c(mergedColNames)
df_MQC_filteredCols = df_MQC[c('Sample', 'FailedQC', 'Variant_MSeqs')]

```

# Ouput
Generate two summarized outputs. The first shows Size and MultiQC Quality Control reports, and the second shows the Demultiplex Quality Control report. The Demultiplex and MultiQC summaries must be reported separately, because the Demultiplex output does not distinguish paired reads.

```{r}
# create timestamp
ts_string = paste0(format(Sys.time(), "%H%M%S_%m%d%Y"))
# merge size QC with MultiQC
df_out1 = merge(x=df_MQC_filteredCols, y=size_df_filteredCols, by="Sample")

# format output and report completion
df_outs1_fName = paste0('qc_multiQC_Size.summary.', ts_string, '.csv')
df_outs2_fName = paste0('qc_demult.summary', ts_string, '.csv')
df_out1_fName = paste0('qc_size.detailed.', ts_string, '.csv')
df_out2_fName = paste0('qc_demult.detailed.', ts_string, '.csv')
df_out3_fName = paste0('qc_multiqc.detailed.', ts_string, '.csv')
write.csv(df_out1, df_outs1_fName)
write.csv(df_MQC_filteredCols, df_outs2_fName)
write.csv(size_df, df_out1_fName)
write.csv(df_DM, df_out2_fName)
write.csv(df_MQC, df_out3_fName)
output_verbose = paste0('QC Report finished. \nCreated two summary output files named ', df_out1_fName, ' and ', df_out2_fName)
output_verbose2 = paste0('and detailed QC files with corresponding names.')
print(output_verbose)
print(output_verbose2)


```
