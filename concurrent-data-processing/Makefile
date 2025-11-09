.PHONY: build test run clean fmt vet lint install-tools coverage help

# Variables
BINARY_NAME=processor
CMD_PATH=./cmd/processor
BUILD_DIR=./bin
COVERAGE_DIR=./coverage

# Colors for output
GREEN=\033[0;32m
YELLOW=\033[0;33m
RED=\033[0;31m
NC=\033[0m # No Color

help: ## Show this help message
	@echo '$(GREEN)Available targets:$(NC)'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-15s$(NC) %s\n", $$1, $$2}'

build: ## Build the application
	@echo '$(GREEN)Building application...$(NC)'
	@mkdir -p $(BUILD_DIR)
	@go build -o $(BUILD_DIR)/$(BINARY_NAME) $(CMD_PATH)
	@echo '$(GREEN)✓ Build complete: $(BUILD_DIR)/$(BINARY_NAME)$(NC)'

run: ## Run the application
	@echo '$(GREEN)Running application...$(NC)'
	@go run $(CMD_PATH)

run-custom: ## Run with custom files (usage: make run-custom FILES="file1.csv,file2.csv")
	@echo '$(GREEN)Running with custom files...$(NC)'
	@go run $(CMD_PATH) -files="$(FILES)"

test: ## Run all tests
	@echo '$(GREEN)Running tests...$(NC)'
	@go test -v -race ./...

test-short: ## Run tests without race detector (faster)
	@echo '$(GREEN)Running tests (short)...$(NC)'
	@go test -v -short ./...

test-coverage: ## Run tests with coverage
	@echo '$(GREEN)Running tests with coverage...$(NC)'
	@mkdir -p $(COVERAGE_DIR)
	@go test -v -race -coverprofile=$(COVERAGE_DIR)/coverage.out ./...
	@go tool cover -html=$(COVERAGE_DIR)/coverage.out -o $(COVERAGE_DIR)/coverage.html
	@echo '$(GREEN)✓ Coverage report: $(COVERAGE_DIR)/coverage.html$(NC)'

coverage: test-coverage ## Alias for test-coverage

bench: ## Run benchmarks
	@echo '$(GREEN)Running benchmarks...$(NC)'
	@go test -bench=. -benchmem ./...

fmt: ## Format code
	@echo '$(GREEN)Formatting code...$(NC)'
	@go fmt ./...
	@echo '$(GREEN)✓ Code formatted$(NC)'

vet: ## Run go vet
	@echo '$(GREEN)Running go vet...$(NC)'
	@go vet ./...
	@echo '$(GREEN)✓ Vet passed$(NC)'

lint: ## Run golangci-lint (requires golangci-lint installed)
	@echo '$(GREEN)Running linter...$(NC)'
	@which golangci-lint > /dev/null || (echo '$(RED)Error: golangci-lint not installed. Run: make install-tools$(NC)' && exit 1)
	@golangci-lint run ./...
	@echo '$(GREEN)✓ Lint passed$(NC)'

install-tools: ## Install development tools
	@echo '$(GREEN)Installing development tools...$(NC)'
	@go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
	@echo '$(GREEN)✓ Tools installed$(NC)'

clean: ## Clean build artifacts and test cache
	@echo '$(GREEN)Cleaning...$(NC)'
	@rm -rf $(BUILD_DIR)
	@rm -rf $(COVERAGE_DIR)
	@go clean -testcache
	@echo '$(GREEN)✓ Clean complete$(NC)'

deps: ## Download dependencies
	@echo '$(GREEN)Downloading dependencies...$(NC)'
	@go mod download
	@echo '$(GREEN)✓ Dependencies downloaded$(NC)'

tidy: ## Tidy go.mod
	@echo '$(GREEN)Tidying go.mod...$(NC)'
	@go mod tidy
	@echo '$(GREEN)✓ go.mod tidied$(NC)'

verify: fmt vet test ## Run format, vet, and test

ci: deps verify ## CI pipeline: deps + verify

all: clean deps build test ## Clean, download deps, build, and test

.DEFAULT_GOAL := help

