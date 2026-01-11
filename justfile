set shell := ["sh", "-c"]

# Path to the main script

target_script := "src/letsgolang.sh"

# Default recipe: verify project integrity
default: check

help:
    @echo "Available commands:"
    @echo ""
    @echo "  just test                 Run all unit tests"
    @echo "  just test-filter <p>      Run tests matching pattern"
    @echo "  just bump-version         Sync version metadata"
    @echo "  just fix                  Apply automatic project fixes (formatting)"
    @echo "  just check                Run project integrity checks"
    @echo "  just release [args]       Build release artifacts"
    @echo ""
    @echo "Release arguments:"
    @echo "  --release <tag>           Use explicit version"
    @echo "  --stripped                Remove leading 'v'"
    @echo "  --sign                    Sign artifacts"
    @echo "  --sign-key <ID>           Use specific GPG key"
    @echo "  --sign-batch              Non-interactive signing"

# Run all unit tests
test:
    @echo "Running tests..."
    ./scripts/run_tests.sh

# Run tests matching a specific name or pattern
test-filter pattern:
    ./scripts/run_tests.sh --filter {{ pattern }}

# Update the script version from the latest Git tag
bump-version:
    @if [ ! -f "{{ target_script }}" ]; then \
        printf "\033[31mError: Target script not found at {{ target_script }}\033[0m\n"; \
        exit 1; \
    fi
    ./scripts/revision.sh {{ target_script }}

# Apply automatic project fixes
fix:
    ./scripts/fix_project.sh

# Perform project integrity and metadata synchronization checks
check:
    ./scripts/check_project.sh

# Build all release artifacts into ./dist
release *args:
    ./scripts/release.sh {{ args }}
