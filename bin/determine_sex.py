#!/usr/bin/env python
#
# This script determines sex from a BAM file by calculating the ratio of reads mapped to
# chromosomes 19, X, and Y using samtools.
#

import argparse
import subprocess
import os
import sys

def get_bam_chromosomes(bam_path):
    """
    Retrieves a list of chromosome names from the BAM file header.
    Returns: a list of chromosome names (strings)
    """
    try:
        header_output = subprocess.check_output(
            f"samtools view -H {bam_path} | grep ^@SQ | cut -f 2-",
            shell=True,
            text=True
        )
        chrom_names = [line.split('\t')[0].replace('SN:', '') for line in header_output.strip().split('\n')]
        return chrom_names
    except subprocess.CalledProcessError as e:
        print(f"Error reading BAM header: {e.stderr}", file=sys.stderr)
        sys.exit(1)

def get_reads_mapped_count(bam_path, chrom_name, output_dir, sample_name):
    """
    Subsets a BAM file by chromosome, computes stats, and returns the number of
    mapped reads, all in a single pipelined command.
    """
    # Create a temporary stats file
    bam_stat_path = os.path.join(output_dir, f"{sample_name}_{chrom_name}_bam_stat.txt")
    
    try:
        # Use a single command to pipe samtools view output to samtools stats
        command_line = f"samtools view -b {bam_path} {chrom_name} | samtools stats - | grep ^SN | cut -f 2- > {bam_stat_path}"
        subprocess.check_output(command_line, shell=True)
        
        # Read the stats file to get the mapped reads count
        with open(bam_stat_path, "r") as f:
            for line in f:
                if line.startswith("reads mapped and paired"):
                    return line.rstrip("\n").split("\t")[1]
    except subprocess.CalledProcessError as e:
        print(f"Warning: Samtools command failed for chromosome {chrom_name}: {e.stderr}", file=sys.stderr)
        return "0"
    except FileNotFoundError:
        print(f"Error: `samtools` command not found. Please ensure it is in your PATH.", file=sys.stderr)
        sys.exit(1)
    finally:
        # Clean up the temporary stats file
        try:
            os.remove(bam_stat_path)
        except OSError:
            pass # File might not exist if the command failed

    return "0"

def classify_sex(X_19_ratio, Y_19_ratio, Y_X_ratio):
    """
    This function classifies sex based on the ratios of mapped reads.
    :param X_19_ratio: Ratio of X chromosome reads to chromosome 19 reads.
    :param Y_19_ratio: Ratio of Y chromosome reads to chromosome 19 reads.
    :param Y_X_ratio: Ratio of Y chromosome reads to X chromosome reads.
    :return: "2" (female) or "1" (male).
    """
    # These thresholds are a simple heuristic. A more rigorous approach
    # would involve a statistical model based on a known cohort.
    if X_19_ratio >= 0.5 and Y_19_ratio <= 0.01 and Y_X_ratio <= 0.01:
        return "2"
    else:
        return "1"

def main(args):
    """
    Main function to run the sex classification pipeline.
    """
    # Create the output directory if it doesn't exist.
    os.makedirs(args.out_dir, exist_ok=True)
    
    # Check for BAM index.
    bai_path = args.bam_path + ".bai"
    if not os.path.exists(bai_path):
        print(f"Error: BAM index not found for {args.bam_path}. Please provide a .bai file.", file=sys.stderr)
        sys.exit(1)

    # Get chromosome names from the BAM header to ensure compatibility.
    bam_chromosomes = get_bam_chromosomes(args.bam_path)

    # This dictionary maps a standard chromosome name to the actual name found in the BAM header.
    # It dynamically finds the correct name for chr19, chrX, and chrY.
    chr_map = {}
    for standard_name in ["19", "X", "Y"]:
        found_name = next(
            (
                chrom_name
                for chrom_name in bam_chromosomes
                if chrom_name == standard_name or chrom_name == f"chr{standard_name}"
            ),
            None,
        )
        if found_name:
            chr_map[standard_name] = found_name
        else:
            print(f"Warning: Could not find a match for chromosome {standard_name}. Assigning 0 reads.", file=sys.stderr)
            chr_map[standard_name] = None
    
    # Initialize output file and write header.
    outfile_path = os.path.join(args.out_dir, args.sample + "_summary.tsv")
    with open(outfile_path, "w") as outfile:
        header = ["sample", "chr19", "chrX", "chrY", "X/19", "Y/19", "Y/X", "sex_prediction"]
        print("\t".join(header), file=outfile)

        # Dictionary to store read counts for each chromosome
        reads_mapped_counts = {}
        
        # Iterate over the chromosomes and get read counts
        for chrom_base in ["19", "X", "Y"]:
            chrom_name = chr_map[chrom_base]
            
            if chrom_name is None:
                reads_mapped_counts[chrom_base] = "0"
                continue

            mapped_reads = get_reads_mapped_count(
                args.bam_path, chrom_name, args.out_dir, args.sample
            )
            reads_mapped_counts[chrom_base] = mapped_reads

        # Prepare the output line
        out = [args.sample]
        out.append(reads_mapped_counts["19"])
        out.append(reads_mapped_counts["X"])
        out.append(reads_mapped_counts["Y"])

        # Calculate ratios and classify sex
        # Handle division by zero for chr19 or chrX reads being 0
        chr19_reads = float(reads_mapped_counts["19"])
        chrX_reads = float(reads_mapped_counts["X"])
        chrY_reads = float(reads_mapped_counts["Y"])

        X_19_ratio = chrX_reads / chr19_reads if chr19_reads > 0 else 0
        Y_19_ratio = chrY_reads / chr19_reads if chr19_reads > 0 else 0
        Y_X_ratio = chrY_reads / chrX_reads if chrX_reads > 0 else 0
        
        sex_prediction = classify_sex(X_19_ratio, Y_19_ratio, Y_X_ratio)

        # Append ratios and prediction to the output line
        out.extend([f"{X_19_ratio:.4f}", f"{Y_19_ratio:.4f}", f"{Y_X_ratio:.4f}", sex_prediction])
        print("\t".join(out), file=outfile)

def parse_args():
    parser = argparse.ArgumentParser(description="Classifies sex from a BAM file using read ratios on chr19, X, and Y.")
    parser.add_argument("--sample", required=True, help="Input the sample name. This is used to name output files.")
    parser.add_argument("--bam_path", required=True, help="Input the path to the BAM file.")
    parser.add_argument("--out_dir", default=os.getcwd(), help="Input the path to where all the results should be stored. Defaults to the current working directory.")
    return parser.parse_args()

if __name__ == "__main__":
    main(parse_args())
