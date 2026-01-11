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

## Security Model

Go is distributed via HTTPS from `https://go.dev/dl/`. The Go project publishes **checksums (currently only SHA‑256)** on that page. There are **no official GPG signatures**, **no transparency log**, and **no independent authenticated checksum channel**.

Although some `.asc` files exist on the Go download servers and contain valid PGP signatures — for example:

https://go.dev/dl/go1.25.5.linux-amd64.tar.gz.asc

```
$ file ~/Downloads/go1.25.5.linux-amd64.tar.gz.asc
/home/user/Downloads/go1.25.5.linux-amd64.tar.gz.asc: PGP signature Signature (old)

$ cat ~/Downloads/go1.25.5.linux-amd64.tar.gz.asc
-----BEGIN PGP SIGNATURE-----
iQIzBAABCAAdFiEEDwb/hr7q9OcYZu5SMu5TVaa8bkIFAmkmj+4ACgkQMu5TVaa8
bkLWShAApANAp8omwrF0dh+w/gR3SiLDtmJULqKmKfQwG73pCqBNzcYFg+uWfo74
FJCwfe5yn7ucCu2/zByZX6IPV9CIp6tPlVKs8iOg0LUcLRq3I4zk7WLEeXi94+vV
szy9TrZk9K3ZHqLhmg8btvMp/QlM4m8BME8cISVECfrnUJ2CEhKz+aK/vhj2oTuN
jJGmx/iBV5a5WKOp/Zby1+SUcDumFWnQNmFmLXOXnXndtNifrhVF2HEujaeC9pIb
Huc/M6DnSYDBuvHg2q/s/0OrNH3vnmV9l38S/YPS4E1iN1NugdtPH229aA2CBPv+
T7tPKGmss0SwDwMeECX1gNVn6EO8LCv4aHUZVSdiK9AWyDAxgVz+FBQcgbn2D2xr
ChVSRQrwgErRebypLdpDJB2PxHqGQlTicyEdo2WGQKdIW8AfQdR8N96+y08vhuH1
09rPUrrnCCTm54voSv6Rydu6gXUzbt+dhaBpf2CIPUbrbSS4Oxmxae0kU36OaQcj
cyDehLu547JMbZok/LfEYnm/cSaQX6Y+uN7gJUr8qCBlHAmhBKYHACcIdWqY3a3x
qKnpcr2WYB8NaPtOx3rMmv2vfdZoaGI82tmkrd/tOlvCDzXw+C/yTWx9M+r2OzNX
JyT2b9+yFgVeHzsbCBCr8szWWmXED+5t/71NCMLGGOV6Ga2KExY=
=A7WM
-----END PGP SIGNATURE-----
```

However, the Go project does not document, support, or guarantee GPG signatures as part of its release process. No official public key, fingerprint, or verification procedure is provided. These signatures appear to be artifacts of Google’s internal infrastructure rather than an official security mechanism. For this reason, `letsgolang` does not rely on GPG verification.

> The Go Authors. (n.d.). _Downloads_. Retrieved January 11, 2026, from https://go.dev/dl/

### What `letsgolang` currently does

- **Enforces HTTPS security**: Uses `curl --fail --proto '=https' --tlsv1.2` for all network access to avoid protocol downgrade and enforce TLS 1.2+.
- **Computes local checksums (SHA‑256 and SHA‑512)**: After downloading the tarball, it computes both SHA‑256 and SHA‑512 for the local file.
- **Uses only SHA‑256 for official verification**:
  - The Go download page currently publishes only **SHA‑256** checksums.
  - `letsgolang` matches the **local SHA‑256** against the checksums found on `https://go.dev/dl/`.
  - SHA‑512 is computed for diagnostic/future use, but there is **no official SHA‑512 reference** to compare against.
- **Aborts on mismatch or failure**: If the SHA‑256 hash is not found in the official checksum list, or if checksum calculation or download integrity checks fail, the installer aborts.

### Future roadmap and trade-offs

- **Cross-checking SHA‑256 against independent sources**\
  _Concept_: Verify the hash against Repology, Homebrew, or distro packaging metadata.\
  _Trade-off_: Increases assurance but adds **latency and fragility**. Third‑party ecosystems often lag hours or days behind `go.dev`, which can cause false failures right after a new Go release.

- **Certificate pinning**\
  _Concept_: Hardcode the TLS certificate (or fingerprint) for `go.dev` to reduce the impact of some MITM attacks.\
  _Trade-off_: High **operational maintenance cost**. When Google rotates certificates (which happens regularly), the installer may break until `letsgolang` is updated.

- **Trust‑on‑First‑Use (TOFU)**\
  _Concept_: Store the verified checksum locally on first run and warn if future downloads of the same version differ.\
  _Trade-off_: Great for detecting tampering over time, but offers **no protection for the very first installation**, which still relies on the upstream infrastructure.

- **Heuristic validation**\
  _Concept_: Inspect the tarball structure (e.g., existence of `go/bin/go`, `go/src`, etc.) before or after extraction.\
  _Trade-off_: Helps catch obviously corrupted or malformed archives, but provides **no cryptographic guarantee** against targeted binary modification.

### What `letsgolang` cannot do (limitations of Go’s distribution model)

- **GPG verification**: No official signed release artifacts or public keys are provided by the Go project.
- **Transparency logs**: There is no official log (like Sigstore/Rekor) of artifacts to verify against.
- **Independent authenticated checksum channel**: Checksums are only available on the same site that serves the binaries, over the same HTTPS connection.
- **Dedicated, authenticated metadata API**: All metadata is scraped from the HTML of the download page.

`letsgolang` cannot provide cryptographic guarantees stronger than those offered by Go’s own distribution model. It focuses on enforcing HTTPS, verifying the downloaded file’s SHA‑256 against the official checksum, and failing fast when something doesn’t match expectations.

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

### Sample run

```sh
[INFO] STEP 1/6:
[INFO] Getting the current version from 'https://go.dev/VERSION?m=text'...
[INFO] Current version found: 1.25.5.
[INFO] STEP 2/6:
[INFO] Searching for installation...
[INFO] No installation found.
[INFO] STEP 3/6:
[INFO] Downloading the installation file from 'https://go.dev/dl/go1.25.5.linux-amd64.tar.gz'...
########################################################################################################################################## 100.0%
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
[INFO] Done.

To apply the changes to your current shell session, run:
  . $HOME/.bashrc

[INFO] All temporary assets have been removed.
```

### Non-interactive Usage

For automation or CI environments, use the `--assume-yes` flag to skip prompts:

```sh
./src/letsgolang.sh --assume-yes
```

## CLI Options

The installer supports the following flags:

| Option             | Description                                          |
| :----------------- | :--------------------------------------------------- |
| `-u, --uninstall`  | Uninstall Go (removes binary and environment config) |
| `-v, --verbose`    | Enable verbose mode for detailed logging             |
| `-q, --quiet`      | Enable quiet mode (suppress non-essential output)    |
| `-y, --assume-yes` | Run in non-interactive mode (auto-confirm prompts)   |
| `-h, --help`       | Print help message                                   |
| `-V, --version`    | Print installer version                              |
| `--license`        | Print license information                            |

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

- [Apache License, Version 2.0](LICENSE-APACHE)
- [MIT license](LICENSE-MIT)

at your option.
