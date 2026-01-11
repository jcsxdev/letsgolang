# Contributing to letsgolang

Thank you for your interest in improving `letsgolang`. We value POSIX orientation, robustness, and clarity.

## Code Standards

- **POSIX Orientation**: All scripts should target standard `/bin/sh` and prioritize portability across minimal environments. While we strive for POSIX compliance, we prioritize real-world portability and maintainability over strict formal compliance. Avoid non-standard extensions (bashisms) unless necessary and well-documented.
- **ShellCheck**: All changes must pass ShellCheck validation.
- **Formatting**: We use `shfmt` for code formatting. The standard configuration is:
  - Indent: 2 spaces
  - Switch cases indentation: yes
  - Binary operators at start of line: yes
- **Naming**: Local variables should be prefixed with an underscore (e.g., `local _var`).

## Development Workflow

1. **Prerequisites**: Ensure you have `just` installed, as it orchestrates our test and build commands.
2. **Tests**: Ensure that any new functionality or bug fix is accompanied by corresponding unit tests in the `test/` directory.
3. **Verification**: Run `just test` and `just check` before submitting any changes. If `just check` reports formatting issues, run `just fix` to automatically resolve them.
4. **Documentation**: If you change the script's behavior or arguments, please update `README.md` and `BUILDING.md` to prevent documentation drift.
5. **Commit Messages**: We follow [Conventional Commits](https://www.conventionalcommits.org/).
   - `feat:` for new features.
   - `fix:` for bug fixes.
   - `docs:` for documentation changes.
   - `refactor:` for code changes that neither fix a bug nor add a feature.

## Versioning and Release Workflow

This project uses a unique release workflow where the build artifacts embed both the semantic version and the specific commit hash of the release tag. This requires an inverted flow compared to conventional bump → commit → tag processes.

### Workflow

1. **Create Tag**: Manually create the release tag (e.g., `git tag v0.2.0`). This establishes the commit hash that will be embedded.
2. **Bump**: Run the bump script (`just bump-version`). It reads the latest tag and writes the version and the tag's commit hash into `src/letsgolang.sh`.
3. **Commit**: Commit the changes made by the bump script.
4. **Push**: Push both the commit and the tag (`git push && git push --tags`).

> **⚠️ WARNING!**
>
> Do not run the bump script before creating the tag. If you do, the script will embed the _previous_ release's hash or fail, resulting in incorrect metadata.

**Note**: The commit containing the bump changes is intentionally _not_ included in the tagged release itself. The tag points to the state of the code _before_ the version constants were updated in the source file, but the release artifacts (built from that state or utilizing the bump script during build) will reflect the correct version logic.

## Technical Documentation

Every function must have a professional header comment describing:

- Its purpose.
- Its arguments (if any).
- Its output (stdout/stderr).
- Its return value (exit status).
