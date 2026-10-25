#!/bin/bash
#SBATCH --job-name=MPI_Distributed
#SBATCH --output=result_%j.out
#SBATCH --error=error_%j.err
#SBATCH --nodes=4                 
#SBATCH --ntasks=4                
#SBATCH --time=00:10:00

# Compile first
module load openmpi/4.1.5
mpic++ -O3 -o mpi_graph mpi_graph.cpp

INPUT=$1

# Run for 1, 2, 4, 8 processes
echo "--- RUNNING WITH 1 PROC ---"
mpirun -np 1 ./mpi_graph $INPUT
echo "--- RUNNING WITH 2 PROCS ---"
mpirun -np 2 ./mpi_graph $INPUT
echo "--- RUNNING WITH 4 PROCS ---"
mpirun -np 4 ./mpi_graph $INPUT
