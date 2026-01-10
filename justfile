set shell := ["sh", "-c"]

# Path to the main script

target_script := "src/letsgolang.sh"

# Default recipe: verify project integrity
default: check

# Run all unit tests
test:
    @echo "Running tests..."
    ./scripts/run_tests.sh

# Run tests matching a specific name or pattern

# Usage: just test-filter <pattern>
test-filter pattern:
    ./scripts/run_tests.sh --filter {{ pattern }}

# Update the script version from the latest Git tag
bump-version:
    @if [ ! -f "{{ target_script }}" ]; then \
        printf "\033[31mError: Target script not found at {{ target_script }}\033[0m\n"; \
        exit 1; \
    fi
    ./scripts/revision.sh {{ target_script }}

# Perform project integrity and metadata synchronization checks
check:
    ./scripts/check_project.sh
