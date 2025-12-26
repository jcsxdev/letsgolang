.PHONY: all help test bump-version test-only

.DEFAULT_GOAL := help

TARGET_SCRIPT := src/letsgolang.sh

# Colors for output
GREY := [0;37m
CYAN := [0;36m
NO_COLOR := [0m

## help: Show this help message.
help:
	@echo ""
	@echo "Usage: make <target>"
	@echo ""
	@echo "Targets:"
	@grep '^##' $(MAKEFILE_LIST) | awk -F': ' '{printf "$(CYAN)%-20s$(NO_COLOR) %s\n", substr($$1, 4), $$2}'
	@echo ""

## test: Run all unit tests.
test:
	@echo "Running tests..."
	@./scripts/run_tests.sh

## test-filter: Run tests matching a specific name or pattern. Requires 'name' argument.
##              Example: make test-filter name=test_is_no_color
test-filter:
	@[ -z "$(name)" ] && \
	echo "Error: 'name' argument is missing. Usage: make test-filter name=<pattern>" && \
	exit 1 || \
	./scripts/run_tests.sh --filter $(name)

## bump-version: Update the script version from the latest Git tag.
bump-version:
	@if [ ! -f "$(TARGET_SCRIPT)" ]; then \
		printf "[31mError: Target script not found at %s[0m\n" "$(TARGET_SCRIPT)"; \
		exit 1; \
	fi
	@./scripts/revision.sh $(TARGET_SCRIPT)
