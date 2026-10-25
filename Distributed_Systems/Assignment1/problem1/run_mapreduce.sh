#!/bin/bash
#SBATCH --job-name=idf_job
#SBATCH --output=job_output.log
#SBATCH --error=job_error.log
#SBATCH --nodes=2
#SBATCH --ntasks=4
#SBATCH --time=00:10:00

# 1. Validation: Check if correct arguments are provided
if [ "$#" -ne 2 ]; then
    echo "Usage: bash run_mapreduce.sh <input_file> <output_dir>"
    exit 1
fi

INPUT=$1
OUTPUT_DIR=$2        
SPLITS=$SLURM_NTASKS

# 2. Setup: Create output directory
mkdir -p "$OUTPUT_DIR"

#################################
# Clean old files inside the output directory
#################################
# We clean only the specific patterns to avoid deleting other user data
rm -f "$OUTPUT_DIR"/chunk_* "$OUTPUT_DIR"/*.map "$OUTPUT_DIR"/*.count "$OUTPUT_DIR"/total_count.txt "$OUTPUT_DIR"/file_list.txt

#################################
# Step 1: Split input DIRECTLY into Output Directory
#################################
echo "Splitting input into $SPLITS parts..."
# This writes files like output_dir/chunk_aa, output_dir/chunk_ab, etc.
split -n l/$SPLITS "$INPUT" "$OUTPUT_DIR/chunk_"

#################################
# Prepare file list
#################################
# List the full paths (e.g., "output_dir/chunk_aa")
ls "$OUTPUT_DIR"/chunk_* > "$OUTPUT_DIR/file_list.txt"

#################################
# Step 2: Count documents (N)
#################################
echo "Running mapper_count..."

srun -N $SLURM_NNODES -n $SLURM_NTASKS bash -c '
    # Read the full path from the file list inside output dir
    file=$(sed -n "$((SLURM_PROCID+1))p" "'$OUTPUT_DIR'/file_list.txt")
    
    if [ -n "$file" ]; then
        # Input: output_dir/chunk_aa
        # Output: output_dir/chunk_aa.count (Automatic because $file contains the path)
        cat "$file" | python3 mapper_count.py > "${file}.count"
    fi
'

# Aggregate N locally using files from output dir
cat "$OUTPUT_DIR"/chunk_*.count | sort | python3 reducer_count.py > "$OUTPUT_DIR"/total_count.txt
N=$(awk '{sum+=$2} END {print sum}' "$OUTPUT_DIR"/total_count.txt)
echo "Total documents = $N"

#################################
# Step 3: Main Mapper (TF)
#################################
echo "Running mapper..."

srun -N $SLURM_NNODES -n $SLURM_NTASKS bash -c '
    file=$(sed -n "$((SLURM_PROCID+1))p" "'$OUTPUT_DIR'/file_list.txt")
    
    if [ -n "$file" ]; then
        # Output: output_dir/chunk_aa.map
        cat "$file" | python3 mapper.py > "${file}.map"
    fi
'

#################################
# Step 4: Reducer (IDF)
#################################
echo "Reducing..."

# Read .map files from output directory and write final result there
cat "$OUTPUT_DIR"/chunk_*.map | sort | python3 reducer.py "$N" > "$OUTPUT_DIR/output_idf"

echo "Job completed. Output written to $OUTPUT_DIR/output_idf"

# Optional: Cleanup chunks and intermediate files (comment out if you want to keep them)
# rm -f "$OUTPUT_DIR"/chunk_* "$OUTPUT_DIR"/*.map "$OUTPUT_DIR"/*.count "$OUTPUT_DIR"/file_list.txt
