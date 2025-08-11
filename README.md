# odcf/expansionhunter

[![GitHub Actions CI Status](https://github.com/odcf/expansionhunter/actions/workflows/nf-test.yml/badge.svg)](https://github.com/odcf/expansionhunter/actions/workflows/nf-test.yml)
[![GitHub Actions Linting Status](https://github.com/odcf/expansionhunter/actions/workflows/linting.yml/badge.svg)](https://github.com/odcf/expansionhunter/actions/workflows/linting.yml)[![Cite with Zenodo](http://img.shields.io/badge/DOI-10.5281/zenodo.XXXXXXX-1073c8?labelColor=000000)](https://doi.org/10.5281/zenodo.XXXXXXX)
[![nf-test](https://img.shields.io/badge/unit_tests-nf--test-337ab7.svg)](https://www.nf-test.com)

[![Nextflow](https://img.shields.io/badge/version-%E2%89%A524.10.5-green?style=flat&logo=nextflow&logoColor=white&color=%230DC09D&link=https%3A%2F%2Fnextflow.io)](https://www.nextflow.io/)
[![run with conda](http://img.shields.io/badge/run%20with-conda-3EB049?labelColor=000000&logo=anaconda)](https://docs.conda.io/en/latest/)
[![run with docker](https://img.shields.io/badge/run%20with-docker-0db7ed?labelColor=000000&logo=docker)](https://www.docker.com/)
[![run with singularity](https://img.shields.io/badge/run%20with-singularity-1d355c.svg?labelColor=000000)](https://sylabs.io/docs/)

## Introduction

**odcf/expansionhunter** is a bioinformatics pipeline to analyse Short Tandem Repeats (STRs) using a combination of Expansion Hunter, samtools, and STRANGER. It is designed to be flexible, supporting various analysis types including single-sample, trio, and somatic cases, and includes an automated sex determination step.

It is designed to be flexible, supporting various analysis types including single-sample, trio, and somatic cases, and includes an automated sex determination step.


### Pipeline Description

The pipeline's core logic adapts to your input, following these key steps:

1. **Sex Determination:** If the sex of a sample is not provided, the pipeline will automatically run the determine_sex.py script. This script analyzes the ratio of reads on chromosomes 19, X, and Y to predict the sample's sex.

2. **Expansion Hunter:** The pipeline runs the Expansion Hunter tool to analyze each sample's BAM file and identify STR expansions.

3. **Sample Merging (Conditional):** Uses SVDB merge tool. 

   - Trio Analysis: If you provide three samples (child, father, mother), the pipeline will merge the Expansion Hunter VCF files into a single output.

   - Somatic Analysis: For tumor/control sample pairs, the pipeline merges the respective VCF files.
   
   - Single Sample: For a single sample, this merging step is skipped.

4. **STRANGER Analysis:** The final step runs STRANGER on the merged or single-sample VCF files.

5. **MultiQC:** Produces final QC reports as well as the versionings of the tools used in this pipeline. 

## Usage

> [!NOTE]
> If you are new to Nextflow and nf-core, please refer to [this page](https://nf-co.re/docs/usage/installation) on how to set-up Nextflow. Make sure to [test your setup](https://nf-co.re/docs/usage/introduction#how-to-run-a-pipeline) with `-profile test` before running the workflow on actual data.

1. Download the pipeline and test it on a minimal dataset with a single command:

```bash
git clone https://github.com/kubranarci/ExpansionHunter.git
```

Make the bin directory executable:

```bash
chmod +x bin/*
```

2. Set up samplesheet.csv

A samplesheet has to have following columns

**sample:** The sample name, will be used to create final reports and rename vcf files. 

**bam:** BAM file path to the sample

**bai:** Index of bam file. 

**sex:** Gender of the sample. 2 for female, 1 for male, 0 if unknown.

**case_id:** Case if will be used for trio or somatic analysis to merge and name case samples. 

**phenotype:** Describes the phenotype of the analysis. 

   - **Trio:** father, mather or child

   - **Somatic:** tumor or control

   - **Single:** single


`samplesheet.csv`:

```csv
sample,bam,bai,sex,case_id,phenotype
triofather,triofather.bam,triofather.bam.bai,1,father,triocase
triomother,triomother.bam,triomother.bam.bai,2,mother,triocase
triochild,triochild.bam,triochild.bam.bai,1,child,triocase
somaticcontrol,somaticcontrol.bam,somaticcontrol.bam.bai,0,control,somaticcase
somatictumor,somatictumor.bam,somatictumor.bam.bai,0,tumor,somaticcasecase
test,test.bam,test.bam.bai,0,single,singlecase
```

Check out /assets/samplesheet.csv for an example sample sheet file. 

3. Prepare reference data

This pipelines needs a fasta reference with fai index and variant catalog file to run Expansion Hunter and Stranger.

- **fasta:** Path to the FASTA reference
- **fai:** Path to FAI of FASTA file
- **variant_catalog:** Path to the variant catalog, GRCh37 and GRCh38 versions from STRANGER can be find in assets/. For more, check https://github.com/Clinical-Genomics/stranger/tree/master/stranger/resources 

4. Now, you can run the pipeline using:


```bash
nextflow run odcf/expansionhunter \
   -profile <docker/singularity/.../institute> \
   --input samplesheet.csv \
   --fasta reference.fa \
   --fai reference.fai \
   --variant_catalog variant_catalog.json \
   --outdir <OUTDIR>
```

## Credits

odcf/expansionhunter was originally written by @kubranarci.

## Contributions and Support

If you would like to contribute to this pipeline, please see the [contributing guidelines](.github/CONTRIBUTING.md).

## Citations

An extensive list of references for the tools used by the pipeline can be found in the [`CITATIONS.md`](CITATIONS.md) file.
