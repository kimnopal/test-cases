package main

import (
	"context"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"concurrent-data-processing/internal/processor"
	"concurrent-data-processing/internal/worker"
)

func main() {
	// Parse command line flags
	var (
		files          string
		numWorkers     int
		timeout        time.Duration
		processingTime time.Duration
	)

	flag.StringVar(&files, "files", "", "Comma-separated list of CSV files to process")
	flag.IntVar(&numWorkers, "workers", 5, "Number of worker goroutines")
	flag.DurationVar(&timeout, "timeout", 30*time.Second, "Processing timeout")
	flag.DurationVar(&processingTime, "processing-time", 10*time.Millisecond, "Simulated processing time per record")
	flag.Parse()

	// Get files list
	var fileList []string
	if files != "" {
		// Use provided files
		fileList = strings.Split(files, ",")
		for i, f := range fileList {
			fileList[i] = strings.TrimSpace(f)
		}
	} else {
		// Use default files from testdata directory
		fileList = []string{
			"testdata/data1.csv",
			"testdata/data2.csv",
			"testdata/data3.csv",
		}
	}

	// Validate files exist
	for _, f := range fileList {
		if _, err := os.Stat(f); os.IsNotExist(err) {
			fmt.Fprintf(os.Stderr, "Warning: File does not exist: %s\n", f)
		}
	}

	// Create context with timeout
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()

	// Create processor configuration
	config := processor.Config{
		Files:           fileList,
		NumWorkers:      numWorkers,
		RecordsBufSize:  100,
		ResultsBufSize:  100,
		ErrorsBufSize:   10,
		WorkerProcessor: worker.NewDefaultProcessor(processingTime),
	}

	// Create and run processor
	proc := processor.New(config)

	if err := proc.Process(ctx); err != nil {
		fmt.Fprintf(os.Stderr, "\n❌ Processing failed: %v\n", err)
		os.Exit(1)
	}

	fmt.Println("\n✅ All done!")
}

func init() {
	// Change to project root if running from cmd/processor
	if strings.HasSuffix(os.Args[0], filepath.Join("cmd", "processor", "processor")) {
		if err := os.Chdir("../.."); err != nil {
			fmt.Fprintf(os.Stderr, "Warning: failed to change to project root: %v\n", err)
		}
	}
}

