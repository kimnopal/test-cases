package reader

import (
	"context"
	"encoding/csv"
	"fmt"
	"io"
	"os"
	"sync"

	"concurrent-data-processing/pkg/models"
)

type FileReader struct {
	files []string
}

func New(files []string) *FileReader {
	return &FileReader{files: files}
}

func (fr *FileReader) ReadFiles(ctx context.Context, out chan<- models.Record, errChan chan<- error) {
	var wg sync.WaitGroup

	for _, filename := range fr.files {
		wg.Add(1)

		go func(fname string) {
			defer wg.Done()

			if err := fr.readFile(ctx, fname, out, errChan); err != nil {
				errChan <- err
			}
		}(filename)
	}

	go func() {
		wg.Wait()
		close(out)
	}()
}

func (fr *FileReader) readFile(ctx context.Context, filename string, out chan<- models.Record, errChan chan<- error) error {
	file, err := os.Open(filename)
	if err != nil {
		return fmt.Errorf("failed to open %s: %w", filename, err)
	}
	defer file.Close()

	reader := csv.NewReader(file)
	rowNum := 0

	for {
		select {
		case <-ctx.Done():
			return ctx.Err()
		default:
		}

		row, err := reader.Read()
		if err == io.EOF {
			break
		}
		if err != nil {
			errChan <- fmt.Errorf("error reading %s row %d: %w", filename, rowNum, err)
			continue
		}

		select {
		case <-ctx.Done():
			return ctx.Err()
		case out <- models.Record{
			FileName: filename,
			RowNum:   rowNum,
			Data:     row,
		}:
		}

		rowNum++
	}

	return nil
}

