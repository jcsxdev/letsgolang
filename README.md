# letsgolang: The Go Installer

<div align="center">

[![OpenSSF Best Practices](https://www.bestpractices.dev/projects/11658/badge)](https://www.bestpractices.dev/projects/11658)
[![OpenSSF Scorecard](https://api.securityscorecards.dev/projects/github.com/jcsxdev/letsgolang/badge)](https://securityscorecards.dev/viewer/?uri=github.com/jcsxdev/letsgolang)
[![Shell Script Quality Checks](https://github.com/jcsxdev/letsgolang/actions/workflows/shell-quality.yml/badge.svg)](https://github.com/jcsxdev/letsgolang/actions/workflows/shell-quality.yml)
[![Security Audit](https://github.com/jcsxdev/letsgolang/actions/workflows/security.yml/badge.svg)](https://github.com/jcsxdev/letsgolang/actions/workflows/security.yml)
[![License](https://img.shields.io/github/license/jcsxdev/letsgolang)](LICENSE)

</div>

A minimalist and POSIX-compliant non-root installer for the Go programming language on Linux.

## Overview

`letsgolang` automates the process of fetching, verifying, and installing the latest official Go distribution directly into your user environment.

- **Non-root**: Installs to `$HOME/.local/opt/go` by default, requiring no `sudo` privileges.
- **Auditable**: Written in pure POSIX shell. No opaque binaries or hidden dependencies to trust.
- **Reliable**: Enforces SHA256 checksum verification and handles environment configuration automatically.

## Requirements

To run the installer, your system needs standard POSIX tools:

- A POSIX-compliant shell (`/bin/sh`)
- `curl` or `wget` (for downloading)
- `tar` (for extraction)
- `sha256sum` or `shasum` (for verification)

## Quick Start

1. Clone this repository:

```sh
git clone <repository-url>
cd letsgolang
```

2. Run the installer script:

```sh
./src/letsgolang.sh
```

### Non-interactive Usage

For automation or CI environments, use the `--assume-yes` flag to skip prompts:

```sh
./src/letsgolang.sh --assume-yes
```

## CLI Options

The installer supports the following flags:

| Option | Description |
| :--- | :--- |
| `-u, --uninstall` | Uninstall Go (removes binary and environment config) |
| `-v, --verbose` | Enable verbose mode for detailed logging |
| `-q, --quiet` | Enable quiet mode (suppress non-essential output) |
| `-y, --assume-yes` | Run in non-interactive mode (auto-confirm prompts) |
| `-h, --help` | Print help message |
| `-V, --version` | Print installer version |
| `--license` | Print license information |

## Installation Details

- **Location**: Go is installed into `$HOME/.local/opt/go`.
- **Symlinks**: The installer manages `GOROOT` and `PATH` settings.
- **Shell Config**: It automatically updates your shell profile (e.g., `.bashrc`, `.zshrc`, `config.fish`, or `.profile`) to include:
  ```sh
  export GOROOT="$HOME/.local/opt/go"
  export PATH="$GOROOT/bin:$HOME/go/bin:$PATH"
  ```

## Uninstallation

To uninstall Go, run the script with the `--uninstall` (or `-u`) flag:

```sh
./src/letsgolang.sh --uninstall
```

This command will:
1. Remove the Go installation directory (`$HOME/.local/opt/go`).
2. Check your shell configuration file for Go-related environment variables and advise you if manual cleanup is needed.

## Troubleshooting

- **Command not found**: If `go` is not found after installation, try reloading your shell configuration:
  ```sh
  source ~/.bashrc  # or ~/.zshrc, ~/.profile, etc.
  ```
- **Permission denied**: Ensure the script is executable (`chmod +x src/letsgolang.sh`).
- **Checksum mismatch**: This indicates a corrupted download or a security issue. The installer will abort automatically to protect your system.

## Documentation

- [Building and Installation](BUILDING.md)

- [Contributing Guidelines](CONTRIBUTING.md)

## License

This project is licensed under either of:

* [Apache License, Version 2.0](LICENSE-APACHE)
* [MIT license](LICENSE-MIT)

at your option.
