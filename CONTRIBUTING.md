# Contributing to letsgolang

Thank you for your interest in improving `letsgolang`. We value POSIX compliance, robustness, and clarity.

## Code Standards

- **POSIX Compliance**: All scripts must remain POSIX-compliant. Avoid non-standard extensions (bashisms).
- **ShellCheck**: All changes must pass ShellCheck validation.
- **Formatting**: We use `shfmt` for code formatting. The standard configuration is:
  - Indent: 2 spaces
  - Switch cases indentation: yes
  - Binary operators at start of line: yes
- **Naming**: Local variables should be prefixed with an underscore (e.g., `local _var`).

## Development Workflow

1. **Tests**: Ensure that any new functionality or bug fix is accompanied by corresponding unit tests in the `test/` directory.
2. **Verification**: Run `make test` and `make check` before submitting any changes.
3. **Commit Messages**: We follow [Conventional Commits](https://www.conventionalcommits.org/).
   - `feat:` for new features.
   - `fix:` for bug fixes.
   - `docs:` for documentation changes.
   - `refactor:` for code changes that neither fix a bug nor add a feature.

## Technical Documentation

Every function must have a professional header comment describing:

- Its purpose.
- Its arguments (if any).
- Its output (stdout/stderr).
- Its return value (exit status).
