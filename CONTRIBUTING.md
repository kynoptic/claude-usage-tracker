# Contributing to Claude Usage Tracker

Thank you for considering contributing to Claude Usage Tracker! This document covers contribution philosophy, getting started, and issue/PR etiquette. Development conventions (code style, architecture, commits, branches) are in [`CLAUDE.md`](CLAUDE.md) — the single source of truth for working in this codebase.

We welcome contributions of all kinds: bug reports, feature requests, documentation improvements, and code contributions.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [Development Setup](#development-setup)
  - [Project Structure](#project-structure)
- [How to Contribute](#how-to-contribute)
  - [Reporting Bugs](#reporting-bugs)
  - [Suggesting Features](#suggesting-features)
  - [Contributing Code](#contributing-code)
- [Pull Request Process](#pull-request-process)
- [Release Process](#release-process)
- [Getting Help](#getting-help)

## Code of Conduct

This project adheres to a code of conduct that all contributors are expected to follow. Please be respectful, inclusive, and considerate in all interactions.

**Our Standards:**
- Be welcoming and inclusive
- Be respectful of differing viewpoints
- Accept constructive criticism gracefully
- Focus on what's best for the community
- Show empathy towards other community members

## Getting Started

### Prerequisites

Before you begin, ensure you have the following installed:

- **macOS 14.0+** (Sonoma or later)
- **Xcode 16+** (required; CI uses Xcode 16 on macOS 15 — the minimum is enforced by the `PBXFileSystemSynchronizedRootGroup` project format introduced in Xcode 16)
- **Git** for version control
- **A Claude AI account** for testing (to obtain a session key)

### Development Setup

1. **Fork the repository**

   Click the "Fork" button on GitHub to create your own copy.

2. **Clone your fork**
   ```bash
   git clone https://github.com/YOUR_USERNAME/Claude-Usage-Tracker.git
   cd Claude-Usage-Tracker
   ```

3. **Open in Xcode**
   ```bash
   open "Claude Usage.xcodeproj"
   ```

4. **Build and run**
   - Select the "Claude Usage" scheme
   - Press `⌘R` to build and run
   - The app will appear in your menu bar

5. **Configure for testing**
   - Extract your session key from claude.ai (see README for instructions)
   - The app will guide you through setup on first launch

### Project Structure

```
Claude Usage/
├── App/
│   ├── AppDelegate.swift           # App lifecycle, notifications setup
│   └── ClaudeUsageTrackerApp.swift # SwiftUI app entry point
│
├── MenuBar/
│   ├── IconRendering/              # Menu bar icon renderers
│   ├── Popover/                    # Popover UI components
│   ├── MenuBarManager.swift        # Status item, popover management
│   └── (supporting files)
│
├── Views/
│   ├── Settings/
│   │   ├── App/                    # App-level settings views
│   │   ├── Components/             # Shared settings UI components
│   │   ├── Credentials/            # API key / credential views
│   │   ├── DesignSystem/           # Settings design tokens
│   │   └── Profile/                # Profile management views
│   ├── SetupWizard/                # First-run wizard steps
│   ├── SettingsView.swift          # Settings window with tabs
│   └── SetupWizardView.swift       # First-run configuration entry
│
├── Shared/
│   ├── Components/                 # Reusable SwiftUI components
│   ├── ErrorHandling/              # Error types and presentation
│   ├── Extensions/                 # Date, UserDefaults, etc.
│   ├── Localization/               # Language manager, strings
│   ├── Models/                     # Pure Swift data structs
│   ├── Patterns/                   # Singleton base pattern
│   ├── Protocols/                  # Service and storage protocols
│   ├── Services/                   # API, notifications, sync
│   ├── Storage/                    # UserDefaults wrappers
│   └── Utilities/                  # Constants, formatters, helpers
│
├── Assets.xcassets/                # Images, colors, icons
└── Resources/
    ├── Info.plist                  # App configuration
    └── (*.lproj)                   # Localization string files
```

## How to Contribute

### Reporting Bugs

Before submitting a bug report:
1. Check existing [issues](https://github.com/kynoptic/claude-usage-tracker/issues) to avoid duplicates
2. Ensure you're running the latest version

**When reporting a bug, include:**
- macOS version (e.g., macOS 14.2)
- App version (found in Settings → About)
- Steps to reproduce the issue
- Expected behavior vs. actual behavior
- Screenshots if applicable
- Relevant Console.app logs (filter by "Claude Usage")

### Suggesting Features

We love feature suggestions! Please:
1. Check existing issues first
2. Describe the problem your feature would solve
3. Explain your proposed solution
4. Consider alternative approaches

### Contributing Code

1. **Find or create an issue** for what you want to work on
2. **Comment on the issue** to let others know you're working on it
3. **Fork and create a branch** following the branch naming conventions in [`CLAUDE.md`](CLAUDE.md)
4. **Make your changes** following the code style and architecture guidelines in [`CLAUDE.md`](CLAUDE.md)
5. **Test thoroughly** on macOS 14.0+
6. **Submit a pull request**

## Pull Request Process

1. **Keep your branch up to date**
   ```bash
   git fetch origin
   git rebase origin/main
   ```

2. **Open a Pull Request**
   - Use a clear, descriptive title following the [Conventional Commits](https://www.conventionalcommits.org/) format
   - Reference any related issues (`Closes #123`)
   - Describe what changed and why
   - Include screenshots for UI changes
   - List any breaking changes

3. **Code Review**
   - Respond to feedback promptly
   - Make requested changes
   - Keep the PR focused — one feature/fix per PR

**PR Checklist:**

- [ ] Code follows project style guidelines in [`CLAUDE.md`](CLAUDE.md)
- [ ] Self-reviewed my own code
- [ ] Added comments for complex logic
- [ ] Updated documentation if needed
- [ ] Tested on macOS 14.0+
- [ ] No new warnings in Xcode
- [ ] UI changes include screenshots

## Release Process

See [`docs/procedures/DEPLOY.md`](docs/procedures/DEPLOY.md) for the complete release procedure, including version bumping, changelog updates, tagging, and GitHub Actions workflow details.

## Getting Help

- **Questions?** Open an [Issue](https://github.com/kynoptic/claude-usage-tracker/issues)
- **Found a bug?** Open an [Issue](https://github.com/kynoptic/claude-usage-tracker/issues)
- **Want to chat?** Reach out to maintainers

---

## Recognition

Contributors are recognized in:
- The GitHub contributors graph
- Release notes for significant contributions
- README acknowledgments for major features

Thank you for helping make Claude Usage Tracker better!
