# Concurrent Data Processing

A production-ready Go application demonstrating concurrent CSV data processing using goroutines, channels, and the worker pool pattern.

## Overview

This project showcases best practices for building concurrent data processing pipelines in Go. It reads multiple CSV files concurrently, processes records using a worker pool, and tracks progress in real-time with proper error handling and graceful shutdown capabilities.

## Features

- **Concurrent File Reading**: Multiple CSV files are read simultaneously using goroutines
- **Worker Pool Pattern**: Configurable number of workers process records concurrently
- **Real-time Progress Tracking**: Live progress updates during processing
- **Context-based Cancellation**: Proper handling of timeouts and cancellations
- **Error Handling**: Comprehensive error reporting without stopping the pipeline
- **Buffered Channels**: Optimized channel sizes for efficient data flow
- **Clean Architecture**: Well-organized package structure following Go best practices
- **Comprehensive Testing**: Unit tests for all components with race detection

## Project Structure

```
.
├── cmd/
│   └── processor/
│       └── main.go              # Application entry point
├── internal/
│   ├── processor/
│   │   ├── processor.go         # Main processing orchestrator
│   │   └── processor_test.go
│   ├── reader/
│   │   ├── reader.go            # Concurrent CSV file reader
│   │   └── reader_test.go
│   ├── tracker/
│   │   ├── tracker.go           # Progress tracking component
│   │   └── tracker_test.go
│   └── worker/
│       ├── worker.go            # Worker pool implementation
│       └── worker_test.go
├── pkg/
│   └── models/
│       └── models.go            # Shared data models
├── testdata/
│   ├── data1.csv                # Sample CSV files
│   ├── data2.csv
│   └── data3.csv
├── Makefile                     # Build and development tasks
└── go.mod                       # Go module definition
```

## Architecture

### Components

1. **FileReader** (`internal/reader`)

   - Reads multiple CSV files concurrently
   - Each file is processed by a separate goroutine
   - Sends records to a buffered channel for workers

2. **Worker Pool** (`internal/worker`)

   - Configurable number of worker goroutines
   - Processes records from the input channel
   - Implements the worker pool pattern for optimal resource utilization
   - Supports custom processor implementations via the `Processor` interface

3. **Progress Tracker** (`internal/tracker`)

   - Monitors processing progress in real-time
   - Thread-safe progress reporting using mutex
   - Displays statistics and success rates

4. **Processor** (`internal/processor`)
   - Orchestrates the entire pipeline
   - Manages lifecycle of readers, workers, and trackers
   - Handles context cancellation and timeouts

### Data Flow

```
CSV Files → FileReader → Records Channel → Worker Pool → Results Channel → Progress Tracker
                ↓                                ↓
            Error Channel ←──────────────────────┘
```

## Prerequisites

- Go 1.21 or higher
- Make (optional, for using Makefile commands)

## Installation

1. Clone the repository:

```bash
git clone <repository-url>
cd concurrent-data-processing
```

2. Download dependencies:

```bash
make deps
```

Or manually:

```bash
go mod download
```

## Usage

### Basic Usage

Run with default test data files:

```bash
make run
```

Or:

```bash
go run cmd/processor/main.go
```

### Advanced Usage

#### Custom Files

Process specific CSV files:

```bash
go run cmd/processor/main.go -files="file1.csv,file2.csv,file3.csv"
```

Or using Make:

```bash
make run-custom FILES="file1.csv,file2.csv"
```

#### Configure Workers

Adjust the number of concurrent workers:

```bash
go run cmd/processor/main.go -workers=10
```

#### Set Timeout

Specify processing timeout:

```bash
go run cmd/processor/main.go -timeout=1m
```

#### Adjust Processing Time

Simulate longer processing per record (for testing):

```bash
go run cmd/processor/main.go -processing-time=100ms
```

#### All Options Combined

```bash
go run cmd/processor/main.go \
  -files="data1.csv,data2.csv" \
  -workers=10 \
  -timeout=30s \
  -processing-time=50ms
```

## Development

### Build

Build the binary:

```bash
make build
```

The binary will be created at `bin/processor`.

### Testing

Run all tests:

```bash
make test
```

Run tests without race detector (faster):

```bash
make test-short
```

Generate coverage report:

```bash
make test-coverage
```

This creates an HTML coverage report at `coverage/coverage.html`.

### Code Quality

Format code:

```bash
make fmt
```

Run go vet:

```bash
make vet
```

Run linter (requires golangci-lint):

```bash
make lint
```

Install development tools:

```bash
make install-tools
```

Run all checks (format, vet, and test):

```bash
make verify
```

### Benchmarking

Run performance benchmarks:

```bash
make bench
```

### Clean

Remove build artifacts and test cache:

```bash
make clean
```

## Configuration

### Processor Configuration

The `processor.Config` struct allows fine-tuning of the pipeline:

```go
config := processor.Config{
    Files:           []string{"data1.csv", "data2.csv"},
    NumWorkers:      5,      // Number of worker goroutines
    RecordsBufSize:  100,    // Input channel buffer size
    ResultsBufSize:  100,    // Output channel buffer size
    ErrorsBufSize:   10,     // Error channel buffer size
    WorkerProcessor: worker.NewDefaultProcessor(10 * time.Millisecond),
}
```

### Custom Processor

Implement the `worker.Processor` interface for custom processing logic:

```go
type CustomProcessor struct {
    // Your fields
}

func (cp *CustomProcessor) Process(record models.Record) models.Result {
    // Your processing logic
    return models.Result{
        FileName:    record.FileName,
        RowNum:      record.RowNum,
        ProcessedAt: time.Now(),
        Success:     true,
    }
}
```

## Examples

### Example 1: Processing with High Concurrency

```bash
go run cmd/processor/main.go -workers=20 -timeout=2m
```

### Example 2: Quick Test with Simulated Delay

```bash
go run cmd/processor/main.go -workers=3 -processing-time=500ms
```

### Example 3: Production-like Setup

```bash
./bin/processor \
  -files="/data/input1.csv,/data/input2.csv,/data/input3.csv" \
  -workers=50 \
  -timeout=5m
```

## Output

The application provides real-time feedback:

```
Starting concurrent data processing pipeline...
✅ Processing complete!

📊 Final Statistics:
   Total Files: 3
   Total Records: 15
   Errors: 0
   Success Rate: 100.00%

✅ All done!
```

## Testing

The project includes comprehensive unit tests for all components:

- **Processor Tests**: End-to-end pipeline testing
- **Reader Tests**: Concurrent file reading validation
- **Worker Tests**: Worker pool behavior verification
- **Tracker Tests**: Progress tracking accuracy

All tests use race detection to ensure thread safety.

## Performance Considerations

1. **Worker Count**: Adjust based on CPU cores and I/O characteristics

   - CPU-bound: NumWorkers ≈ CPU cores
   - I/O-bound: NumWorkers > CPU cores

2. **Buffer Sizes**: Balance memory usage vs. throughput

   - Larger buffers = better throughput but more memory
   - Smaller buffers = less memory but potential blocking

3. **File Count**: The reader spawns one goroutine per file
   - Suitable for moderate number of files (< 1000)
   - For many files, consider limiting concurrent readers

## Error Handling

- Non-fatal errors are logged but don't stop processing
- Fatal errors (context timeout, cancellation) stop all goroutines gracefully
- All goroutines properly clean up resources on shutdown

## Makefile Commands

| Command              | Description                       |
| -------------------- | --------------------------------- |
| `make help`          | Show all available commands       |
| `make build`         | Build the application             |
| `make run`           | Run with default settings         |
| `make run-custom`    | Run with custom files             |
| `make test`          | Run all tests with race detection |
| `make test-short`    | Run tests without race detection  |
| `make test-coverage` | Generate coverage report          |
| `make bench`         | Run benchmarks                    |
| `make fmt`           | Format code                       |
| `make vet`           | Run go vet                        |
| `make lint`          | Run golangci-lint                 |
| `make clean`         | Remove build artifacts            |
| `make verify`        | Run fmt, vet, and test            |
| `make ci`            | CI pipeline (deps + verify)       |

## Learn More

This project demonstrates several Go concurrency patterns:

- **Fan-Out**: Multiple file readers producing to a single channel
- **Worker Pool**: Fixed number of workers consuming from a channel
- **Fan-In**: Multiple workers producing to a results channel
- **Pipeline**: Multi-stage processing with channels connecting stages
- **Context Propagation**: Cancellation signals across goroutines

For more information on Go concurrency patterns, see:

- [Go Concurrency Patterns](https://go.dev/blog/pipelines)
- [Effective Go](https://go.dev/doc/effective_go)
