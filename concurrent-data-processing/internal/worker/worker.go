package worker

import (
	"context"
	"fmt"
	"sync"
	"time"

	"concurrent-data-processing/pkg/models"
)

type Pool struct {
	numWorkers int
	processor  Processor
}

type Processor interface {
	Process(record models.Record) models.Result
}

type DefaultProcessor struct {
	processingTime time.Duration
}

func New(numWorkers int, processor Processor) *Pool {
	return &Pool{
		numWorkers: numWorkers,
		processor:  processor,
	}
}

func NewDefaultProcessor(processingTime time.Duration) *DefaultProcessor {
	return &DefaultProcessor{
		processingTime: processingTime,
	}
}

func (wp *Pool) Start(ctx context.Context, in <-chan models.Record, out chan<- models.Result) {
	var wg sync.WaitGroup

	for i := 0; i < wp.numWorkers; i++ {
		wg.Add(1)

		go func(workerID int) {
			defer wg.Done()
			wp.worker(ctx, workerID, in, out)
		}(i)
	}

	go func() {
		wg.Wait()
		close(out)
	}()
}

func (wp *Pool) worker(ctx context.Context, workerID int, in <-chan models.Record, out chan<- models.Result) {
	for {
		select {
		case <-ctx.Done():
			return
		case record, ok := <-in:
			if !ok {
				return
			}

			result := wp.processor.Process(record)

			select {
			case <-ctx.Done():
				return
			case out <- result:
			}
		}
	}
}

func (dp *DefaultProcessor) Process(record models.Record) models.Result {
	if dp.processingTime > 0 {
		time.Sleep(dp.processingTime)
	}

	if len(record.Data) == 0 {
		return models.Result{
			FileName:    record.FileName,
			RowNum:      record.RowNum,
			ProcessedAt: time.Now(),
			Success:     false,
			Error:       fmt.Errorf("empty record"),
		}
	}

	if record.RowNum == 0 {
		return models.Result{
			FileName:    record.FileName,
			RowNum:      record.RowNum,
			ProcessedAt: time.Now(),
			Success:     true,
			Error:       nil,
		}
	}

	return models.Result{
		FileName:    record.FileName,
		RowNum:      record.RowNum,
		ProcessedAt: time.Now(),
		Success:     true,
		Error:       nil,
	}
}

