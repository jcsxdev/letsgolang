# letsgolang: The Go Installer

<div align="center">

[![Shell Script Quality Checks](https://github.com/jcsxdev/letsgolang/actions/workflows/shell-quality.yml/badge.svg)](https://github.com/jcsxdev/letsgolang/actions/workflows/shell-quality.yml)
[![Security Audit](https://github.com/jcsxdev/letsgolang/actions/workflows/security.yml/badge.svg)](https://github.com/jcsxdev/letsgolang/actions/workflows/security.yml)
[![OpenSSF Scorecard](https://api.securityscorecards.dev/projects/github.com/jcsxdev/letsgolang/badge)](https://securityscorecards.dev/viewer/?uri=github.com/jcsxdev/letsgolang)
[![License](https://img.shields.io/github/license/jcsxdev/letsgolang)](LICENSE)

</div>

A minimalist and POSIX-compliant non-root installer for the Go programming language on Linux.

## Overview

`letsgolang` automates the process of fetching, verifying, and installing the latest official Go distribution directly into your user environment.

- **Non-root**: Installs to `$HOME/.local/opt/go` by default, requiring no `sudo` privileges.
- **Auditable**: Written in pure POSIX shell. No opaque binaries or hidden dependencies to trust.
- **Reliable**: Enforces SHA256 checksum verification and handles environment configuration automatically.

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

**Example Output:**

```text
[INFO] STEP 1/6:
[INFO] Getting the current version from 'https://go.dev/VERSION?m=text'...
[INFO] Current version found: 1.25.5.
[INFO] STEP 2/6:
[INFO] Searching for installation...
[INFO] No installation found.
[INFO] STEP 3/6:
[INFO] Downloading the installation file from 'https://go.dev/dl/go1.25.5.linux-amd64.tar.gz'...
##################################################################################################################################################################### 100.0%
[INFO] STEP 4/6:
[INFO] Validating the 'go1.25.5.linux-amd64.tar.gz' file...
[INFO] Getting checksums of downloaded files...
[INFO] File checksums:
  - SHA256SUM: 9e9b755d63b36acf30c12a9a3fc379243714c1c6d3dd72861da637f336ebb35b
  - SHA512SUM: b23f749a51b6da1bf7042a87af6daca2454604c69c62044627b411769f207ac5676fb629948a26c16000c3b495bf785902c3250a6db4522f60dbf4ad900064a8
[INFO] Finding checksums on 'https://go.dev/dl'...
[INFO] 1 checksum found:
  - SHA256SUM: 9e9b755d63b36acf30c12a9a3fc379243714c1c6d3dd72861da637f336ebb35b
[INFO] STEP 5/6:
[INFO] Extracting 'go1.25.5.linux-amd64.tar.gz' file to '/home/user/.local/opt/go'...
[INFO] STEP 6/6:
[INFO] Configuring environment variables in /home/user/.bashrc...
[INFO] Run: source /home/user/.bashrc
[INFO] Done.
```

## Uninstallation

Since letsgolang runs without root privileges, removal is simple:

1. Delete the installation directory:

```sh
rm -rf $HOME/.local/opt/go
```

2. Remove the Go environment variables from your shell configuration file (e.g., .bashrc or .zshrc).

## Documentation

- [Building and Installation](BUILDING.md)

- [Contributing Guidelines](CONTRIBUTING.md)

## License

This project is licensed under the [MIT License](LICENSE.md).
