package models

import "time"

type Record struct {
	FileName string
	RowNum   int
	Data     []string
}

type Result struct {
	FileName    string
	RowNum      int
	ProcessedAt time.Time
	Success     bool
	Error       error
}

type ProgressReport struct {
	TotalFiles       int
	ProcessedFiles   int
	TotalRecords     int
	ProcessedRecords int
	Errors           int
}

