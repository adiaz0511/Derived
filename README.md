<div align="center">
  <img src="docs/assets/derived-app-icon.png" width="180" alt="Derived app icon">
      <h1>Derived</h1>
  <p>A native macOS menu-bar application for inspecting and removing storage created by Xcode, Simulator, and XCTest.</p>
  <p>
    <img src="https://img.shields.io/badge/macOS-14.0%2B-111827?logo=apple" alt="macOS 14.0 or later">
    <img src="https://img.shields.io/badge/Swift_Tools-6.2-F05138?logo=swift&logoColor=white" alt="Swift tools 6.2">
    <img src="https://img.shields.io/badge/CLI_%2B_MCP-1.0.0-0A84FF" alt="CLI and MCP version 1.0.0">
    <img src="https://img.shields.io/badge/License-MIT-30D158" alt="MIT License">
  </p>
</div>

> [!WARNING]
> Derived is under active development. Cleanup is permanent and does not move files to the Trash. Review the selected category and confirmation message before deleting data.

## Install

Derived is distributed as a notarized disk image so users do not need Xcode.

1. Download `Derived.dmg` from the [latest GitHub release](https://github.com/adiaz0511/Derived/releases/latest).
2. Open the disk image.
3. Drag `Derived.app` to the Applications folder.
4. Open Derived from Applications.

### Add Derived to Codex

The disk image includes the precompiled CLI, MCP server, and `derived-cleanup` skill.

1. Open `Derived.dmg`.
2. Open **Derived Agent Tools**.
3. Select **Install for Codex**.
4. Restart Codex.
5. Verify the installation:

```sh
"$HOME/.local/bin/derived" --version
codex mcp get derived
```

Then ask Codex:

```text
Use $derived-cleanup to scan my developer storage.
```

The notarized installer uses only locations owned by the current user. It does not request administrator access. Open the same application and select **Remove** to uninstall the agent tools. See [Agent Integrations](docs/AGENT_INTEGRATIONS.md) for manual installation, Claude Code, Cursor, and uninstall instructions.

## Features

- Reports Mac storage usage and reclaimable developer data.
- Groups cleanup candidates by Derived Data, previews, XCTest devices, simulators, runtimes, Device Support, logs, caches, archives, and temporary data.
- Supports category-specific and cross-category selection.
- Uses `simctl` for simulator device and runtime removal.
- Protects active targets and checks for running development tools.
- Supports scheduled cleanup for Derived Data, Xcode logs, and Xcode caches.
- Supports Launch at Login through the native macOS login-item service.
- Keeps a local JSON Lines cleanup history.
- Provides versioned native CLI and local MCP tools for Codex, Claude, Cursor, and other compatible agents.

## Agent tools

The current CLI and MCP agent-tools version is `1.0.0`. The CLI provides an aligned ASCII table for interactive use and structured JSON for scripts and agents.

```sh
derived --version
derived scan
derived scan --json
```

For repository development, build the release products, install the CLI and MCP server, install the portable Codex skill, and register the MCP server with:

```sh
scripts/install-codex-agent-tools.sh
```

See [Agent Integrations](docs/AGENT_INTEGRATIONS.md) for the complete CLI workflow, MCP configuration, packaging, safety rules, and skill installation instructions.

## Safety model

Derived validates every filesystem target against a fixed allowlist immediately before deletion. It rejects category roots, targets outside approved developer directories, malformed simulator identifiers, active targets, and symbolic-link escapes. Automatic cleanup waits until related development tools are closed and fails safely when process inspection is unavailable.

Archives and simulator runtimes are never selected automatically. XCTest APFS clone sizes are reported as logical sizes and are excluded from verified reclaimable totals.

See [Safety](docs/SAFETY.md) for the complete deletion model and approved paths.

## Requirements

- macOS 14.0 or later
- Xcode 26.4 or later

The DMG contains a prebuilt application, so users do not need to compile Derived in Xcode.

The application is intentionally not sandboxed because it manages files under `~/Library/Developer` and invokes `xcrun simctl`.

## Build

1. Clone the repository.
2. Open `Derived.xcodeproj` in Xcode.
3. Select the `Derived` scheme.
4. Build and run the macOS target.

Command-line build:

```sh
xcodebuild \
  -project Derived.xcodeproj \
  -scheme Derived \
  -configuration Debug \
  -derivedDataPath /tmp/DerivedBuild \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Command-line tests:

```sh
xcodebuild \
  -project Derived.xcodeproj \
  -scheme Derived \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/DerivedTests \
  CODE_SIGNING_ALLOWED=NO \
  test
```

Build and test the CLI and MCP server:

```sh
swift test
scripts/test-agent-protocol.sh
swift build -c release
```

Launch at Login requires a signed application installed in a stable location. It may not work from an unsigned development build.

## Project structure

- `Derived/App`: application lifecycle, menu-bar item, and panel management
- `Derived/Features`: SwiftUI presentation grouped by feature
- `Derived/Models`: cleanup, scan, automation, and reporting models
- `Derived/Services`: scanning, validation, process inspection, deletion, and persistence
- `Derived/Shared`: shared formatting and design constants
- `Derived/AgentIntegration`: shared CLI and MCP models, state, and safety workflow
- `DerivedTests`: safety and behavior tests
- `DerivedCLITests`: CLI argument, version, and human-readable output tests
- `DerivedCoreTests`: agent integration and destructive-operation safeguards
- `Tools`: native CLI and MCP executables
- `Integrations`: portable agent skill

## Privacy

Derived operates locally. It does not include analytics, advertising, accounts, or network services. See [Privacy](PRIVACY.md).

## Contributing

Contributions are welcome after the repository becomes public. Read [Contributing](CONTRIBUTING.md) before changing scanner, validation, or deletion behavior.

Maintainers should follow [Releasing Derived](docs/RELEASING.md) for signing, notarization, DMG generation, and MCP publication.

## License

Derived is available under the [MIT License](LICENSE).
