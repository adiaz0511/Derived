# Releasing Derived

This process creates the public DMG, CLI and MCP payload, MCPB package, checksums, and MCP Registry metadata. Public releases require a Developer ID Application certificate and Apple notarization credentials.

## Validate locally

Run the complete validation suite:

```sh
swift test
scripts/test-agent-protocol.sh
scripts/test-agent-tools-install.sh
scripts/test-publication-metadata.sh
scripts/verify-app-regression.sh
```

Create an unsigned universal DMG for layout and installation testing:

```sh
scripts/build-release-dmg.sh \
  --version 0.2.0 \
  --architectures universal \
  --unsigned
```

The command writes the DMG and checksum to `dist`. It also creates a matching universal MCPB package, MCPB checksum, and generated `dist/server.json`.

## Configure signing

Install a Developer ID Application certificate in the login keychain. Then store App Store Connect API-key notarization credentials without adding them to the repository:

```sh
xcrun notarytool store-credentials derived-notary \
  --key "/path/to/AuthKey_KEY_ID.p8" \
  --key-id "YOUR_KEY_ID" \
  --issuer "YOUR_ISSUER_ID"
```

## Build and notarize

```sh
scripts/build-release-dmg.sh \
  --version 0.2.0 \
  --architectures universal \
  --sign-identity "Developer ID Application: YOUR NAME (TEAM_ID)" \
  --notary-profile derived-notary \
  --notarize
```

The script signs the application, CLI, MCP server, and DMG with hardened runtime and secure timestamps. It submits the DMG, waits for notarization, staples the ticket, runs Gatekeeper assessment, and creates checksums. The MCPB is built from the same signed universal MCP executable contained in the notarized DMG.

## GitHub release automation

Configure these GitHub Actions secrets:

- `DEVELOPER_ID_APPLICATION_P12_BASE64`
- `DEVELOPER_ID_APPLICATION_P12_PASSWORD`
- `APP_STORE_CONNECT_API_KEY_ID`
- `APP_STORE_CONNECT_API_ISSUER_ID`
- `APP_STORE_CONNECT_API_PRIVATE_KEY_BASE64`

Run the Release workflow manually with its default unsigned setting before the first public release. Then create and push the release tag:

```sh
git tag v0.2.0
git push origin v0.2.0
```

The tag workflow publishes the notarized DMG, MCPB, checksums, and generated MCP Registry metadata to a GitHub Release. It fails before publication when signing or notarization is unavailable.

## Publish MCP metadata

After the GitHub Release and MCPB URL are publicly accessible, authenticate with the official MCP Registry publisher. Then validate and publish the generated metadata:

```sh
cd dist
mcp-publisher validate server.json
mcp-publisher publish
```

Do not publish the repository `server.json` after signing. Final signing changes the MCPB checksum, so use the generated `dist/server.json` from the release build.

## Final clean-machine check

1. Download the DMG from the public GitHub Release.
2. Confirm Gatekeeper opens it without an override.
3. Drag Derived into Applications and launch it.
4. Run **Install Derived Agent Tools** from the DMG.
5. Restart Codex.
6. Run `"$HOME/.local/bin/derived" --version` and `codex mcp get derived`.
7. Ask Codex to use `$derived-cleanup` for a read-only scan.
8. Confirm the agent selects MCP before CLI or Computer Use.
