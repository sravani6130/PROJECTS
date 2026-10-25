#include <mpi.h>
#include <iostream>
#include <vector>
#include <algorithm>
#include <climits>

using namespace std;

struct Edge { int u, v, weight; };
struct Subset { int parent; int rank; };

int find(Subset subsets[], int i) {
    if (subsets[i].parent != i)
        subsets[i].parent = find(subsets, subsets[i].parent);
    return subsets[i].parent;
}

void Union(Subset subsets[], int x, int y) {
    int xroot = find(subsets, x);
    int yroot = find(subsets, y);
    if (subsets[xroot].rank < subsets[yroot].rank) subsets[xroot].parent = yroot;
    else if (subsets[xroot].rank > subsets[yroot].rank) subsets[yroot].parent = xroot;
    else { subsets[yroot].parent = xroot; subsets[xroot].rank++; }
}

int main(int argc, char** argv) {
    MPI_Init(&argc, &argv);
    int world_rank, world_size;
    MPI_Comm_rank(MPI_COMM_WORLD, &world_rank);
    MPI_Comm_size(MPI_COMM_WORLD, &world_size);

    // --- TIMERS ---
    double t_start = MPI_Wtime();
    double t_comm = 0.0; // Total time in MPI calls
    double t_comp = 0.0; // Total time in computation
    double t_temp_start; 

    // 1. INPUT READING (Excluded from main profiling usually, but we track it)
    int n = 0, m = 0;
    vector<int> all_edges_flat;

    if (world_rank == 0) {
        if (argc < 2) { cerr << "Usage: " << argv[0] << " <input>" << endl; MPI_Abort(MPI_COMM_WORLD, 1); }
        FILE* file = fopen(argv[1], "r");
        if (!file) { cerr << "Error opening file" << endl; MPI_Abort(MPI_COMM_WORLD, 1); }
        if (fscanf(file, "%d %d", &n, &m) != 2) { cerr << "Read Error" << endl; MPI_Abort(MPI_COMM_WORLD, 1); }
        all_edges_flat.resize(m * 3);
        for (int i = 0; i < m; i++) {
            fscanf(file, "%d %d %d", &all_edges_flat[3*i], &all_edges_flat[3*i+1], &all_edges_flat[3*i+2]);
        }
        fclose(file);
        while ((all_edges_flat.size() / 3) % world_size != 0) {
            all_edges_flat.push_back(-1); all_edges_flat.push_back(-1); all_edges_flat.push_back(INT_MAX);
        }
    }

    // BROADCAST N
    t_temp_start = MPI_Wtime();
    MPI_Bcast(&n, 1, MPI_INT, 0, MPI_COMM_WORLD);
    t_comm += MPI_Wtime() - t_temp_start;

    // SCATTER
    int total_ints = (world_rank == 0) ? all_edges_flat.size() : 0;
    
    t_temp_start = MPI_Wtime();
    MPI_Bcast(&total_ints, 1, MPI_INT, 0, MPI_COMM_WORLD);
    t_comm += MPI_Wtime() - t_temp_start;

    int local_ints = total_ints / world_size;
    vector<int> local_data(local_ints);

    t_temp_start = MPI_Wtime();
    MPI_Scatter(all_edges_flat.data(), local_ints, MPI_INT, local_data.data(), local_ints, MPI_INT, 0, MPI_COMM_WORLD);
    t_comm += MPI_Wtime() - t_temp_start;

    // Local Struct Construction (Computation)
    t_temp_start = MPI_Wtime();
    vector<Edge> local_edges;
    local_edges.reserve(local_ints/3);
    for (size_t i = 0; i < local_data.size(); i += 3) {
        if (local_data[i+2] != INT_MAX) local_edges.push_back({local_data[i], local_data[i+1], local_data[i+2]});
    }
    t_comp += MPI_Wtime() - t_temp_start;

    // --- MAIN LOOP ---
    Subset* subsets = nullptr;
    if (world_rank == 0) {
        subsets = new Subset[n];
        for (int v = 0; v < n; ++v) { subsets[v].parent = v; subsets[v].rank = 0; }
    }
    vector<int> node_components(n);
    long long mst_weight = 0;
    int num_trees = n;

    while (true) {
        // RANK 0 COMPUTE (Update Components)
        t_temp_start = MPI_Wtime();
        if (world_rank == 0) {
            for (int i = 0; i < n; i++) node_components[i] = find(subsets, i);
        }
        t_comp += MPI_Wtime() - t_temp_start;

        // BCAST (Comm)
        t_temp_start = MPI_Wtime();
        MPI_Bcast(&num_trees, 1, MPI_INT, 0, MPI_COMM_WORLD);
        if (num_trees <= 1) { t_comm += MPI_Wtime() - t_temp_start; break; } // Exit
        MPI_Bcast(node_components.data(), n, MPI_INT, 0, MPI_COMM_WORLD);
        t_comm += MPI_Wtime() - t_temp_start;

        // WORKER COMPUTE (Find Local Cheapest)
        t_temp_start = MPI_Wtime();
        vector<int> local_cheapest(n * 3, -1);
        for (const auto& edge : local_edges) {
            int set1 = node_components[edge.u];
            int set2 = node_components[edge.v];
            if (set1 != set2) {
                if (local_cheapest[set1 * 3] == -1 || edge.weight < local_cheapest[set1 * 3]) {
                    local_cheapest[set1 * 3] = edge.weight;
                    local_cheapest[set1 * 3 + 1] = edge.u;
                    local_cheapest[set1 * 3 + 2] = edge.v;
                }
                if (local_cheapest[set2 * 3] == -1 || edge.weight < local_cheapest[set2 * 3]) {
                    local_cheapest[set2 * 3] = edge.weight;
                    local_cheapest[set2 * 3 + 1] = edge.u;
                    local_cheapest[set2 * 3 + 2] = edge.v;
                }
            }
        }
        t_comp += MPI_Wtime() - t_temp_start;

        // GATHER (Comm)
        t_temp_start = MPI_Wtime();
        vector<int> global_candidates;
        if (world_rank == 0) global_candidates.resize(n * 3 * world_size);
        MPI_Gather(local_cheapest.data(), n * 3, MPI_INT, global_candidates.data(), n * 3, MPI_INT, 0, MPI_COMM_WORLD);
        t_comm += MPI_Wtime() - t_temp_start;

        // RANK 0 MERGE (Compute)
        t_temp_start = MPI_Wtime();
        if (world_rank == 0) {
            vector<int> best_weight(n, INT_MAX);
            vector<int> best_u(n, -1), best_v(n, -1);

            for (int i = 0; i < n * world_size; i++) {
                int w = global_candidates[i * 3];
                if (w != -1 && w < best_weight[i % n]) {
                    best_weight[i % n] = w;
                    best_u[i % n] = global_candidates[i * 3 + 1];
                    best_v[i % n] = global_candidates[i * 3 + 2];
                }
            }
            bool merged = false;
            for (int i = 0; i < n; i++) {
                if (best_weight[i] != INT_MAX) {
                    int s1 = find(subsets, best_u[i]), s2 = find(subsets, best_v[i]);
                    if (s1 != s2) { mst_weight += best_weight[i]; Union(subsets, s1, s2); num_trees--; merged = true; }
                }
            }
            if (!merged && num_trees > 1) num_trees = 0;
        }
        t_comp += MPI_Wtime() - t_temp_start;
    }

    double t_total = MPI_Wtime() - t_start;

    // --- PROFILING REPORT ---
    // We aggregate stats to Rank 0 to print one clean report
    double max_t_comm, max_t_comp, max_t_total;
    MPI_Reduce(&t_comm, &max_t_comm, 1, MPI_DOUBLE, MPI_MAX, 0, MPI_COMM_WORLD);
    MPI_Reduce(&t_comp, &max_t_comp, 1, MPI_DOUBLE, MPI_MAX, 0, MPI_COMM_WORLD);
    MPI_Reduce(&t_total, &max_t_total, 1, MPI_DOUBLE, MPI_MAX, 0, MPI_COMM_WORLD);

    if (world_rank == 0) {
        cout << "MST_Weight: " << mst_weight << endl;
        cout << "PROFILE_DATA: Procs=" << world_size 
             << " TotalTime=" << max_t_total 
             << " CommTime=" << max_t_comm 
             << " CompTime=" << max_t_comp << endl;
        delete[] subsets;
    }

    MPI_Finalize();
    return 0;
}
