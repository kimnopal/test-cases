package processor

import (
	"context"
	"os"
	"path/filepath"
	"testing"
	"time"

	"concurrent-data-processing/internal/tracker"
	"concurrent-data-processing/internal/worker"
	"concurrent-data-processing/pkg/models"
)

func TestProcessor_Process(t *testing.T) {
	tmpDir := t.TempDir()
	
	testFiles := []string{}
	for i := 1; i <= 3; i++ {
		testFile := filepath.Join(tmpDir, "test"+string(rune('0'+i))+".csv")
		content := "id,name,value\n1,test1,100\n2,test2,200\n"
		if err := os.WriteFile(testFile, []byte(content), 0644); err != nil {
			t.Fatalf("failed to create test file: %v", err)
		}
		testFiles = append(testFiles, testFile)
	}

	tests := []struct {
		name              string
		files             []string
		numWorkers        int
		contextTimeout    time.Duration
		expectError       bool
		minRecordsExpected int
	}{
		{
			name:              "successful processing",
			files:             testFiles,
			numWorkers:        3,
			contextTimeout:    10 * time.Second,
			expectError:       false,
			minRecordsExpected: 9, // 3 rows per file * 3 files
		},
		{
			name:              "single worker",
			files:             testFiles[:1],
			numWorkers:        1,
			contextTimeout:    10 * time.Second,
			expectError:       false,
			minRecordsExpected: 3,
		},
		{
			name:              "context timeout",
			files:             testFiles,
			numWorkers:        1,
			contextTimeout:    1 * time.Nanosecond,
			expectError:       true,
			minRecordsExpected: 0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			ctx, cancel := context.WithTimeout(context.Background(), tt.contextTimeout)
			defer cancel()

			config := Config{
				Files:          tt.files,
				NumWorkers:     tt.numWorkers,
				RecordsBufSize: 10,
				ResultsBufSize: 10,
				ErrorsBufSize:  5,
				WorkerProcessor: worker.NewDefaultProcessor(1 * time.Millisecond),
				TrackerConfig: tracker.Config{
					TotalFiles: len(tt.files),
					PrintFunc:  func(models.ProgressReport) {},
				},
			}

			processor := New(config)
			err := processor.Process(ctx)

			if tt.expectError && err == nil {
				t.Error("expected error but got none")
			}

			if !tt.expectError && err != nil {
				t.Errorf("unexpected error: %v", err)
			}

			if !tt.expectError {
				progress := processor.GetProgress()
				if progress.ProcessedRecords < tt.minRecordsExpected {
					t.Errorf("expected at least %d records, got %d", tt.minRecordsExpected, progress.ProcessedRecords)
				}
			}
		})
	}
}

func TestProcessor_WithMissingFiles(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	tmpDir := t.TempDir()
	existingFile := filepath.Join(tmpDir, "exists.csv")
	content := "id,name\n1,test\n"
	if err := os.WriteFile(existingFile, []byte(content), 0644); err != nil {
		t.Fatalf("failed to create test file: %v", err)
	}

	files := []string{
		existingFile,
		filepath.Join(tmpDir, "missing.csv"),
	}

	config := Config{
		Files:      files,
		NumWorkers: 2,
		TrackerConfig: tracker.Config{
			PrintFunc: func(models.ProgressReport) {},
		},
	}

	processor := New(config)
	err := processor.Process(ctx)

	if err != nil {
		t.Errorf("unexpected error: %v", err)
	}

	progress := processor.GetProgress()
	if progress.ProcessedRecords < 1 {
		t.Errorf("expected at least 1 record from existing file, got %d", progress.ProcessedRecords)
	}
}

func TestDefaultConfig(t *testing.T) {
	files := []string{"file1.csv", "file2.csv", "file3.csv"}
	config := DefaultConfig(files)

	if len(config.Files) != len(files) {
		t.Errorf("expected %d files, got %d", len(files), len(config.Files))
	}

	if config.NumWorkers != 5 {
		t.Errorf("expected default 5 workers, got %d", config.NumWorkers)
	}

	if config.RecordsBufSize != 100 {
		t.Errorf("expected records buffer 100, got %d", config.RecordsBufSize)
	}

	if config.ResultsBufSize != 100 {
		t.Errorf("expected results buffer 100, got %d", config.ResultsBufSize)
	}

	if config.ErrorsBufSize != 10 {
		t.Errorf("expected errors buffer 10, got %d", config.ErrorsBufSize)
	}
}

func TestNew_WithDefaults(t *testing.T) {
	config := Config{
		Files: []string{"file1.csv"},
	}

	processor := New(config)

	if processor.config.NumWorkers != 5 {
		t.Errorf("expected default 5 workers, got %d", processor.config.NumWorkers)
	}

	if processor.config.RecordsBufSize != 100 {
		t.Errorf("expected default records buffer 100, got %d", processor.config.RecordsBufSize)
	}

	if processor.config.WorkerProcessor == nil {
		t.Error("expected default worker processor to be set")
	}
}

func TestProcessor_GetProgress(t *testing.T) {
	tmpDir := t.TempDir()
	testFile := filepath.Join(tmpDir, "test.csv")
	content := "id\n1\n2\n"
	if err := os.WriteFile(testFile, []byte(content), 0644); err != nil {
		t.Fatalf("failed to create test file: %v", err)
	}

	config := Config{
		Files:      []string{testFile},
		NumWorkers: 1,
		TrackerConfig: tracker.Config{
			PrintFunc: func(models.ProgressReport) {},
		},
	}

	processor := New(config)

	progress := processor.GetProgress()
	if progress.ProcessedRecords != 0 {
		t.Errorf("expected 0 processed records initially, got %d", progress.ProcessedRecords)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	
	processor.Process(ctx)

	progress = processor.GetProgress()
	if progress.ProcessedRecords != 3 {
		t.Errorf("expected 3 processed records, got %d", progress.ProcessedRecords)
	}
}

