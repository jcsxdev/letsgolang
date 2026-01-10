# Building and Installing

This document provides instructions on how to set up the development environment, run tests, and use the `letsgolang` installer.

## Prerequisites

To use or develop `letsgolang`, you need a POSIX-compliant system with the following tools installed:

- **POSIX Shell** (sh, dash, bash, etc.)
- **curl**: For downloading the Go distributions.
- **tar**: For extracting the Go distributions.
- **git**: Required for version synchronization and development.
- **just**: For task automation.

## Usage

The `letsgolang.sh` script is a standalone non-root installer. You can execute it directly:

```sh
./src/letsgolang.sh
```

For a list of supported options:

```sh
./src/letsgolang.sh --help
```

## Development Tasks

The project uses a `justfile` to manage common development tasks.

### Running Tests

Execute the full test suite:

```sh
just test
```

To run a specific test or filter tests by pattern:

```sh
just test-filter pattern
```

### Project Verification

Before releasing or committing changes, you can verify the integrity of the project (ensuring version constants are populated and synchronized with Git):

```sh
just check
```

### Versioning

The project automates metadata synchronization using Git state. To update the hardcoded version, commit hash, and date in the source code based on the latest Git tag:

```sh
just bump-version
```

If no tags are found, it defaults to `0.0.0`.
