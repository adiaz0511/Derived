# Contributing to Derived

## Development setup

1. Use macOS 26.4 or later and Xcode 26.4 or later.
2. Clone the repository and open `Derived.xcodeproj`.
3. Build the `Derived` scheme.
4. Run the complete test suite before submitting a change.

## Change requirements

- Keep scanner, validation, deletion, and presentation responsibilities in separate files.
- Add tests for changes to approved paths, automatic selection, process checks, simulator commands, or deletion scopes.
- Do not broaden filesystem access without documenting the new path in `docs/SAFETY.md`.
- Do not follow symbolic links while calculating sizes or deleting targets.
- Do not remove confirmation requirements for permanent deletion.
- Do not add analytics, telemetry, or network access without prior discussion.
- Preserve the rule that Archives and Simulator Runtimes are never selected automatically.

## Pull requests

Use a focused branch and describe:

- What changed
- Why the change is needed
- Which safety behavior is affected
- Which build or test command was run

User-interface changes should include a screenshot when practical. Changes that delete or select additional data must include tests and explicit safety justification.
