#!/usr/bin/env python
import sys
import os
import pandas as pd

def calculate_sex(df):
    try:
        x_reads = df.loc[df['chromosome'].str.contains('X', case=False, na=False), 'reads'].sum()
        y_reads = df.loc[df['chromosome'].str.contains('Y', case=False, na=False), 'reads'].sum()

        if y_reads == 0:
            return '2'

        ratio = x_reads / y_reads
        return '2' if ratio > 4 else '1'
    except Exception as e:
        sys.stderr.write(f"Error in calculating sex: {e}\\n")
        sys.exit(1)

def main():
    input_file = sys.argv[1]

    try:
        df = pd.read_csv(input_file, sep="\t", header=None, names=["chromosome", "reads", "unmapped_reads", "base_count"])
    except FileNotFoundError:
        sys.stderr.write(f"Error: The file '{input_file}' was not found.\\n")
        sys.exit(1)
    except Exception as e:
        sys.stderr.write(f"Error reading file {input_file}: {e}\\n")
        sys.exit(1)

    sex = calculate_sex(df)
    print(sex)

if __name__ == "__main__":
    main()
