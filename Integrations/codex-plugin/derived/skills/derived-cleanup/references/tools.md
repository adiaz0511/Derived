# Derived Tool Reference

## Interface priority

1. Prefer the Derived MCP tools.
2. Fall back to the `derived` CLI when MCP tools are unavailable.
3. Use the macOS UI only when explicitly requested or when neither programmatic interface is available.

Always request structured CLI output with `--json`. Do not parse the human-readable format when JSON output is available.

## Version and output modes

- Run `derived --version` to identify the installed CLI. Version `1.0.3` also appears in the MCP initialization handshake.
- Use `derived scan` and `derived list` only when a user explicitly wants human-readable terminal output. These commands render aligned ASCII tables; scan output includes totals.
- Interactive `derived prepare` output explains the confirmation phrase and prints the exact `derived delete` command for the prepared plan.
- Use `--json` for agent decisions, scripts, candidate identifiers, and cleanup plans.

## Categories

- `derivedData`
- `previewData`
- `xctestDevices`
- `unavailableSimulators`
- `redundantSimulators`
- `simulatorRuntimes`
- `deviceSupport`
- `logs`
- `caches`
- `archives`
- `temporaryData`

## Tools

### `scan`

Accept no arguments. Return an expiring `scanID`, category summaries, active development processes, and warnings.

### `list_candidates`

Provide:

- `scan_id`: UUID returned by `scan`.
- `category`: one category value.
- `offset`: zero-based page offset. Default to `0`.
- `limit`: page size from 1 through 50. Default to `20`.

Use `nextOffset` for another page. A missing value means the category is complete.

### `prepare_cleanup`

Provide:

- `scan_id`: UUID returned by `scan`.
- `item_ids`: exact candidate identifiers from that scan.
- `categories`: complete categories to include.

Candidate IDs and categories form a union. Use only the user's intended scope.

### `execute_cleanup`

Provide:

- `plan_id`: UUID returned by `prepare_cleanup`.
- `confirmation_phrase`: exact phrase returned by that plan.

This operation permanently deletes data. Plans are single-use and expire after ten minutes. Derived rescans and rejects changed candidates before deletion.

## CLI equivalents

Use the exact identifiers returned by earlier commands:

```sh
derived --version
derived scan --json
derived list --scan <scan-id> --category <category> --offset <offset> --limit <limit> --json
derived prepare --scan <scan-id> [--item <candidate-id>]... [--category <category>]... --json
derived delete --plan <plan-id> --confirm <exact-phrase> --json
```

Before using the CLI, resolve the executable with the shell. Do not build or install it unless the user requests that action.

## Error recovery

- Missing or expired scan: call `scan` again.
- Missing, expired, or stale plan: prepare a new plan and request confirmation again.
- Invalid confirmation: show the exact phrase and wait for explicit user approval.
- Active development tools: ask the user to close the named tools, then rescan.
- Blocked or failed items: report the result without attempting manual filesystem deletion.
