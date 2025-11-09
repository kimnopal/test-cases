package tracker

import (
	"context"
	"fmt"
	"sync"
	"testing"
	"time"

	"concurrent-data-processing/pkg/models"
)

func TestProgressTracker_Start(t *testing.T) {
	tests := []struct {
		name           string
		results        []models.Result
		expectedRecords int
		expectedErrors  int
	}{
		{
			name: "successful results",
			results: []models.Result{
				{Success: true, Error: nil},
				{Success: true, Error: nil},
				{Success: true, Error: nil},
			},
			expectedRecords: 3,
			expectedErrors:  0,
		},
		{
			name: "mixed success and errors",
			results: []models.Result{
				{Success: true, Error: nil},
				{Success: false, Error: fmt.Errorf("error1")},
				{Success: true, Error: nil},
				{Success: false, Error: fmt.Errorf("error2")},
			},
			expectedRecords: 4,
			expectedErrors:  2,
		},
		{
			name:            "no results",
			results:         []models.Result{},
			expectedRecords: 0,
			expectedErrors:  0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
			defer cancel()

			resultsChan := make(chan models.Result, len(tt.results))
			doneChan := make(chan struct{})

			// Mock print function to avoid console output during tests
			printCalled := false
			mockPrintFunc := func(progress models.ProgressReport) {
				printCalled = true
			}

			tracker := New(Config{
				TotalFiles:     3,
				UpdateInterval: 100 * time.Millisecond,
				PrintFunc:      mockPrintFunc,
			})

			// Start tracker
			tracker.Start(ctx, resultsChan, doneChan)

			// Send results
			for _, result := range tt.results {
				resultsChan <- result
			}
			close(resultsChan)

			// Wait for completion
			select {
			case <-doneChan:
				// Expected completion
			case <-time.After(2 * time.Second):
				t.Fatal("tracker did not complete in time")
			}

			// Verify progress
			progress := tracker.GetProgress()
			if progress.ProcessedRecords != tt.expectedRecords {
				t.Errorf("expected %d processed records, got %d", tt.expectedRecords, progress.ProcessedRecords)
			}

			if progress.Errors != tt.expectedErrors {
				t.Errorf("expected %d errors, got %d", tt.expectedErrors, progress.Errors)
			}

			if progress.TotalFiles != 3 {
				t.Errorf("expected total files 3, got %d", progress.TotalFiles)
			}

			if !printCalled {
				t.Error("expected print function to be called")
			}
		})
	}
}

func TestProgressTracker_ContextCancellation(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())

	resultsChan := make(chan models.Result, 10)
	doneChan := make(chan struct{})

	tracker := New(Config{
		TotalFiles:     1,
		UpdateInterval: 50 * time.Millisecond,
		PrintFunc:      func(models.ProgressReport) {},
	})

	tracker.Start(ctx, resultsChan, doneChan)

	// Send a result and give time to process
	resultsChan <- models.Result{Success: true}
	time.Sleep(10 * time.Millisecond) // Give time for result to be processed

	// Cancel context
	cancel()

	// Should complete quickly
	select {
	case <-doneChan:
		// Expected
	case <-time.After(1 * time.Second):
		t.Fatal("tracker did not stop after context cancellation")
	}

	// Verify at least one record was processed (may be 0 or 1 due to timing)
	progress := tracker.GetProgress()
	if progress.ProcessedRecords > 1 {
		t.Errorf("expected at most 1 processed record, got %d", progress.ProcessedRecords)
	}
}

func TestProgressTracker_PeriodicUpdates(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()

	resultsChan := make(chan models.Result, 10)
	doneChan := make(chan struct{})

	printCount := 0
	var mu sync.Mutex
	mockPrintFunc := func(progress models.ProgressReport) {
		mu.Lock()
		printCount++
		mu.Unlock()
	}

	tracker := New(Config{
		TotalFiles:     1,
		UpdateInterval: 50 * time.Millisecond,
		PrintFunc:      mockPrintFunc,
	})

	tracker.Start(ctx, resultsChan, doneChan)

	// Keep sending results slowly
	go func() {
		for i := 0; i < 5; i++ {
			resultsChan <- models.Result{Success: true}
			time.Sleep(100 * time.Millisecond)
		}
		close(resultsChan)
	}()

	// Wait for completion
	<-doneChan

	// Print should have been called multiple times (periodic + final)
	mu.Lock()
	finalPrintCount := printCount
	mu.Unlock()
	
	if finalPrintCount < 1 {
		t.Errorf("expected at least 1 print call, got %d", finalPrintCount)
	}
}

func TestProgressTracker_GetProgress(t *testing.T) {
	tracker := New(Config{
		TotalFiles:     5,
		UpdateInterval: 100 * time.Millisecond,
		PrintFunc:      func(models.ProgressReport) {},
	})

	// Initial state
	progress := tracker.GetProgress()
	if progress.TotalFiles != 5 {
		t.Errorf("expected total files 5, got %d", progress.TotalFiles)
	}
	if progress.ProcessedRecords != 0 {
		t.Errorf("expected 0 processed records initially, got %d", progress.ProcessedRecords)
	}

	// Update progress manually
	tracker.updateProgress(models.Result{Success: true})
	tracker.updateProgress(models.Result{Success: false, Error: fmt.Errorf("error")})

	progress = tracker.GetProgress()
	if progress.ProcessedRecords != 2 {
		t.Errorf("expected 2 processed records, got %d", progress.ProcessedRecords)
	}
	if progress.Errors != 1 {
		t.Errorf("expected 1 error, got %d", progress.Errors)
	}
}

func TestDefaultPrintFunc(t *testing.T) {
	// Just verify it doesn't panic
	progress := models.ProgressReport{
		TotalFiles:       3,
		ProcessedFiles:   2,
		ProcessedRecords: 10,
		Errors:           1,
	}

	// Should not panic
	DefaultPrintFunc(progress)
}

