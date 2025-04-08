# Makefile for inkport setup and dev tasks

INSTALL_DIR ?= /usr/local/bin
SCRIPT_NAME ?= inkport

.PHONY: all install uninstall lint check test help

all: check

install:
	@echo "🔧 Installing $(SCRIPT_NAME) to $(INSTALL_DIR)..."
	install -m 755 inkport.sh "$(INSTALL_DIR)/$(SCRIPT_NAME)"

uninstall:
	@echo "🗑️  Removing $(INSTALL_DIR)/$(SCRIPT_NAME)..."
	rm -f "$(INSTALL_DIR)/$(SCRIPT_NAME)"

lint:
	shellcheck lib/*.bash inkport.sh

check: lint

test:
	bats test/

setup:
	@bash install.sh

help:
	@echo "Available targets:"
	@echo "  make install     Install inkport to $(INSTALL_DIR)"
	@echo "  make uninstall   Remove installed inkport binary"
	@echo "  make lint        Run ShellCheck on scripts"
	@echo "  make check       Alias for lint"
	@echo "  make test        Run tests with bats"
	@echo "  make setup       Run interactive installer (install.sh)"
