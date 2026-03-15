# Security Policy

## Supported Versions

We release security updates for the latest stable version only. Please ensure you're running the most recent version before reporting issues.

| Version | Supported          |
| ------- | ------------------ |
| 2.4.x   | :white_check_mark: |
| < 2.4   | :x:                |

[Download the latest version](https://github.com/kynoptic/claude-usage-tracker/releases/latest)

## Reporting a Vulnerability

We take security seriously. If you discover a security vulnerability, please report it responsibly.

### How to Report

**Please do NOT report security vulnerabilities through public GitHub issues.**

Instead, use GitHub's private security advisory feature:

1. Go to the [Security tab](https://github.com/kynoptic/claude-usage-tracker/security/advisories)
2. Click "Report a vulnerability"
3. Provide detailed information about the vulnerability

### What to Include

To help us assess and address the issue quickly, please include:

- **Type of vulnerability** (e.g., credential exposure, code injection, privilege escalation)
- **Step-by-step reproduction** instructions
- **Affected versions** (if known)
- **Potential impact** assessment
- **Proof of concept** code (if applicable)
- **Suggested fix** (if you have one)

### Response Timeline

- **Acknowledgment**: Within 24-48 hours
- **Initial assessment**: Within 1 week
- **Resolution timeline**: Depends on severity and complexity

We'll keep you informed throughout the process and credit you in the security advisory and release notes (unless you prefer to remain anonymous).

## Security Considerations

### Session Key Storage

- Session keys are stored in `UserDefaults` as part of the serialized `Profile` struct (see [ADR-003](docs/decisions/ADR-003-credentials-embedded-in-profile.md))
- `UserDefaults` is less secure than the macOS Keychain — credentials are readable by any process running as the same user
- Keys are never transmitted except to `claude.ai` via HTTPS
- No cloud sync or external storage

### Application Signing

- The app is currently **unsigned** (no Apple Developer certificate)
- macOS Gatekeeper will block the app on first launch
- Users must manually approve via System Settings → Privacy & Security
- **This is expected behavior** for community open-source apps

### Network Security

- All communication uses **HTTPS only**
- API requests are sent exclusively to `claude.ai` endpoints
- No telemetry, analytics, or third-party tracking
- Session authentication via secure cookies only

### Code Execution

- Claude Code integration scripts are installed to `~/.claude/`
- Script permissions are set to `755` (read/execute for all, write for owner)
- The statusline script (`~/.claude/fetch-claude-usage.swift`) contains the session key in plaintext, injected at install time (see [ADR-004](docs/decisions/ADR-004-statusline-session-key-injection.md))
- No arbitrary code execution from external sources

### Sandboxing

- App Sandbox is **disabled** to allow file system access
- Required for writing `~/.claude/` scripts and reading CLI OAuth credentials from the System Keychain
- Necessary trade-off for the app's core functionality

## Best Practices for Users

### Protect Your Session Key

- Never share your session key publicly
- Treat it like a password
- Rotate it if you suspect compromise (extract a fresh key from claude.ai)
- If the statusline is enabled, the session key is also stored in plaintext in `~/.claude/fetch-claude-usage.swift` — restrict read access to this file if you share your machine

### Verify Downloads

- Download only from the official source:
  - [GitHub Releases](https://github.com/kynoptic/claude-usage-tracker/releases) — the sole distribution channel for this fork
  - Note: the Homebrew cask workflow is disabled in this fork; no tap is configured or maintained
- Build from source if you prefer: `git clone` + Xcode build

### Keep Updated

- Security patches are released for the latest version only
- Enable notifications for new releases on GitHub
- Review the [CHANGELOG.md](CHANGELOG.md) for security-related updates

## Security Acknowledgments

We recognize and appreciate security researchers who help keep our community safe. Contributors who responsibly disclose vulnerabilities will be:

- Credited in the security advisory (with permission)
- Acknowledged in release notes
- Listed as security contributors in the project

Thank you for helping keep Claude Usage Tracker secure!

## Questions?

For non-security related issues, please use [GitHub Issues](https://github.com/kynoptic/claude-usage-tracker/issues).

For general questions, see our [Contributing Guide](CONTRIBUTING.md).
