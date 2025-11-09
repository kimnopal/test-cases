package processor

import (
	"context"
	"fmt"
	"os"

	"concurrent-data-processing/internal/reader"
	"concurrent-data-processing/internal/tracker"
	"concurrent-data-processing/internal/worker"
	"concurrent-data-processing/pkg/models"
)

type Processor struct {
	fileReader      *reader.FileReader
	workerPool      *worker.Pool
	progressTracker *tracker.ProgressTracker
	config          Config
}

type Config struct {
	Files           []string
	NumWorkers      int
	RecordsBufSize  int
	ResultsBufSize  int
	ErrorsBufSize   int
	WorkerProcessor worker.Processor
	TrackerConfig   tracker.Config
}

func DefaultConfig(files []string) Config {
	return Config{
		Files:          files,
		NumWorkers:     5,
		RecordsBufSize: 100,
		ResultsBufSize: 100,
		ErrorsBufSize:  10,
		TrackerConfig: tracker.Config{
			TotalFiles: len(files),
		},
	}
}

func New(config Config) *Processor {
	if config.NumWorkers == 0 {
		config.NumWorkers = 5
	}
	if config.RecordsBufSize == 0 {
		config.RecordsBufSize = 100
	}
	if config.ResultsBufSize == 0 {
		config.ResultsBufSize = 100
	}
	if config.ErrorsBufSize == 0 {
		config.ErrorsBufSize = 10
	}
	if config.WorkerProcessor == nil {
		config.WorkerProcessor = worker.NewDefaultProcessor(0)
	}

	config.TrackerConfig.TotalFiles = len(config.Files)

	return &Processor{
		fileReader:      reader.New(config.Files),
		workerPool:      worker.New(config.NumWorkers, config.WorkerProcessor),
		progressTracker: tracker.New(config.TrackerConfig),
		config:          config,
	}
}

func (p *Processor) Process(ctx context.Context) error {
	// Create channels
	recordsChan := make(chan models.Record, p.config.RecordsBufSize)
	resultsChan := make(chan models.Result, p.config.ResultsBufSize)
	errorsChan := make(chan error, p.config.ErrorsBufSize)
	doneChan := make(chan struct{})

	fmt.Println("Starting concurrent data processing pipeline...")

	go p.fileReader.ReadFiles(ctx, recordsChan, errorsChan)
	p.workerPool.Start(ctx, recordsChan, resultsChan)
	p.progressTracker.Start(ctx, resultsChan, doneChan)

	errDone := make(chan struct{})
	go func() {
		defer close(errDone)
		for err := range errorsChan {
			fmt.Fprintf(os.Stderr, "\n⚠️  Error: %v\n", err)
		}
	}()

	select {
	case <-ctx.Done():
		p.progressTracker.PrintNewline()
		return ctx.Err()
	case <-doneChan:
		p.progressTracker.PrintNewline()
		fmt.Println("✅ Processing complete!")
		
		p.printStatistics()
		return nil
	}
}

func (p *Processor) printStatistics() {
	progress := p.progressTracker.GetProgress()
	
	fmt.Printf("\n📊 Final Statistics:\n")
	fmt.Printf("   Total Files: %d\n", progress.TotalFiles)
	fmt.Printf("   Total Records: %d\n", progress.ProcessedRecords)
	fmt.Printf("   Errors: %d\n", progress.Errors)
	
	if progress.ProcessedRecords > 0 {
		successRate := float64(progress.ProcessedRecords-progress.Errors) / float64(progress.ProcessedRecords) * 100
		fmt.Printf("   Success Rate: %.2f%%\n", successRate)
	}
}

func (p *Processor) GetProgress() models.ProgressReport {
	return p.progressTracker.GetProgress()
}

