#!/bin/bash
#SBATCH --nodes=2
#SBATCH --ntasks=4
#SBATCH --time=00:10:00

# Function to profile a specific input size
run_profile() {
    INPUT=$1
    echo "--- PROFILING $INPUT ---"
    
    start_init=$(date +%s.%N)
    # Task Initialization (Split input)
    rm -f chunk_* *.map output_idf.txt
    split -n l/$SLURM_NTASKS $INPUT chunk_
    ls chunk_* > file_list.txt
    end_init=$(date +%s.%N)

    # Mapper
    start_map=$(date +%s.%N)
    srun -N $SLURM_NNODES -n $SLURM_NTASKS bash -c '
    file=$(sed -n "$((SLURM_PROCID+1))p" file_list.txt)
    # Dummy Mapper Logic for timing (Word Count style)
    cat $file | awk "{print \$1 \"\t1\"}" > ${file}.map
    '
    end_map=$(date +%s.%N)

    # Shuffle/Sort
    start_shuffle=$(date +%s.%N)
    cat chunk_*.map | sort > sorted.map
    end_shuffle=$(date +%s.%N)

    # Reducer
    start_reduce=$(date +%s.%N)
    cat sorted.map | uniq -c > output.txt
    end_reduce=$(date +%s.%N)

    # Calc Times
    echo "Init:    $(echo "$end_init - $start_init" | bc)"
    echo "Map:     $(echo "$end_map - $start_map" | bc)"
    echo "Shuffle: $(echo "$end_shuffle - $start_shuffle" | bc)"
    echo "Reduce:  $(echo "$end_reduce - $start_reduce" | bc)"
}

run_profile data_1MB.txt
run_profile data_10MB.txt
run_profile data_100MB.txt
