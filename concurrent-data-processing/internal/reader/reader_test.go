package reader

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"testing"
	"time"

	"concurrent-data-processing/pkg/models"
)

func TestFileReader_ReadFiles(t *testing.T) {
	// Create temporary test CSV file
	tmpDir := t.TempDir()
	testFile := filepath.Join(tmpDir, "test.csv")

	content := "id,name,value\n1,test1,100\n2,test2,200\n"
	if err := os.WriteFile(testFile, []byte(content), 0644); err != nil {
		t.Fatalf("failed to create test file: %v", err)
	}

	tests := []struct {
		name           string
		files          []string
		expectedCount  int
		expectError    bool
		contextTimeout time.Duration
	}{
		{
			name:           "successful read single file",
			files:          []string{testFile},
			expectedCount:  3, // header + 2 data rows
			expectError:    false,
			contextTimeout: 5 * time.Second,
		},
		{
			name:           "missing file should send error",
			files:          []string{"nonexistent.csv"},
			expectedCount:  0,
			expectError:    true,
			contextTimeout: 5 * time.Second,
		},
		{
			name:           "context cancellation",
			files:          []string{testFile},
			expectedCount:  0,
			expectError:    false,
			contextTimeout: 1 * time.Nanosecond, // immediate timeout
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			ctx, cancel := context.WithTimeout(context.Background(), tt.contextTimeout)
			defer cancel()

			recordsChan := make(chan models.Record, 10)
			errorsChan := make(chan error, 10)

			reader := New(tt.files)
			reader.ReadFiles(ctx, recordsChan, errorsChan)

			// Collect records
			var records []models.Record
			done := make(chan struct{})
			go func() {
				for record := range recordsChan {
					records = append(records, record)
				}
				close(done)
			}()

			// Wait for completion or timeout
			select {
			case <-done:
				// Records channel closed
			case <-time.After(2 * time.Second):
				t.Fatal("test timed out waiting for records")
			}

			// Check for errors
			hasError := false
			select {
			case <-errorsChan:
				hasError = true
			default:
			}

			if tt.expectError && !hasError {
				t.Error("expected error but got none")
			}

			if !tt.expectError && tt.contextTimeout > time.Second {
				if len(records) != tt.expectedCount {
					t.Errorf("expected %d records, got %d", tt.expectedCount, len(records))
				}
			}
		})
	}
}

func TestFileReader_ReadFiles_MultipleFiles(t *testing.T) {
	tmpDir := t.TempDir()

	// Create multiple test files
	files := []string{}
	for i := 1; i <= 3; i++ {
		testFile := filepath.Join(tmpDir, fmt.Sprintf("test%d.csv", i))
		content := fmt.Sprintf("id,name\n%d,test%d\n", i, i)
		if err := os.WriteFile(testFile, []byte(content), 0644); err != nil {
			t.Fatalf("failed to create test file: %v", err)
		}
		files = append(files, testFile)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	recordsChan := make(chan models.Record, 10)
	errorsChan := make(chan error, 10)

	reader := New(files)
	reader.ReadFiles(ctx, recordsChan, errorsChan)

	// Collect all records
	records := []models.Record{}
	for record := range recordsChan {
		records = append(records, record)
	}

	// Should have 6 records total (2 rows per file * 3 files)
	expectedCount := 6
	if len(records) != expectedCount {
		t.Errorf("expected %d records from 3 files, got %d", expectedCount, len(records))
	}

	// Verify records from different files
	fileMap := make(map[string]int)
	for _, record := range records {
		fileMap[record.FileName]++
	}

	if len(fileMap) != 3 {
		t.Errorf("expected records from 3 different files, got %d", len(fileMap))
	}
}

func TestFileReader_ReadFile_InvalidCSV(t *testing.T) {
	tmpDir := t.TempDir()
	testFile := filepath.Join(tmpDir, "invalid.csv")

	// Create invalid CSV with inconsistent columns
	content := "id,name\n1,test1,extra\n2,test2\n"
	if err := os.WriteFile(testFile, []byte(content), 0644); err != nil {
		t.Fatalf("failed to create test file: %v", err)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	recordsChan := make(chan models.Record, 10)
	errorsChan := make(chan error, 10)

	reader := New([]string{testFile})
	reader.ReadFiles(ctx, recordsChan, errorsChan)

	// Should get some errors
	hasError := false
	timeout := time.After(1 * time.Second)
	
	for {
		select {
		case <-errorsChan:
			hasError = true
		case <-recordsChan:
			// Continue reading
		case <-timeout:
			goto done
		}
	}
	
done:
	if !hasError {
		t.Error("expected errors from invalid CSV, got none")
	}
}

