# letsgolang: The Go Installer

<div align="center">

[![OpenSSF Best Practices](https://www.bestpractices.dev/projects/11658/badge)](https://www.bestpractices.dev/projects/11658)
[![OpenSSF Scorecard](https://api.securityscorecards.dev/projects/github.com/jcsxdev/letsgolang/badge)](https://securityscorecards.dev/viewer/?uri=github.com/jcsxdev/letsgolang)
[![Shell Script Quality Checks](https://github.com/jcsxdev/letsgolang/actions/workflows/shell-quality.yml/badge.svg)](https://github.com/jcsxdev/letsgolang/actions/workflows/shell-quality.yml)
[![Security Audit](https://github.com/jcsxdev/letsgolang/actions/workflows/security.yml/badge.svg)](https://github.com/jcsxdev/letsgolang/actions/workflows/security.yml)
[![License](https://img.shields.io/github/license/jcsxdev/letsgolang)](LICENSE)

</div>

`letsgolang` is a minimalist, POSIX-oriented, non-root installer for the Go programming language on Linux. It focuses on security, auditability, and simplicity, ensuring your development environment is set up correctly with minimal fuss.

## Table of Contents

- [Overview](#overview)
- [Installation](#installation)
- [Why use letsgolang?](#why-use-letsgolang)
- [Supported Platforms](#supported-platforms)
- [Usage](#usage)
- [Updating Go](#updating-go)
- [Uninstallation](#uninstallation)
- [Installation Details](#installation-details)
- [Security Model](#security-model)
- [Design Goals](#design-goals)
- [Non-Goals](#non-goals)
- [Requirements](#requirements)
- [Troubleshooting](#troubleshooting)
- [FAQ](#faq)
- [Development](#development)
- [Documentation](#documentation)
- [License](#license)

## Overview

`letsgolang` automates the process of fetching, verifying, and installing the latest official Go distribution directly into your user environment.

- **Non-root**: Installs to `$HOME/.local/opt/go` by default, requiring no `sudo` privileges.
- **Auditable**: Written in standard `/bin/sh` with a small set of widely supported extensions. No opaque binaries or hidden runtime dependencies.
- **Reliable**: Enforces SHA256 checksum verification and handles environment configuration automatically.

> **⚠️ WARNING!**
>
> `letsgolang` is an early‑stage, experimental project. While it aims to be safe and predictable, it may still contain bugs or edge cases. Use it at your own discretion and review the installer script before execution.

## Installation

To install Go using `letsgolang`, run:

```sh
curl --proto '=https' --tlsv1.2 -sSLf https://github.com/jcsxdev/letsgolang/releases/latest/download/letsgolang.sh | sh
```

> **Note on curl | sh**\
> This installer uses the `curl | sh` pattern for convenience, but the script is fully transparent and can be downloaded, reviewed, and signature‑verified before execution. HTTPS is enforced, redirects are restricted, and checksum validation is performed to mitigate common risks associated with this installation method.

**About the curl flags**\
The installer uses a hardened `curl` invocation to reduce common risks associated with remote script execution:

- `--proto '=https'` — refuses any protocol other than HTTPS, preventing downgrade attacks. [[docs][curl-proto]]
- `--tlsv1.2` — enforces a minimum TLS version to avoid insecure cipher suites. [[docs][curl-tls]]
- `-sS` — silent mode but still shows errors. [[docs][curl-silent]]
- `-f` — fails on HTTP errors instead of piping HTML error pages into the shell. [[docs][curl-fail]]
- `-L` — follows HTTPS redirects required by GitHub Releases. [[docs][curl-location]]

More info: <https://curl.se/docs/manpage.html>

[curl-proto]: https://curl.se/docs/manpage.html#--proto
[curl-tls]: https://curl.se/docs/manpage.html#--tlsv12
[curl-silent]: https://curl.se/docs/manpage.html#--silent
[curl-fail]: https://curl.se/docs/manpage.html#--fail
[curl-location]: https://curl.se/docs/manpage.html#--location

### Verify installer signature (optional)

```sh
curl --proto '=https' --tlsv1.2 -sSLfO "https://github.com/jcsxdev/letsgolang/releases/latest/download/letsgolang.sh{,.asc}"
gpg --keyserver hkps://keys.openpgp.org --recv-keys DD7C87C3FEACEFF03CD1B93D00073B0954092B26
gpg --verify letsgolang.sh.asc
```

## Why use letsgolang?

- **Zero Dependencies**: No need to install Python, Node.js, or complex version managers. Just a shell and standard utilities (`curl`, `tar`).
- **POSIX-oriented**: Runs on standard `/bin/sh`, prioritizing portability across minimal environments.

> **Note on POSIX orientation**\
> `letsgolang` aims to be portable across standard `/bin/sh` implementations and follows POSIX principles wherever practical. It is described as _POSIX‑oriented_ rather than _POSIX‑compliant_ because it intentionally avoids strict formal compliance in favor of real‑world portability and maintainability. This keeps the script simple, auditable, and compatible with the minimal shells commonly found on Linux systems.

- **Non-Root Installation**: Installs to your home directory, keeping your system partitions clean and secure.
- **Auditable**: The entire logic is in a single, readable shell script. No hidden binaries or black boxes.
- **Predictable**: Enforces official checksums and handles `GOROOT`/`PATH` configuration automatically, preventing common "it works on my machine" issues.

> **Note on auditability**\
> While the script is fully transparent and contains no opaque binaries or generated code, it is not small. “Auditable” here means that all logic is visible, deterministic, and self‑contained — not that the script is trivial to read in its entirety.

## Supported Platforms

- **Linux (glibc)**: First-class target (Debian, Ubuntu, Fedora, CentOS, etc.).
- **Alpine Linux (musl)**: Supported, but relies on Go's upstream musl compatibility.
- **WSL2**: First-class target.
- **WSL1**: Supported (best effort).
- **NixOS**: Partially supported (installation works, but environment configuration may require manual tweaks due to NixOS's unique structure).
- **macOS**: Not supported (use the official pkg installer or Homebrew).

Support for the platforms listed above is based on expected compatibility; only the environments listed in the “Tested Environments” section have been validated directly.

### Tested Environments

The installer has been tested directly on the following environments:

**Manually tested:**

- WSL2 (Ubuntu 24.04 LTS)
- Debian 12 (Bookworm)
- Debian 13 (Trixie)

**Not yet tested:**

- Alpine Linux (musl)
- Fedora, CentOS, RHEL
- NixOS
- Other glibc-based distributions

These platforms are expected to work based on POSIX compatibility, but they have not been validated yet.

## Usage

### Interactive

Run the installed script (or the one-liner) and follow the prompts. The installer will guide you through the process.

### Non-interactive Usage

For automation or CI environments, use the `--assume-yes` flag to skip prompts:

```sh
./letsgolang.sh --assume-yes
```

### CLI Options

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

## Updating Go

To update Go, simply run the installation command again. `letsgolang` will detect the new version (if available upstream), verify it, and replace the existing installation in `$HOME/.local/opt/go`. Your `GOPATH` and projects remain untouched.

## Uninstallation

To uninstall Go, run the script with the `--uninstall` (or `-u`) flag:

```sh
./src/letsgolang.sh --uninstall
```

Or using the remote one-liner:

```sh
curl --proto '=https' --tlsv1.2 -sSLf https://github.com/jcsxdev/letsgolang/releases/latest/download/letsgolang.sh | sh -s -- --uninstall
```

This command will:

1. Remove the Go installation directory (`$HOME/.local/opt/go`).
2. Check your shell configuration file for Go-related environment variables and advise you if manual cleanup is needed.

## Installation Details

- **Location**: Go is installed into `$HOME/.local/opt/go`.
- **Symlinks**: The installer manages `GOROOT` and `PATH` settings.
- **Shell Config**: It automatically updates your shell profile (e.g., `.bashrc`, `.zshrc`, `config.fish`, or `.profile`) to include:
  ```sh
  export GOROOT="$HOME/.local/opt/go"
  export PATH="$GOROOT/bin:$HOME/go/bin:$PATH"
  ```

## Security Model

Go is distributed via HTTPS from `https://go.dev/dl/`. The Go project publishes **checksums (currently only SHA‑256)** on that page. There are **no official GPG signatures**, **no transparency log**, and **no independent authenticated checksum channel**.

Although some `.asc` files exist on the Go download servers and contain valid PGP signatures — for example:

https://go.dev/dl/go1.25.5.linux-amd64.tar.gz.asc

```
$ file ~/Downloads/go1.25.5.linux-amd64.tar.gz.asc
/home/user/Downloads/go1.25.5.linux-amd64.tar.gz.asc: PGP signature Signature (old)
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

- **Cross-checking SHA‑256 against independent sources**
  _Concept_: Verify the hash against Repology, Homebrew, or distro packaging metadata.
  _Trade-off_: Increases assurance but adds **latency and fragility**. Third‑party ecosystems often lag hours or days behind `go.dev`, which can cause false failures right after a new Go release.

- **Certificate pinning**
  _Concept_: Hardcode the TLS certificate (or fingerprint) for `go.dev` to reduce the impact of some MITM attacks.
  _Trade-off_: High **operational maintenance cost**. When Google rotates certificates (which happens regularly), the installer may break until `letsgolang` is updated.

- **Trust‑on‑First‑Use (TOFU)**
  _Concept_: Store the verified checksum locally on first run and warn if future downloads of the same version differ.
  _Trade-off_: Great for detecting tampering over time, but offers **no protection for the very first installation**, which still relies on the upstream infrastructure.

- **Heuristic validation**
  _Concept_: Inspect the tarball structure (e.g., existence of `go/bin/go`, `go/src`, etc.) before or after extraction.
  _Trade-off_: Helps catch obviously corrupted or malformed archives, but provides **no cryptographic guarantee** against targeted binary modification.

### What `letsgolang` cannot do (limitations of Go’s distribution model)

- **GPG verification**: No official signed release artifacts or public keys are provided by the Go project.
- **Transparency logs**: There is no official log (like Sigstore/Rekor) of artifacts to verify against.
- **Independent authenticated checksum channel**: Checksums are only available on the same site that serves the binaries, over the same HTTPS connection.
- **Dedicated, authenticated metadata API**: All metadata is scraped from the HTML of the download page.

`letsgolang` cannot provide cryptographic guarantees stronger than those offered by Go’s own distribution model. This is a limitation of Go’s current distribution model, not a design choice made by `letsgolang`. It focuses on enforcing HTTPS, verifying the downloaded file’s SHA‑256 against the official checksum, and failing fast when something doesn’t match expectations.

## Design Goals

- **Minimalism**: Do one thing well—install Go.
- **Predictability**: The script should behave exactly the same way on a fresh container as it does on a developer's workstation.
- **Auditability**: Security-conscious users should be able to understand the structure and trust boundaries in minutes.
- **Fail-Fast**: If a checksum fails or a dependency is missing, stop immediately.

## Non-Goals

- **Multi-version Management**: This tool installs the _latest_ stable Go version. For switching between multiple versions, consider tools like `asdf` or `gvm`.
- **macOS/Windows Support**: Focused strictly on Linux/POSIX environments.
- **Plugin Ecosystem**: No plugins, no extensions.
- **GPG Verification**: We do not enforce GPG because the Go project does not officially support it for releases.

## Requirements

To run the installer, your system needs standard POSIX tools:

- A standard `/bin/sh` implementation
- `curl` or `wget` (for downloading)
- `tar` (for extraction)
- `sha256sum` or `shasum` (for verification)
- `awk`, `sed`, and `grep` (for text processing)

## Troubleshooting

- **Command not found**: If `go` is not found after installation, try reloading your shell configuration:
  ```sh
  source ~/.bashrc  # or ~/.zshrc, ~/.profile, etc.
  ```
- **Permission denied**: Ensure the script is executable (`chmod +x src/letsgolang.sh`).
- **Checksum mismatch**: This indicates a corrupted download or a security issue. The installer will abort automatically to protect your system.

## FAQ

**Why not just extract the Go tarball manually?**\
Manual installation works, but it is repetitive and error‑prone across machines. `letsgolang` automates verification, cleanup, and environment configuration in a predictable, auditable way.

**Why not use asdf, mise, or gvm?**\
Those tools are excellent for multi‑version workflows. `letsgolang` intentionally focuses on a single task: installing the latest stable Go with zero dependencies.

**Why no GPG verification?**\
The Go project does not officially publish signed release artifacts or document a supported GPG verification process. See the Security Model section for details.

**Does it work on Alpine, NixOS, or other distros?**\
These platforms are expected to work based on POSIX compatibility, but they have not been tested yet. See the “Tested Environments” section for details.

## Development

To contribute to `letsgolang`, clone the repository:

```sh
git clone https://github.com/jcsxdev/letsgolang
cd letsgolang
./src/letsgolang.sh # Run from source
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for more details.

## Documentation

- [Building and Installation](BUILDING.md)
- [Contributing Guidelines](CONTRIBUTING.md)

## License

This project is licensed under either of:

- [Apache License, Version 2.0](LICENSE-APACHE)
- [MIT license](LICENSE-MIT)

at your option.
