---
name: derived-cleanup
description: Inspect and permanently clean Xcode, Simulator, and XCTest storage through Derived's MCP tools or CLI. Use when a user names Derived, links the Derived app, asks to find developer storage, identify reclaimable Xcode data, inspect cleanup candidates, or delete selected candidates or categories. Prefer MCP and CLI access over the Derived macOS UI or Computer Use.
---

# Derived Cleanup

## Select the interface

Use these interfaces in order:

1. Use Derived MCP tools when they are available.
2. Otherwise, use the `derived` CLI with `--json` for structured results.
3. Use the Derived macOS UI only when the user explicitly requests UI interaction or neither programmatic interface is available.

Treat a Derived app link, including a `plugin://computer-use` link for `mx.devlabs.Derived`, as identification of the app. Do not treat the link as a requirement to use Computer Use. Before loading Computer Use, search for Derived MCP tools and the `derived` executable.

Do not construct cleanup paths or run manual filesystem deletion commands. Both programmatic interfaces use the same scanner and cleanup validation as the app.

## Inspect storage

1. Run `scan` before making recommendations.
2. Summarize category counts and verified reclaimable bytes.
3. Report XCTest logical bytes separately. Do not describe logical clone sizes as verified space savings.
4. Run `list_candidates` only for categories the user wants to inspect.
5. Follow `nextOffset` until enough information is available. Do not request more than 50 rows at once.

## Prepare cleanup

1. Resolve the user's selection to candidate IDs or complete categories from the current scan.
2. Run `prepare_cleanup`.
3. Present its item count, categories, verified reclaimable bytes, logical bytes, and high-risk status.
4. Ask the user for explicit confirmation using the returned confirmation phrase.

Do not interpret a request to inspect, scan, recommend, or preview as permission to delete.

## Execute cleanup

1. Run `execute_cleanup` only after the user explicitly approves the prepared plan.
2. Pass the exact `plan_id` and `confirmation_phrase` returned by `prepare_cleanup`.
3. Report removed, blocked, and failed items separately.
4. Run a new scan when a scan or plan is missing, expired, or stale.

Never bypass warnings for active development tools, pinned runtimes, newest runtimes, archives, or other high-risk candidates.

Read [references/tools.md](references/tools.md) when exact MCP inputs, CLI commands, categories, or error recovery are needed.
