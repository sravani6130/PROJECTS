package main

// test/main.go – KNN distributed system test suite
// Run from the q1 directory with:
//
//	go run ./test/
//
// The script builds knn_server, starts 3 instances on free ports,
// connects via gRPC, runs all edge-case tests, and reports PASS/FAIL.

import (
	"context"
	"fmt"
	"math"
	"math/rand"
	"net"
	"os"
	"os/exec"
	"sort"
	"time"

	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
	pb "knn_system/knn"
)

// ─── Test harness ──────────────────────────────────────────────────────────

var (
	passed int
	failed int
)

func pass(name string) {
	passed++
	fmt.Printf("  [PASS] %s\n", name)
}

func fail(name, reason string) {
	failed++
	fmt.Printf("  [FAIL] %s – %s\n", name, reason)
}

func section(title string) {
	fmt.Printf("\n── %s ──\n", title)
}

// ─── gRPC helpers ─────────────────────────────────────────────────────────

func connectAll(addrs []string) ([]pb.KNNServiceClient, []*grpc.ClientConn, error) {
	var clients []pb.KNNServiceClient
	var conns []*grpc.ClientConn
	for _, addr := range addrs {
		conn, err := grpc.Dial(addr, grpc.WithTransportCredentials(insecure.NewCredentials()))
		if err != nil {
			return nil, nil, fmt.Errorf("connect %s: %v", addr, err)
		}
		conns = append(conns, conn)
		clients = append(clients, pb.NewKNNServiceClient(conn))
	}
	return clients, conns, nil
}

func closeAll(conns []*grpc.ClientConn) {
	for _, c := range conns {
		c.Close()
	}
}

// uploadPartitioned splits dataPoints across all servers (contiguous chunks,
// remainder spread over the first servers) – mirrors the client implementation.
func uploadPartitioned(clients []pb.KNNServiceClient, dataPoints []*pb.DataPoint) error {
	n := len(dataPoints)
	numServers := len(clients)
	base := n / numServers
	rem := n % numServers
	start := 0
	for i := 0; i < numServers; i++ {
		size := base
		if i < rem {
			size++
		}
		end := start + size
		if end > n {
			end = n
		}
		partition := dataPoints[start:end]
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		_, err := clients[i].UploadData(ctx, &pb.UploadRequest{DataPoints: partition})
		cancel()
		if err != nil {
			return fmt.Errorf("server %d upload: %v", i+1, err)
		}
		start = end
	}
	return nil
}

// queryAll queries every server and returns the globally sorted top-k neighbors.
func queryAll(clients []pb.KNNServiceClient, query *pb.DataPoint, k int) ([]*pb.Neighbor, error) {
	var all []*pb.Neighbor
	for i, c := range clients {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		resp, err := c.QueryKNN(ctx, &pb.KNNRequest{QueryPoint: query, K: int32(k)})
		cancel()
		if err != nil {
			return nil, fmt.Errorf("server %d query: %v", i+1, err)
		}
		all = append(all, resp.Neighbors...)
	}
	sort.Slice(all, func(i, j int) bool {
		return all[i].Distance < all[j].Distance
	})
	if k > len(all) {
		k = len(all)
	}
	return all[:k], nil
}

// euclidean is the reference distance for verification.
func euclidean(a, b []float64) float64 {
	if len(a) != len(b) {
		return math.MaxFloat64
	}
	sum := 0.0
	for i := range a {
		d := a[i] - b[i]
		sum += d * d
	}
	return math.Sqrt(sum)
}

func makePoint(features ...float64) *pb.DataPoint {
	return &pb.DataPoint{Features: features}
}

func floatEq(a, b, tol float64) bool {
	return math.Abs(a-b) <= tol
}

// ─── Server lifecycle ─────────────────────────────────────────────────────

func freePort() int {
	l, err := net.Listen("tcp", ":0")
	if err != nil {
		panic(fmt.Sprintf("freePort: %v", err))
	}
	port := l.Addr().(*net.TCPAddr).Port
	l.Close()
	return port
}

// startServers builds knn_server and starts n instances.
// Returns addresses and a stop function.
func startServers(n int) (addrs []string, stop func()) {
	fmt.Println("[Setup] Building knn_server …")
	out, err := exec.Command("go", "build", "-o", "/tmp/knn_server_test", "./knn_server.go").CombinedOutput()
	if err != nil {
		fmt.Printf("[Setup] Build failed: %v\n%s\n", err, out)
		os.Exit(1)
	}

	var procs []*exec.Cmd
	for i := 0; i < n; i++ {
		port := freePort()
		addr := fmt.Sprintf("localhost:%d", port)
		addrs = append(addrs, addr)
		cmd := exec.Command("/tmp/knn_server_test", fmt.Sprintf("%d", port))
		cmd.Stdout = nil
		cmd.Stderr = nil
		if err := cmd.Start(); err != nil {
			fmt.Printf("[Setup] Could not start server: %v\n", err)
			os.Exit(1)
		}
		procs = append(procs, cmd)
	}

	time.Sleep(300 * time.Millisecond) // give servers time to bind

	stop = func() {
		for _, p := range procs {
			_ = p.Process.Kill()
		}
		os.Remove("/tmp/knn_server_test")
	}
	return
}

// ─── Tests ────────────────────────────────────────────────────────────────

// T01 – Assignment example from the PDF (§1.5)
func t01AssignmentExample(clients []pb.KNNServiceClient) {
	section("T01  Assignment-example walkthrough (PDF §1.5)")
	points := []*pb.DataPoint{
		makePoint(1.0, 2.0),
		makePoint(3.0, 4.0),
		makePoint(5.0, 6.0),
		makePoint(7.0, 8.0),
		makePoint(2.0, 1.0),
		makePoint(4.0, 3.0),
	}
	if err := uploadPartitioned(clients, points); err != nil {
		fail("upload 6 points across 3 servers", err.Error())
		return
	}
	pass("upload 6 points across 3 servers")

	result, err := queryAll(clients, makePoint(2.0, 3.0), 3)
	if err != nil {
		fail("query k=3", err.Error())
		return
	}
	if len(result) != 3 {
		fail("result count", fmt.Sprintf("want 3, got %d", len(result)))
		return
	}
	pass("result count = 3")

	expected := []float64{math.Sqrt(2), math.Sqrt(2), 2.0}
	for i, nb := range result {
		if !floatEq(nb.Distance, expected[i], 0.01) {
			fail(fmt.Sprintf("neighbor[%d] distance", i),
				fmt.Sprintf("want %.4f got %.4f", expected[i], nb.Distance))
			return
		}
	}
	pass("distances match expected (√2, √2, 2.0)")
}

// T02 – Data replacement: re-upload overwrites all previously stored data
func t02DataReplacement(clients []pb.KNNServiceClient) {
	section("T02  Data replacement (re-upload replaces previous data)")
	// Upload set A: one far-away point
	if err := uploadPartitioned(clients, []*pb.DataPoint{makePoint(100.0, 100.0)}); err != nil {
		fail("upload set A", err.Error())
		return
	}
	// Upload set B: three nearby points
	setB := []*pb.DataPoint{makePoint(1.0, 1.0), makePoint(2.0, 2.0), makePoint(3.0, 3.0)}
	if err := uploadPartitioned(clients, setB); err != nil {
		fail("upload set B", err.Error())
		return
	}
	result, err := queryAll(clients, makePoint(1.5, 1.5), 3)
	if err != nil {
		fail("query after replacement", err.Error())
		return
	}
	for _, nb := range result {
		for _, f := range nb.Point.Features {
			if floatEq(f, 100.0, 0.01) {
				fail("old data still present", fmt.Sprintf("found point %v from set A", nb.Point.Features))
				return
			}
		}
	}
	pass("set A not accessible after replacement with set B")
	if len(result) == 3 {
		pass("set B: all 3 points accessible")
	} else {
		fail("set B size", fmt.Sprintf("want 3 results, got %d", len(result)))
	}
}

// T03 – k larger than total number of data points
func t03KLargerThanData(clients []pb.KNNServiceClient) {
	section("T03  k > total points (should return all available, no error)")
	if err := uploadPartitioned(clients, []*pb.DataPoint{
		makePoint(1.0, 1.0), makePoint(2.0, 2.0), makePoint(3.0, 3.0),
	}); err != nil {
		fail("upload 3 points", err.Error())
		return
	}
	result, err := queryAll(clients, makePoint(0.0, 0.0), 100)
	if err != nil {
		fail("query k=100 with 3 points", err.Error())
		return
	}
	if len(result) == 3 {
		pass("returned all 3 points when k=100 (capped at total)")
	} else {
		fail("result count", fmt.Sprintf("want 3, got %d", len(result)))
	}
}

// T04 – k=1 returns the single nearest point
func t04KEquals1(clients []pb.KNNServiceClient) {
	section("T04  k=1 returns exactly the nearest point")
	if err := uploadPartitioned(clients, []*pb.DataPoint{
		makePoint(10.0, 10.0), makePoint(1.0, 1.0), makePoint(5.0, 5.0),
	}); err != nil {
		fail("upload", err.Error())
		return
	}
	result, err := queryAll(clients, makePoint(0.0, 0.0), 1)
	if err != nil {
		fail("query k=1", err.Error())
		return
	}
	if len(result) != 1 {
		fail("result count", fmt.Sprintf("want 1, got %d", len(result)))
		return
	}
	f := result[0].Point.Features
	if floatEq(f[0], 1.0, 0.001) && floatEq(f[1], 1.0, 0.001) {
		pass("nearest point is (1,1) – correct")
	} else {
		fail("nearest point", fmt.Sprintf("want [1 1], got %v", f))
	}
}

// T05 – Query point coincides with a data point → distance = 0
func t05ZeroDistance(clients []pb.KNNServiceClient) {
	section("T05  Query point coincides with data point (distance = 0)")
	if err := uploadPartitioned(clients, []*pb.DataPoint{
		makePoint(3.0, 7.0), makePoint(1.0, 1.0),
	}); err != nil {
		fail("upload", err.Error())
		return
	}
	result, err := queryAll(clients, makePoint(3.0, 7.0), 1)
	if err != nil {
		fail("query", err.Error())
		return
	}
	if len(result) == 0 {
		fail("empty result", "expected at least 1")
		return
	}
	if floatEq(result[0].Distance, 0.0, 1e-9) {
		pass("coincident point: distance = 0")
	} else {
		fail("distance", fmt.Sprintf("want 0, got %.10f", result[0].Distance))
	}
}

// T06 – Negative coordinates
func t06NegativeCoordinates(clients []pb.KNNServiceClient) {
	section("T06  Negative coordinates")
	if err := uploadPartitioned(clients, []*pb.DataPoint{
		makePoint(-1.0, -2.0), makePoint(-5.0, -5.0), makePoint(3.0, 4.0),
	}); err != nil {
		fail("upload", err.Error())
		return
	}
	result, err := queryAll(clients, makePoint(-1.5, -2.5), 1)
	if err != nil {
		fail("query", err.Error())
		return
	}
	if len(result) == 0 {
		fail("empty result", "expected 1 neighbor")
		return
	}
	f := result[0].Point.Features
	if floatEq(f[0], -1.0, 0.001) && floatEq(f[1], -2.0, 0.001) {
		pass("correct nearest with negative coordinates")
	} else {
		fail("nearest point", fmt.Sprintf("want [-1 -2], got %v", f))
	}
}

// T07 – All-zero coordinates and zero query
func t07ZeroCoordinates(clients []pb.KNNServiceClient) {
	section("T07  All-zero coordinates and zero query point")
	if err := uploadPartitioned(clients, []*pb.DataPoint{
		makePoint(0.0, 0.0, 0.0), makePoint(0.0, 0.0, 1.0), makePoint(0.0, 1.0, 0.0),
	}); err != nil {
		fail("upload", err.Error())
		return
	}
	result, err := queryAll(clients, makePoint(0.0, 0.0, 0.0), 3)
	if err != nil {
		fail("query from origin", err.Error())
		return
	}
	if len(result) == 3 {
		pass("3 neighbors returned from 3D all-zero dataset")
	} else {
		fail("result count", fmt.Sprintf("want 3, got %d", len(result)))
	}
	for i := 1; i < len(result); i++ {
		if result[i].Distance < result[i-1].Distance-1e-9 {
			fail("sort order", "results not sorted by distance")
			return
		}
	}
	pass("results sorted by distance")
}

// T08 – Very large floating-point values
func t08LargeFloats(clients []pb.KNNServiceClient) {
	section("T08  Very large floating-point values (1e10 range)")
	if err := uploadPartitioned(clients, []*pb.DataPoint{
		makePoint(1e10, 2e10), makePoint(3e10, 4e10), makePoint(5e10, 6e10),
	}); err != nil {
		fail("upload large floats", err.Error())
		return
	}
	result, err := queryAll(clients, makePoint(1.1e10, 2.1e10), 1)
	if err != nil {
		fail("query large floats", err.Error())
		return
	}
	if len(result) < 1 {
		fail("empty result", "expected 1")
		return
	}
	f := result[0].Point.Features
	if floatEq(f[0], 1e10, 1) && floatEq(f[1], 2e10, 1) {
		pass("correct nearest with large float values (1e10 scale)")
	} else {
		fail("nearest point", fmt.Sprintf("want [1e10, 2e10], got %v", f))
	}
}

// T09 – Very small (near-zero) floating-point values
func t09SmallFloats(clients []pb.KNNServiceClient) {
	section("T09  Near-zero small floating-point values (1e-10 range)")
	if err := uploadPartitioned(clients, []*pb.DataPoint{
		makePoint(1e-10, 2e-10), makePoint(3e-10, 4e-10), makePoint(5e-10, 6e-10),
	}); err != nil {
		fail("upload small floats", err.Error())
		return
	}
	result, err := queryAll(clients, makePoint(1.1e-10, 2.1e-10), 1)
	if err != nil {
		fail("query small floats", err.Error())
		return
	}
	if len(result) < 1 {
		fail("empty result", "expected 1")
		return
	}
	f := result[0].Point.Features
	if floatEq(f[0], 1e-10, 1e-13) && floatEq(f[1], 2e-10, 1e-13) {
		pass("correct nearest with near-zero float values (1e-10 scale)")
	} else {
		fail("nearest point", fmt.Sprintf("want [1e-10, 2e-10], got %v", f))
	}
}

// T10 – High-dimensional data (50 dimensions)
func t10HighDimensions(clients []pb.KNNServiceClient) {
	section("T10  High-dimensional data (50 dimensions)")
	dim := 50
	var points []*pb.DataPoint
	for i := 1; i <= 10; i++ {
		feats := make([]float64, dim)
		for d := 0; d < dim; d++ {
			feats[d] = float64(i)
		}
		points = append(points, &pb.DataPoint{Features: feats})
	}
	if err := uploadPartitioned(clients, points); err != nil {
		fail("upload 50D data", err.Error())
		return
	}
	origin := &pb.DataPoint{Features: make([]float64, dim)}
	result, err := queryAll(clients, origin, 3)
	if err != nil {
		fail("query 50D", err.Error())
		return
	}
	if len(result) != 3 {
		fail("result count", fmt.Sprintf("want 3, got %d", len(result)))
		return
	}
	// Point with all 1s is closest to the all-zeros origin
	expectedDist := math.Sqrt(float64(dim) * 1.0)
	if floatEq(result[0].Distance, expectedDist, 0.01) {
		pass(fmt.Sprintf("50D: nearest point correct (dist ≈ %.2f)", expectedDist))
	} else {
		fail("50D distance", fmt.Sprintf("want %.4f got %.4f", expectedDist, result[0].Distance))
	}
	if result[0].Distance <= result[1].Distance && result[1].Distance <= result[2].Distance {
		pass("50D results sorted correctly")
	} else {
		fail("50D sort order", "not sorted")
	}
}

// T11 – Very high-dimensional data (500 dimensions)
func t11VeryHighDimensions(clients []pb.KNNServiceClient) {
	section("T11  Very high-dimensional data (500 dimensions)")
	dim := 500
	points := make([]*pb.DataPoint, 5)
	for i := range points {
		feats := make([]float64, dim)
		for d := 0; d < dim; d++ {
			feats[d] = rand.Float64() * float64(i+1)
		}
		points[i] = &pb.DataPoint{Features: feats}
	}
	if err := uploadPartitioned(clients, points); err != nil {
		fail("upload 500D data", err.Error())
		return
	}
	result, err := queryAll(clients, &pb.DataPoint{Features: make([]float64, dim)}, 2)
	if err != nil {
		fail("query 500D", err.Error())
		return
	}
	if len(result) == 2 {
		pass("500D query returned 2 results successfully")
	} else {
		fail("500D result count", fmt.Sprintf("want 2, got %d", len(result)))
	}
}

// T12 – Large dataset (1000 points, 2D) with brute-force verification
func t12LargeDataset(clients []pb.KNNServiceClient) {
	section("T12  Large dataset (1000 points, 2D) with brute-force verification")
	var points []*pb.DataPoint
	for i := 0; i < 1000; i++ {
		points = append(points, makePoint(rand.Float64()*100, rand.Float64()*100))
	}
	if err := uploadPartitioned(clients, points); err != nil {
		fail("upload 1000 points", err.Error())
		return
	}
	pass("uploaded 1000 2D points")

	q := []float64{50.0, 50.0}
	result, err := queryAll(clients, &pb.DataPoint{Features: q}, 10)
	if err != nil {
		fail("query k=10 over 1000 points", err.Error())
		return
	}
	if len(result) != 10 {
		fail("result count", fmt.Sprintf("want 10, got %d", len(result)))
		return
	}
	pass("returned 10 nearest neighbors from 1000-point dataset")

	// Verify sorted order
	for i := 1; i < len(result); i++ {
		if result[i].Distance < result[i-1].Distance-1e-9 {
			fail("sort order", "results not sorted by distance")
			return
		}
	}
	pass("results sorted by distance")

	// Brute-force top-10 comparison
	type pair struct{ dist float64 }
	var bf []pair
	for _, p := range points {
		bf = append(bf, pair{euclidean(q, p.Features)})
	}
	sort.Slice(bf, func(a, b int) bool { return bf[a].dist < bf[b].dist })
	for i := 0; i < 10; i++ {
		if !floatEq(result[i].Distance, bf[i].dist, 1e-6) {
			fail("brute-force verification",
				fmt.Sprintf("rank %d: want dist %.6f got %.6f", i, bf[i].dist, result[i].Distance))
			return
		}
	}
	pass("top-10 distances match brute-force verification")
}

// T13 – Large high-dimensional dataset (200 × 20) with brute-force check
func t13LargeHighDim(clients []pb.KNNServiceClient) {
	section("T13  Large high-dimensional (200 points × 20 dimensions)")
	dim := 20
	var points []*pb.DataPoint
	for i := 0; i < 200; i++ {
		feats := make([]float64, dim)
		for d := 0; d < dim; d++ {
			feats[d] = rand.NormFloat64()
		}
		points = append(points, &pb.DataPoint{Features: feats})
	}
	if err := uploadPartitioned(clients, points); err != nil {
		fail("upload 200×20D", err.Error())
		return
	}
	q := make([]float64, dim)
	result, err := queryAll(clients, &pb.DataPoint{Features: q}, 5)
	if err != nil {
		fail("query 200×20D", err.Error())
		return
	}
	if len(result) != 5 {
		fail("result count", fmt.Sprintf("want 5, got %d", len(result)))
		return
	}

	type pair struct{ dist float64 }
	var bf []pair
	for _, p := range points {
		bf = append(bf, pair{euclidean(q, p.Features)})
	}
	sort.Slice(bf, func(a, b int) bool { return bf[a].dist < bf[b].dist })
	for i := 0; i < 5; i++ {
		if !floatEq(result[i].Distance, bf[i].dist, 1e-6) {
			fail("200×20D brute-force check",
				fmt.Sprintf("rank %d: want %.6f got %.6f", i, bf[i].dist, result[i].Distance))
			return
		}
	}
	pass("200×20D top-5 matches brute-force")
}

// T14 – Uneven partitioning: 7 points across 3 servers → 3/2/2
func t14UnevenPartitioning(clients []pb.KNNServiceClient) {
	section("T14  Uneven partitioning (7 points across 3 servers → 3/2/2)")
	points := []*pb.DataPoint{
		makePoint(1, 1), makePoint(2, 2), makePoint(3, 3),
		makePoint(4, 4), makePoint(5, 5),
		makePoint(6, 6), makePoint(7, 7),
	}
	if err := uploadPartitioned(clients, points); err != nil {
		fail("upload 7 points", err.Error())
		return
	}
	result, err := queryAll(clients, makePoint(4, 4), 7)
	if err != nil {
		fail("query k=7", err.Error())
		return
	}
	if len(result) == 7 {
		pass("all 7 points accessible across uneven 3/2/2 split")
	} else {
		fail("result count", fmt.Sprintf("want 7 (all points), got %d", len(result)))
	}
}

// T15 – Tie-breaking: multiple equidistant points
func t15TieBreaking(clients []pb.KNNServiceClient) {
	section("T15  Tie-breaking: multiple equidistant points")
	// Unit square corners – all equidistant from centre (0.5, 0.5) at √0.5
	if err := uploadPartitioned(clients, []*pb.DataPoint{
		makePoint(0.0, 0.0), makePoint(1.0, 0.0),
		makePoint(0.0, 1.0), makePoint(1.0, 1.0),
	}); err != nil {
		fail("upload unit square", err.Error())
		return
	}
	result, err := queryAll(clients, makePoint(0.5, 0.5), 2)
	if err != nil {
		fail("query k=2", err.Error())
		return
	}
	if len(result) != 2 {
		fail("result count", fmt.Sprintf("want 2, got %d", len(result)))
		return
	}
	dist := math.Sqrt(0.5)
	if floatEq(result[0].Distance, dist, 0.001) && floatEq(result[1].Distance, dist, 0.001) {
		pass("tie-breaking: both returned points are equidistant (√0.5)")
	} else {
		fail("distances", fmt.Sprintf("want all ≈%.4f, got %.4f, %.4f",
			dist, result[0].Distance, result[1].Distance))
	}
}

// T16 – Single server operation (1 server only)
func t16SingleServer(clients []pb.KNNServiceClient) {
	section("T16  Single-server operation")
	single := clients[:1]
	if err := uploadPartitioned(single, []*pb.DataPoint{
		makePoint(1, 2), makePoint(3, 4), makePoint(5, 6),
	}); err != nil {
		fail("single server upload", err.Error())
		return
	}
	result, err := queryAll(single, makePoint(2, 3), 2)
	if err != nil {
		fail("single server query", err.Error())
		return
	}
	if len(result) == 2 {
		pass("single-server mode: 2 results returned")
	} else {
		fail("single server result count", fmt.Sprintf("want 2, got %d", len(result)))
	}
}

// T17 – k=0 returns empty result (no crash)
func t17KEqualsZero(clients []pb.KNNServiceClient) {
	section("T17  k=0 returns empty result without panic")
	if err := uploadPartitioned(clients, []*pb.DataPoint{
		makePoint(1, 2), makePoint(3, 4),
	}); err != nil {
		fail("upload", err.Error())
		return
	}
	result, err := queryAll(clients, makePoint(0, 0), 0)
	if err != nil {
		fail("query k=0", err.Error())
		return
	}
	if len(result) == 0 {
		pass("k=0 returns empty list (no panic)")
	} else {
		fail("result count", fmt.Sprintf("want 0, got %d", len(result)))
	}
}

// T18 – Empty servers: query returns no results, no crash
func t18EmptyServer(clients []pb.KNNServiceClient) {
	section("T18  Empty servers (no data uploaded) – no crash, empty result")
	for _, c := range clients {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		_, err := c.UploadData(ctx, &pb.UploadRequest{DataPoints: []*pb.DataPoint{}})
		cancel()
		if err != nil {
			fail("clear server", err.Error())
			return
		}
	}
	result, err := queryAll(clients, makePoint(1, 2), 5)
	if err != nil {
		fail("query empty servers", err.Error())
		return
	}
	if len(result) == 0 {
		pass("empty server returns 0 results (no panic)")
	} else {
		fail("result count", fmt.Sprintf("want 0, got %d", len(result)))
	}
}

// T19 – Distance consistency: server-computed vs local reference
func t19DistanceConsistency(clients []pb.KNNServiceClient) {
	section("T19  Distance consistency (server vs local Euclidean reference)")
	if err := uploadPartitioned(clients, []*pb.DataPoint{
		makePoint(1.5, 2.5, 3.5), makePoint(7.0, 8.0, 9.0), makePoint(-3.0, 0.0, 4.5),
	}); err != nil {
		fail("upload 3D points", err.Error())
		return
	}
	q := []float64{2.0, 3.0, 4.0}
	result, err := queryAll(clients, &pb.DataPoint{Features: q}, 3)
	if err != nil {
		fail("query 3D", err.Error())
		return
	}
	allOk := true
	for _, nb := range result {
		expected := euclidean(q, nb.Point.Features)
		if !floatEq(nb.Distance, expected, 1e-9) {
			fail("distance mismatch",
				fmt.Sprintf("point %v: server=%.10f local=%.10f", nb.Point.Features, nb.Distance, expected))
			allOk = false
		}
	}
	if allOk {
		pass("all server-computed distances match local Euclidean reference")
	}
}

// T20 – Sequential re-uploads: verify each upload replaces the last
func t20SequentialUploads(clients []pb.KNNServiceClient) {
	section("T20  Sequential uploads: each replaces previous (3 rounds)")
	for round := 1; round <= 3; round++ {
		base := float64(round * 10)
		pts := []*pb.DataPoint{makePoint(base, base), makePoint(base+1, base+1)}
		if err := uploadPartitioned(clients, pts); err != nil {
			fail(fmt.Sprintf("upload round %d", round), err.Error())
			return
		}
		result, err := queryAll(clients, makePoint(base, base), 1)
		if err != nil {
			fail(fmt.Sprintf("query round %d", round), err.Error())
			return
		}
		if len(result) < 1 {
			fail(fmt.Sprintf("round %d empty result", round), "expected 1")
			return
		}
		if floatEq(result[0].Distance, 0.0, 1e-9) {
			pass(fmt.Sprintf("round %d: exact point uploaded → distance=0", round))
		} else {
			fail(fmt.Sprintf("round %d distance", round),
				fmt.Sprintf("want 0, got %.6f", result[0].Distance))
		}
	}
}

// ─── Main ─────────────────────────────────────────────────────────────────

func main() {
	fmt.Println("═══════════════════════════════════════════════════════")
	fmt.Println("         KNN Distributed System – Test Suite           ")
	fmt.Println("         Run from q1/: go run ./test/                  ")
	fmt.Println("═══════════════════════════════════════════════════════")

	addrs, stop := startServers(3)
	defer stop()
	fmt.Printf("[Setup] Servers running on: %v\n", addrs)

	clients, conns, err := connectAll(addrs)
	if err != nil {
		fmt.Printf("[FATAL] Cannot connect to servers: %v\n", err)
		os.Exit(1)
	}
	defer closeAll(conns)

	t01AssignmentExample(clients)
	t02DataReplacement(clients)
	t03KLargerThanData(clients)
	t04KEquals1(clients)
	t05ZeroDistance(clients)
	t06NegativeCoordinates(clients)
	t07ZeroCoordinates(clients)
	t08LargeFloats(clients)
	t09SmallFloats(clients)
	t10HighDimensions(clients)
	t11VeryHighDimensions(clients)
	t12LargeDataset(clients)
	t13LargeHighDim(clients)
	t14UnevenPartitioning(clients)
	t15TieBreaking(clients)
	t16SingleServer(clients)
	t17KEqualsZero(clients)
	t18EmptyServer(clients)
	t19DistanceConsistency(clients)
	t20SequentialUploads(clients)

	total := passed + failed
	fmt.Printf("\n═══════════════════════════════════════════════════════\n")
	fmt.Printf("  Results: %d/%d passed\n", passed, total)
	if failed == 0 {
		fmt.Println("  ALL TESTS PASSED")
	} else {
		fmt.Printf("  FAILED: %d\n", failed)
	}
	fmt.Println("═══════════════════════════════════════════════════════")

	if failed > 0 {
		os.Exit(1)
	}
}
