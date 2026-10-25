#!/bin/bash
# run_mpi.sh

# 1. Load environment
module purge
module load openmpi/4.1.5


INPUT_FILE=$1
NUM_PROCS=$2

mpirun -np $NUM_PROCS \
    --bind-to none \
    --mca pml ob1 \
    --mca btl tcp,self \
    --mca btl_tcp_if_include 172.16.0.0/24 \
    --mca coll ^hcoll \
    ./mpi_graph  $INPUT_FILE
