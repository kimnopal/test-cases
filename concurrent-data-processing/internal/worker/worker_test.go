package worker

import (
	"context"
	"sync"
	"testing"
	"time"

	"concurrent-data-processing/pkg/models"
)

// MockProcessor for testing
type MockProcessor struct {
	processFunc func(models.Record) models.Result
	callCount   int
	mu          sync.Mutex
}

func (m *MockProcessor) Process(record models.Record) models.Result {
	m.mu.Lock()
	m.callCount++
	m.mu.Unlock()
	
	if m.processFunc != nil {
		return m.processFunc(record)
	}
	return models.Result{
		FileName:    record.FileName,
		RowNum:      record.RowNum,
		ProcessedAt: time.Now(),
		Success:     true,
	}
}

func TestPool_Start(t *testing.T) {
	tests := []struct {
		name           string
		numWorkers     int
		numRecords     int
		contextTimeout time.Duration
	}{
		{
			name:           "single worker processes all records",
			numWorkers:     1,
			numRecords:     5,
			contextTimeout: 5 * time.Second,
		},
		{
			name:           "multiple workers process records concurrently",
			numWorkers:     3,
			numRecords:     10,
			contextTimeout: 5 * time.Second,
		},
		{
			name:           "no records to process",
			numWorkers:     2,
			numRecords:     0,
			contextTimeout: 5 * time.Second,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			ctx, cancel := context.WithTimeout(context.Background(), tt.contextTimeout)
			defer cancel()

			// Create channels
			recordsChan := make(chan models.Record, tt.numRecords)
			resultsChan := make(chan models.Result, tt.numRecords)

			// Send test records
			for i := 0; i < tt.numRecords; i++ {
				recordsChan <- models.Record{
					FileName: "test.csv",
					RowNum:   i,
					Data:     []string{"data"},
				}
			}
			close(recordsChan)

			// Create mock processor
			mock := &MockProcessor{}
			pool := New(tt.numWorkers, mock)

			// Start workers
			pool.Start(ctx, recordsChan, resultsChan)

			// Collect results
			results := []models.Result{}
			for result := range resultsChan {
				results = append(results, result)
			}

			// Verify all records processed
			if len(results) != tt.numRecords {
				t.Errorf("expected %d results, got %d", tt.numRecords, len(results))
			}

			// Verify processor was called correct number of times
			mock.mu.Lock()
			actualCallCount := mock.callCount
			mock.mu.Unlock()
			
			if actualCallCount != tt.numRecords {
				t.Errorf("expected processor to be called %d times, got %d", tt.numRecords, actualCallCount)
			}
		})
	}
}

func TestPool_ContextCancellation(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())

	recordsChan := make(chan models.Record, 10)
	resultsChan := make(chan models.Result, 10)

	// Send some records
	for i := 0; i < 5; i++ {
		recordsChan <- models.Record{
			FileName: "test.csv",
			RowNum:   i,
			Data:     []string{"data"},
		}
	}

	mock := &MockProcessor{
		processFunc: func(record models.Record) models.Result {
			time.Sleep(100 * time.Millisecond) // Simulate slow processing
			return models.Result{Success: true}
		},
	}

	pool := New(2, mock)
	pool.Start(ctx, recordsChan, resultsChan)

	// Cancel context immediately
	cancel()

	// Wait a bit
	time.Sleep(200 * time.Millisecond)

	// Results channel should eventually close
	close(recordsChan)

	timeout := time.After(2 * time.Second)
	for {
		select {
		case _, ok := <-resultsChan:
			if !ok {
				// Channel closed as expected
				return
			}
		case <-timeout:
			t.Fatal("results channel did not close after context cancellation")
		}
	}
}

func TestDefaultProcessor_Process(t *testing.T) {
	tests := []struct {
		name           string
		record         models.Record
		expectedSuccess bool
		expectError     bool
	}{
		{
			name: "valid record",
			record: models.Record{
				FileName: "test.csv",
				RowNum:   1,
				Data:     []string{"value1", "value2"},
			},
			expectedSuccess: true,
			expectError:     false,
		},
		{
			name: "empty data",
			record: models.Record{
				FileName: "test.csv",
				RowNum:   1,
				Data:     []string{},
			},
			expectedSuccess: false,
			expectError:     true,
		},
		{
			name: "header row",
			record: models.Record{
				FileName: "test.csv",
				RowNum:   0,
				Data:     []string{"header1", "header2"},
			},
			expectedSuccess: true,
			expectError:     false,
		},
	}

	processor := NewDefaultProcessor(0) // No delay for testing

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := processor.Process(tt.record)

			if result.Success != tt.expectedSuccess {
				t.Errorf("expected success=%v, got %v", tt.expectedSuccess, result.Success)
			}

			if tt.expectError && result.Error == nil {
				t.Error("expected error but got none")
			}

			if !tt.expectError && result.Error != nil {
				t.Errorf("expected no error but got: %v", result.Error)
			}

			if result.FileName != tt.record.FileName {
				t.Errorf("expected filename %s, got %s", tt.record.FileName, result.FileName)
			}

			if result.RowNum != tt.record.RowNum {
				t.Errorf("expected row number %d, got %d", tt.record.RowNum, result.RowNum)
			}
		})
	}
}

func TestDefaultProcessor_ProcessingTime(t *testing.T) {
	processingTime := 50 * time.Millisecond
	processor := NewDefaultProcessor(processingTime)

	record := models.Record{
		FileName: "test.csv",
		RowNum:   1,
		Data:     []string{"value"},
	}

	start := time.Now()
	processor.Process(record)
	elapsed := time.Since(start)

	// Should take at least the processing time
	if elapsed < processingTime {
		t.Errorf("expected processing to take at least %v, took %v", processingTime, elapsed)
	}
}

