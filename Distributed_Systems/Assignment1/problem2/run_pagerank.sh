#!/bin/bash
#SBATCH --job-name=pagerank
#SBATCH --output=pagerank_output.log
#SBATCH --error=pagerank_error.log
#SBATCH --nodes=2
#SBATCH --ntasks=4
#SBATCH --time=00:10:00

# 1. Validation: Arguments 
if [ "$#" -ne 2 ]; then
    echo "Usage: bash run_pagerank.sh <input_file> <output_dir>"
    exit 1
fi

INPUT_FILE=$1
OUTPUT_DIR=$2
ITERATIONS=10
TASKS=$SLURM_NTASKS

# 2. Setup Output Directory
mkdir -p "$OUTPUT_DIR"

# Clean up old run artifacts inside output dir
rm -f "$OUTPUT_DIR"/iter_* "$OUTPUT_DIR"/chunk_* "$OUTPUT_DIR"/*.map

echo "=========================================="
echo "Starting PageRank on $INPUT_FILE"
echo "Output Directory: $OUTPUT_DIR"
echo "=========================================="

#################################
# Step 0: Initialize & Count N
#################################
echo "Counting nodes and Initializing..."

# Count N (Total lines in input = Total nodes)
N=$(grep -c "." "$INPUT_FILE")
echo "Total nodes N = $N"

# Initialize Iteration 0
# Input Format: Node \t Neighbors
# Output Format: Node \t Neighbors \t Initial_PR (1/N)
awk -v n="$N" -F'\t' '{
    # Handle standard case (Node \t Neighbors)
    if(NF==2) {
        printf "%s\t%s\t%.6f\n", $1, $2, 1/n;
    } 
    # Handle dangling case (Node \t)
    else if(NF==1) {
        printf "%s\t\t%.6f\n", $1, 1/n;
    }
}' "$INPUT_FILE" > "$OUTPUT_DIR/iter_0.txt"


#################################
# Iterative MapReduce Loop
#################################
for ((i=1; i<=ITERATIONS; i++))
do
    PREV_ITER=$((i-1))
    CURRENT_INPUT="$OUTPUT_DIR/iter_${PREV_ITER}.txt"
    CURRENT_OUTPUT="$OUTPUT_DIR/iter_${i}.txt"
    
    echo "--- Iteration $i ---"

    # 1. Split Input for Distributed Processing
    # We split into the output directory to keep things clean
    split -n l/$TASKS "$CURRENT_INPUT" "$OUTPUT_DIR/chunk_iter${i}_"
    
    # Generate file list for srun (Fixes the array bug)
    ls "$OUTPUT_DIR"/chunk_iter${i}_* > "$OUTPUT_DIR/file_list.txt"

    # 2. Distributed Map Phase
    srun -N $SLURM_NNODES -n $TASKS bash -c '
        # Robustly pick file from list
        file=$(sed -n "$((SLURM_PROCID+1))p" "'$OUTPUT_DIR'/file_list.txt")
        
        if [ -n "$file" ]; then
            python3 mapper.py < "$file" > "${file}.map"
        fi
    '

    # 3. Reduce Phase
    # Aggregate maps -> Sort -> Reduce
    cat "$OUTPUT_DIR"/chunk_iter${i}_*.map | sort | python3 reducer.py "$N" > "$CURRENT_OUTPUT"

    # 4. Cleanup Intermediate Chunks
    rm -f "$OUTPUT_DIR"/chunk_iter${i}_* "$OUTPUT_DIR"/*.map "$OUTPUT_DIR"/file_list.txt

    # Optional: Print progress
    echo "Iteration $i completed."
done

#################################
# Final Formatting 
#################################
echo "Formatting Final Output..."

FINAL_FILE="$OUTPUT_DIR/final_pageranks"

# The Assignment requires: node_id <TAB> pagerank_value
# Our output is: node_id <TAB> neighbors <TAB> pagerank_value
# We use 'cut' to keep columns 1 and 3, removing the neighbors.
cut -f1,3 "$OUTPUT_DIR/iter_${ITERATIONS}.txt" > "$FINAL_FILE"

echo "PageRank Completed Successfully."
echo "Final Result: $FINAL_FILE"
