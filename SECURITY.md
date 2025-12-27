# Security Policy

## Supported Versions

We follow Semantic Versioning. Security updates are provided only for the latest stable release.

| Version | Supported          | Notes |
| ------- | ------------------ | ----- |
| Latest  | :white_check_mark: | Only the most recent minor/patch release is supported. |
| < Latest| :x:                | Please upgrade to the latest version. |

## Reporting a Vulnerability

We take the security of `letsgolang` seriously. If you discover a potential security vulnerability, please **DO NOT** open a public issue.

### How to Report (Private Reporting)

We utilize [GitHub's Private Vulnerability Reporting][github-reporting-docs] feature to manage security reports securely and privately. This is the only official channel for security reports.

1. Navigate to the **Security** tab of this repository.
2. In the left sidebar, under "Reporting", click **Advisories**.
3. Click **Report a vulnerability** to open the reporting form.

This initiates a private conversation with the maintainers, allowing us to collaborate on a fix before public disclosure.

### Response Commitment

As this project is maintained by a single person in their free time, please be aware that response times may vary compared to commercially backed projects.

- **Acknowledgment**: We aim to acknowledge your report within 48 hours.
- **Updates**: We will provide status updates as feasible (aiming for every 2 weeks) regarding verification and patch development.
- **Resolution**: Once a solution is implemented, a security advisory will be published along with an update to the changelog.

### Public Disclosure & CVEs

Once a fix is available, we will publish a security advisory. In cases of critical severity, we may request a **CVE ID** to ensure proper tracking.

Public disclosure will occur only after a fix has been released and users have had reasonable time to update, unless the vulnerability is already being actively exploited in the wild.

### Scope and Expectations

To avoid misunderstandings, please review our scope:

- **No Bug Bounties**: As an open-source project managed by volunteers, we **do not** offer financial rewards.
- **Out of Scope**: The following are generally considered out of scope unless they demonstrate a severe impact:
    - Spam or social engineering techniques.
    - Denial of Service (DoS) attacks.
    - Automated scan reports without a valid proof of concept (PoC).
    - Vulnerabilities in third-party libraries that do not affect the usage of `letsgolang`.

[github-reporting-docs]: https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing-information-about-vulnerabilities/privately-reporting-a-security-vulnerability
