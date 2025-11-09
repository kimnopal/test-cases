package tracker

import (
	"context"
	"fmt"
	"sync"
	"time"

	"concurrent-data-processing/pkg/models"
)

type ProgressTracker struct {
	mu            sync.Mutex
	progress      models.ProgressReport
	updateTicker  *time.Ticker
	printFunc     func(models.ProgressReport)
	progressPrinted bool
}

type Config struct {
	TotalFiles     int
	UpdateInterval time.Duration
	PrintFunc      func(models.ProgressReport)
}

func DefaultPrintFunc(progress models.ProgressReport) {
	fmt.Printf("\r[Progress] Files: %d/%d | Records: %d | Errors: %d",
		progress.ProcessedFiles,
		progress.TotalFiles,
		progress.ProcessedRecords,
		progress.Errors,
	)
}

func New(config Config) *ProgressTracker {
	if config.UpdateInterval == 0 {
		config.UpdateInterval = 500 * time.Millisecond
	}
	if config.PrintFunc == nil {
		config.PrintFunc = DefaultPrintFunc
	}

	return &ProgressTracker{
		progress: models.ProgressReport{
			TotalFiles: config.TotalFiles,
		},
		updateTicker: time.NewTicker(config.UpdateInterval),
		printFunc:    config.PrintFunc,
	}
}

func (pt *ProgressTracker) Start(ctx context.Context, results <-chan models.Result, done chan<- struct{}) {
	defer pt.updateTicker.Stop()

	go func() {
		defer close(done)

		for {
			select {
			case <-ctx.Done():
				pt.printProgress()
				return

			case result, ok := <-results:
				if !ok {
					pt.printProgress()
					return
				}
				pt.updateProgress(result)

			case <-pt.updateTicker.C:
				pt.printProgress()
			}
		}
	}()
}

func (pt *ProgressTracker) updateProgress(result models.Result) {
	pt.mu.Lock()
	defer pt.mu.Unlock()

	pt.progress.ProcessedRecords++
	if !result.Success && result.Error != nil {
		pt.progress.Errors++
	}
}

func (pt *ProgressTracker) printProgress() {
	pt.mu.Lock()
	defer pt.mu.Unlock()

	pt.printFunc(pt.progress)
	pt.progressPrinted = true
}

func (pt *ProgressTracker) GetProgress() models.ProgressReport {
	pt.mu.Lock()
	defer pt.mu.Unlock()
	return pt.progress
}

func (pt *ProgressTracker) PrintNewline() {
	pt.mu.Lock()
	defer pt.mu.Unlock()
	
	if pt.progressPrinted {
		fmt.Println()
	}
}

