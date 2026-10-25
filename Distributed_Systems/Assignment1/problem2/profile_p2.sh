#!/bin/bash
#SBATCH --output=profile_p2.log
#SBATCH --nodes=2
#SBATCH --ntasks=4
#SBATCH --time=00:20:00

# Ensure scripts exist
if [ ! -f "mapper.py" ] || [ ! -f "reducer.py" ]; then
    echo "Error: mapper.py or reducer.py not found in current directory."
    exit 1
fi

run_profile() {
    NODES=$1
    INPUT="graph_${NODES}.txt"
    ITER_INPUT="iter_0_${NODES}.txt"
    
    echo "==========================================="
    echo "PROFILING GRAPH SIZE: $NODES Nodes"
    echo "==========================================="

    # 1. GENERATE DATA
    python3 gen_graph.py $NODES $INPUT

    # 2. INITIALIZATION (Add 1/N PR)
    start_init=$(date +%s.%N)
    
    # Calculate 1/N
    N=$(wc -l < $INPUT)
    awk -v n=$N 'BEGIN {FS="\t"; OFS="\t"} {print $1, $2, 1.0/n}' $INPUT > $ITER_INPUT
    
    # Split for Mapper
    rm -f chunk_*
    split -n l/$SLURM_NTASKS $ITER_INPUT chunk_
    ls chunk_* > file_list.txt
    
    end_init=$(date +%s.%N)
    time_init=$(echo "$end_init - $start_init" | bc)

    # 3. MAPPER
    start_map=$(date +%s.%N)
    srun -N $SLURM_NNODES -n $SLURM_NTASKS bash -c '
        file=$(sed -n "$((SLURM_PROCID+1))p" file_list.txt)
        python3 mapper.py < $file > ${file}.map
    '
    end_map=$(date +%s.%N)
    time_map=$(echo "$end_map - $start_map" | bc)

    # 4. SHUFFLE / SORT
    start_shuffle=$(date +%s.%N)
    cat chunk_*.map | sort > sorted.map
    end_shuffle=$(date +%s.%N)
    time_shuffle=$(echo "$end_shuffle - $start_shuffle" | bc)

    # 5. REDUCER
    start_reduce=$(date +%s.%N)
    python3 reducer.py $N < sorted.map > output_${NODES}.txt
    end_reduce=$(date +%s.%N)
    time_reduce=$(echo "$end_reduce - $start_reduce" | bc)
    
    # TOTAL
    time_total=$(echo "$time_init + $time_map + $time_shuffle + $time_reduce" | bc)

    echo "-------------------------------------------"
    echo "RESULTS ($NODES Nodes)"
    echo "-------------------------------------------"
    echo "Init Time:    $time_init s"
    echo "Map Time:     $time_map s"
    echo "Shuffle Time: $time_shuffle s"
    echo "Reduce Time:  $time_reduce s"
    echo "Total Iter 1: $time_total s"
    echo "-------------------------------------------"
    
    # Cleanup heavy files to save space
    rm $INPUT $ITER_INPUT chunk_* sorted.map output_${NODES}.txt
}

# Run for 3 sizes
# Small
run_profile 10000

# Medium
run_profile 100000

# Large (Adjust if it takes too long on your cluster)
run_profile 500000
