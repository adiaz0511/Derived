# Agent Integrations

Derived provides two native command-line products from the repository's Swift package:

- `derived`: human-readable and JSON command-line access.
- `derived-mcp`: a local Model Context Protocol server using standard input and output.

Both products use the same scanner, validation, and cleanup coordinator as the macOS application. The MCP server does not accept arbitrary paths.

The current agent-tools version is `1.0.4`. The CLI reports it through `derived --version`, and the MCP server reports the same value in its initialization handshake.

## Install with Homebrew

Homebrew installs the agent tools independently from the Derived application:

```sh
brew tap adiaz0511/derived
brew install --cask derived-tools
derived integrations install
```

The integration command detects Codex, Claude Code, and Cursor. It installs the portable skill and registers the Homebrew-managed `derived-mcp` executable. Configure one client explicitly when required:

```sh
derived integrations install --client codex
derived integrations install --client claude
derived integrations install --client cursor
```

Inspect or update the installation with:

```sh
derived integrations status
derived integrations update
```

`derived integrations update` runs the Homebrew upgrade and refreshes detected client configurations. The CLI also checks for a newer release at most once per day during interactive commands. Set `DERIVED_NO_UPDATE_CHECK=1` to disable this advisory check. JSON output and MCP responses never contain update notices.

Derived can update DMG-installed tools in `~/.local/bin` when the application is also installed. The app never overwrites Homebrew-managed or development installations. Without the app, download the latest DMG and run **Derived Agent Tools** again.

## Install from the disk image

The public disk image contains the signed application and precompiled agent tools. Swift and Xcode are not required for installation.

First, install the application:

1. Download `Derived.dmg` from the [latest GitHub release](https://github.com/adiaz0511/Derived/releases/latest).
2. Open the disk image.
3. Drag `Derived.app` to the Applications folder.
4. Open Derived from Applications.

### Codex: recommended installation

The recommended installer performs four user-scoped actions:

1. It installs `derived` and `derived-mcp` in `~/.local/bin`.
2. It installs the `derived-cleanup` skill in `~/.codex/skills/derived-cleanup`.
3. It registers `~/.local/bin/derived-mcp` as the `derived` MCP server.
4. It reports the installed version and verification commands.

To install:

1. Open `Derived.dmg`.
2. Open **Derived Agent Tools**.
3. Select **Install for Codex**.
4. Wait for the green completion indicator, then select **Close**.
5. Restart Codex.
6. Run the verification commands:

```sh
"$HOME/.local/bin/derived" --version
codex mcp get derived
```

Then test the workflow with this request:

```text
Use $derived-cleanup to scan my developer storage.
```

The installer application is signed and notarized as part of the release disk image. It does not require administrator access. It replaces only the existing Derived MCP registration and `derived-cleanup` skill.

### Codex: manual installation

Keep `Derived.dmg` mounted. Then run:

```sh
mkdir -p "$HOME/.local/bin" "$HOME/.codex/skills"
install -m 755 "/Volumes/Derived/.agent-tools/bin/derived" "$HOME/.local/bin/derived"
install -m 755 "/Volumes/Derived/.agent-tools/bin/derived-mcp" "$HOME/.local/bin/derived-mcp"
rm -rf "$HOME/.codex/skills/derived-cleanup"
ditto "/Volumes/Derived/.agent-tools/Integrations/derived-cleanup" \
  "$HOME/.codex/skills/derived-cleanup"
codex mcp remove derived 2>/dev/null || true
codex mcp add derived -- "$HOME/.local/bin/derived-mcp"
```

Restart Codex and run the same verification commands shown above.

## Uninstall from Codex

The easiest method is to open `Derived.dmg`, open **Derived Agent Tools**, and select **Remove**.

For manual removal, run:

```sh
codex mcp remove derived 2>/dev/null || true
rm -f "$HOME/.local/bin/derived" "$HOME/.local/bin/derived-mcp"
rm -rf "$HOME/.codex/skills/derived-cleanup"
```

These steps do not remove `Derived.app`, application preferences, scan history, or cleanup history. Remove the application from the Applications folder separately if it is no longer required.

## Build from source

```sh
swift build -c release
```

The executables are written to `.build/release/derived` and `.build/release/derived-mcp`.

Create a distributable archive containing both binaries, the portable skill, the license, and this guide:

```sh
scripts/package-agent-tools.sh
```

The packaging script derives the archive version from `derived --version`. An optional version argument validates an expected version and fails if it does not match the binary:

```sh
scripts/package-agent-tools.sh 1.0.4
```

## Command-line workflow

Use the default output for interactive terminal work. Scan and candidate commands render aligned ASCII tables, and scan output includes a totals row.

```sh
derived --version
derived scan
derived list --scan <scan-id> --category derivedData --limit 20
derived prepare --scan <scan-id> --category previewData
```

Interactive `prepare` output explains the confirmation phrase and prints the complete `derived delete` command for that plan. Review the plan before running the printed command.

Use `--json` for scripts and agents:

```sh
derived scan --json
derived list --scan <scan-id> --category derivedData --limit 20 --json
derived prepare --scan <scan-id> --item <candidate-id> --json
derived delete --plan <plan-id> --confirm "<exact phrase>" --json
```

Scan identifiers expire after 30 minutes. Cleanup plans expire after 10 minutes and can be executed once. Deletion is permanent.

## Codex development installation

From the repository, first build the release CLI and MCP server:

```sh
swift build -c release
```

Then install both executables and the skill, and replace the existing Codex MCP registration:

```sh
scripts/install-codex-agent-tools.sh
```

The script uses the precompiled products in `.build/release`. It installs `derived` and `derived-mcp` in `~/.local/bin`, installs the skill in `~/.codex/skills/derived-cleanup`, and registers the installed MCP executable as `derived`.

Verify the installation with:

```sh
derived --version
codex mcp get derived
```

To register an already installed server manually, run:

```sh
codex mcp add derived -- "$HOME/.local/bin/derived-mcp"
```

Copy `Integrations/derived-cleanup` to `~/.codex/skills/derived-cleanup` to install the optional workflow skill.

Agents should use the Derived MCP tools first. If the MCP server is unavailable, they should use the `derived` CLI with `--json`. They should use the macOS interface only when the user explicitly requests UI interaction or neither programmatic interface is available. A Derived app link identifies the application but does not require Computer Use.

## Claude Code

First, install the precompiled executables from the mounted disk image:

```sh
mkdir -p "$HOME/.local/bin"
install -m 755 "/Volumes/Derived/.agent-tools/bin/derived" "$HOME/.local/bin/derived"
install -m 755 "/Volumes/Derived/.agent-tools/bin/derived-mcp" "$HOME/.local/bin/derived-mcp"
```

Add the server for the current user:

```sh
claude mcp add derived --scope user -- "$HOME/.local/bin/derived-mcp"
```

Copy the optional workflow skill from the mounted image:

```sh
mkdir -p "$HOME/.claude/skills"
rm -rf "$HOME/.claude/skills/derived-cleanup"
ditto "/Volumes/Derived/.agent-tools/Integrations/derived-cleanup" \
  "$HOME/.claude/skills/derived-cleanup"
```

Verify the server with `claude mcp get derived`.

## Cursor

First, copy `derived-mcp` from the mounted disk image to `~/.local/bin` as shown in the Claude Code section.

Add the server to `~/.cursor/mcp.json`:

```json
{
  "mcpServers": {
    "derived": {
      "command": "/Users/your-name/.local/bin/derived-mcp",
      "args": []
    }
  }
}
```

Copy `/Volumes/Derived/.agent-tools/Integrations/derived-cleanup` to `~/.cursor/skills/derived-cleanup` to install the optional workflow skill. Restart Cursor, open its MCP settings, and confirm that `derived` is connected.

## Interaction model

First, the agent calls `scan`. Then it requests candidate pages only when needed. Next, it calls `prepare_cleanup` for the user's exact selection. Finally, it presents the returned plan and waits for explicit confirmation before calling `execute_cleanup`.

Client-specific rich interfaces are optional. The portable workflow uses structured tool results and conversational confirmation so it behaves consistently in Codex, Claude, and Cursor.
