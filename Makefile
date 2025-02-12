# Makefile for MJDR (My Jellyfin Docker Runner)

# Variables
SHELL := /bin/bash
BATS_CORE_VERSION := v1.9.0
SHELLCHECK_OPTS := -e SC1090,SC1091

# Detect OS
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
    OS := MacOS
else ifeq ($(UNAME_S),Linux)
    OS := Linux
else
    OS := Windows
endif

# Directories
LIBS_DIR := libs
TESTS_DIR := tests
COVERAGE_DIR := coverage

# Files
SHELL_FILES := $(wildcard $(LIBS_DIR)/*.sh *.sh)
TEST_FILES_UNIT := $(wildcard $(TESTS_DIR)/unit/*.bats)
TEST_FILES_INTEGRATION := $(wildcard $(TESTS_DIR)/integration/*.bats)

.PHONY: help install deps clean test lint coverage start stop debug

help: ## Show this help message
	@echo 'MJDR Development Commands'
	@echo '------------------------'
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

install: deps ## Install all dependencies and setup development environment
	@echo "Setting up development environment..."
	@mkdir -p $(TESTS_DIR)
	@mkdir -p $(COVERAGE_DIR)

deps: ## Install required dependencies
	@echo "Installing dependencies for $(OS)..."
ifeq ($(OS),MacOS)
	@command -v brew >/dev/null 2>&1 || { echo "Installing Homebrew..."; /bin/bash -c "$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; }
	@brew install shellcheck bats-core kcov netcat
else ifeq ($(OS),Linux)
	@sudo apt-get update
	@sudo apt-get install -y shellcheck bats kcov netcat
else
	@echo "Please install dependencies manually on Windows"
endif
	@echo "Installing bats-support and bats-assert..."
	@git clone https://github.com/bats-core/bats-support.git /tmp/bats-support || true
	@git clone https://github.com/bats-core/bats-assert.git /tmp/bats-assert || true
	@sudo mkdir -p /usr/local/lib/bats/
	@sudo cp -r /tmp/bats-support /usr/local/lib/bats/ || true
	@sudo cp -r /tmp/bats-assert /usr/local/lib/bats/ || true

clean: ## Clean temporary files and test artifacts
	@echo "Cleaning temporary files..."
	@find . -type f -name "*.tmp" -delete
	@find . -type f -name "*.log" -delete
	@find . -type f -name "*.bak" -delete
	@rm -rf $(COVERAGE_DIR)
	@echo "Clean complete"

lint: ## Run shellcheck on all shell scripts
	@echo "Running shellcheck..."
	@shellcheck $(SHELLCHECK_OPTS) $(SHELL_FILES)

test-unit: ## Run unit tests
	@echo "Running unit tests..."
	@TERM=xterm-256color bats $(TEST_FILES_UNIT)

test-integration: ## Run integration tests
	@echo "Running integration tests..."
	@TERM=xterm-256color bats $(TEST_FILES_INTEGRATION)

test: lint test-unit test-integration ## Run all tests (lint, unit, integration)
	@echo "All tests completed successfully"

coverage: test ## Generate test coverage report
	@echo "Generating coverage report..."
	@mkdir -p $(COVERAGE_DIR)
	@kcov \
		--include-pattern=.sh \
		--exclude-pattern=.bats,.env.example,tests/ \
		$(COVERAGE_DIR)/ \
		bats $(TEST_FILES_UNIT) $(TEST_FILES_INTEGRATION)
	@echo "Coverage report generated in $(COVERAGE_DIR)"

start: ## Start Jellyfin container
	@echo "Starting Jellyfin..."
	@./start-jellyfin.sh

stop: ## Stop Jellyfin container
	@echo "Stopping Jellyfin..."
	@./stop-jellyfin.sh

debug: ## Start Jellyfin in debug mode
	@echo "Starting Jellyfin in debug mode..."
	@./start-jellyfin.sh --debug

# Development helpers
.PHONY: dev-setup dev-clean dev-update

dev-setup: install ## Setup complete development environment
	@echo "Development environment setup complete"

dev-clean: clean ## Clean development environment
	@echo "Development environment cleaned"

dev-update: ## Update development dependencies
	@echo "Updating dependencies..."
	@make deps
