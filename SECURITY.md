# Security Policy

## Reporting Security Issues

Please do not open public issues for security-sensitive reports.

Send reports through GitHub private vulnerability reporting when available, or contact the maintainer privately. Include:

- affected TokenShed version or commit
- macOS version
- steps to reproduce
- expected and actual behavior
- any relevant logs with secrets removed

## Security Model

TokenShed is a local macOS tool. Its security goals are:

- reduce noisy logs before they are sent to coding agents
- redact common secrets before summarized output leaves the machine
- avoid telemetry and hosted TokenShed services
- keep agent integration explicit and user-controlled

## Sensitive Data

TokenShed may process logs that contain secrets. The redactor catches common token and assignment patterns, but it is not a complete data-loss-prevention system. Users should still avoid feeding highly sensitive logs into any toolchain that later sends output to remote coding agents.

## Supported Versions

Security fixes target the latest public release.
