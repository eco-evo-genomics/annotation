#!/bin/bash -l

# ================================================================
# EviAnn annotation pipeline: FAST setup & execution
#
# Before running this script, make sure you have the following:
# 1. A Conda environment called `gene_annotation` with:
#    - entrez-direct (for esearch/efetch)
#    - EviAnn (https://github.com/alekseyzimin/EviAnn_release)
#
# If you don't know how to set this up, follow these steps:
# ------------------------------------------------------------
# mamba create -n gene_annotation -c conda-forge -c bioconda entrez-direct
# git clone https://github.com/alekseyzimin/EviAnn_release
# cd EviAnn_release && chmod +x eviann.sh
# Add the `eviann.sh` script to your PATH or specify its full path below
# ================================================================

# -----------------------------
# User-defined variables, change accordingly 
# -----------------------------
# Activate your Conda environment (must include entrez-direct and EviAnn)
CONDA_ENV="gene_annotation"

# Taxon ID to download protein sequences (for example, Insecta = 50557)
TAXON_ID="50557"

# Output name for downloaded protein file
PROTEIN_OUTPUT="proteins.fasta"

# Input genome assembly file (FASTA format)
GENOME_FASTA="genome.fasta"

# Directory containing RNA-seq FASTQ files
RNASEQ_DIR="./rnaseq"

# File containing paths to paired RNA-seq reads
PAIRED_FILE="paired.txt"

# Number of threads for EviAnn
THREADS=24

# Minimum protein size (recommended: 500000 for insects, default: 250000)
MIN_PROTEINS=500000

# lncRNA minimum TPM
LNCRNA_MIN_TPM=1

# -----------------------------
# Step 1: Activate environment
# -----------------------------
echo "[INFO] Activating conda environment: $CONDA_ENV"
mamba activate "$CONDA_ENV"

# -----------------------------
# Step 2: Download protein sequences
# -----------------------------
echo "[INFO] Downloading proteins from NCBI for taxon ID: $TAXON_ID"
echo "[INFO] Output file: $PROTEIN_OUTPUT"

esearch -db protein -query "txid${TAXON_ID}[Organism:exp]" | efetch -format fasta > "$PROTEIN_OUTPUT"

if [ $? -ne 0 ]; then
    echo "[ERROR] Failed to download proteins. Please check internet connection and NCBI status."
    exit 1
fi

# -----------------------------
# Step 3: Check/create RNA-seq directory and move fastq files
# -----------------------------
echo "[INFO] Checking for RNA-seq directory: $RNASEQ_DIR"

if [ ! -d "$RNASEQ_DIR" ]; then
    echo "[WARNING] RNA-seq directory not found. Creating: $RNASEQ_DIR"
    mkdir -p "$RNASEQ_DIR"

    echo "[INFO] Moving *_R1.fastq and *_R2.fastq files into $RNASEQ_DIR"
    mv *_R[12].fastq "$RNASEQ_DIR" 2>/dev/null

    echo "[NOTE] Please verify your FASTQ files were correctly moved into '$RNASEQ_DIR'."
fi

# -----------------------------
# Step 4: Generate paired FASTQ list
# -----------------------------
echo "[INFO] Generating paired FASTQ list in $PAIRED_FILE"

cd "$RNASEQ_DIR" || exit 1

paste <(ls *_R1.fastq | sort) <(ls *_R2.fastq | sort) > "../$PAIRED_FILE"

cd - || exit 1

# -----------------------------
# Step 5: Run EviAnn
# -----------------------------
echo "[INFO] Running EviAnn..."
echo "[INFO] Genome: $GENOME_FASTA"
echo "[INFO] RNA list: $PAIRED_FILE"
echo "[INFO] Proteins: $PROTEIN_OUTPUT"

eviann.sh \
  -t "$THREADS" \
  -g "$GENOME_FASTA" \
  -r "$PAIRED_FILE" \
  -p "$PROTEIN_OUTPUT" \
  -m "$MIN_PROTEINS" \
  --lncrnamintpm "$LNCRNA_MIN_TPM"

if [ $? -eq 0 ]; then
    echo "[SUCCESS] EviAnn finished successfully."
else
    echo "[ERROR] EviAnn failed."
    exit 1
fi
