# Security Policy

## Supported versions

Derived is currently in pre-release development. Security fixes are applied to the latest commit on the default branch.

## Reporting a vulnerability

Do not publish vulnerabilities involving path validation, command execution, symbolic links, or unintended deletion in a public issue.

Use GitHub's private vulnerability reporting feature from the repository Security tab. Include the affected version, reproduction steps, the expected result, the actual result, and any relevant target paths with personal information removed.

## Scope

Security-sensitive components include:

- Filesystem allowlist validation
- Symbolic-link handling
- `simctl` command construction
- Process inspection and automatic-cleanup safeguards
- Cleanup history storage
- Launch at Login registration
