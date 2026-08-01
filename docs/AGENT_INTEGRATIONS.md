# Agent Integrations

Derived provides two native command-line products from the repository's Swift package:

- `derived`: human-readable and JSON command-line access.
- `derived-mcp`: a local Model Context Protocol server using standard input and output.

Both products use the same scanner, validation, and cleanup coordinator as the macOS application. The MCP server does not accept arbitrary paths.

The current agent-tools version is `0.2.0`. The CLI reports it through `derived --version`, and the MCP server reports the same value in its initialization handshake.

## Build

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
scripts/package-agent-tools.sh 0.2.0
```

## Command-line workflow

Use the default output for interactive terminal work. Scan and candidate commands render aligned ASCII tables, and scan output includes a totals row.

```sh
derived --version
derived scan
derived list --scan <scan-id> --category derivedData --limit 20
```

Use `--json` for scripts and agents:

```sh
derived scan --json
derived list --scan <scan-id> --category derivedData --limit 20 --json
derived prepare --scan <scan-id> --item <candidate-id> --json
derived delete --plan <plan-id> --confirm "<exact phrase>" --json
```

Scan identifiers expire after 30 minutes. Cleanup plans expire after 10 minutes and can be executed once. Deletion is permanent.

## Codex

From the repository, build and install the release CLI, MCP server, and skill, then replace the existing Codex MCP registration:

```sh
scripts/install-codex-agent-tools.sh
```

The script installs `derived` and `derived-mcp` in `~/.local/bin`, installs the skill in `~/.codex/skills/derived-cleanup`, and registers the installed MCP executable as `derived`.

Verify the installation with:

```sh
derived --version
codex mcp get derived
```

To configure the components manually, add the local server:

```sh
codex mcp add derived -- "$HOME/.local/bin/derived-mcp"
```

Copy `Integrations/derived-cleanup` to `~/.codex/skills/derived-cleanup` to install the optional workflow skill.

Agents should use the Derived MCP tools first. If the MCP server is unavailable, they should use the `derived` CLI with `--json`. They should use the macOS interface only when the user explicitly requests UI interaction or neither programmatic interface is available. A Derived app link identifies the application but does not require Computer Use.

## Claude Code

Add the server for the current user:

```sh
claude mcp add derived --scope user -- /absolute/path/to/derived-mcp
```

Copy `Integrations/derived-cleanup` to `~/.claude/skills/derived-cleanup` to install the optional workflow skill.

## Cursor

Add the server to `~/.cursor/mcp.json`:

```json
{
  "mcpServers": {
    "derived": {
      "command": "/absolute/path/to/derived-mcp",
      "args": []
    }
  }
}
```

Copy `Integrations/derived-cleanup` to `~/.cursor/skills/derived-cleanup` to install the optional workflow skill.

## Interaction model

First, the agent calls `scan`. Then it requests candidate pages only when needed. Next, it calls `prepare_cleanup` for the user's exact selection. Finally, it presents the returned plan and waits for explicit confirmation before calling `execute_cleanup`.

Client-specific rich interfaces are optional. The portable workflow uses structured tool results and conversational confirmation so it behaves consistently in Codex, Claude, and Cursor.
