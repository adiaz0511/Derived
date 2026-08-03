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

Create the isolated release-packaging environment:

```sh
python3 -m venv .build/release-venv
.build/release-venv/bin/pip install -r requirements-release.txt
export DMGBUILD_BIN="$PWD/.build/release-venv/bin/dmgbuild"
```

The pinned `dmgbuild` dependency writes Finder metadata directly. This avoids the unreliable asynchronous `.DS_Store` updates produced by Finder on macOS Tahoe.

Create an unsigned universal DMG for layout and installation testing:

```sh
scripts/build-release-dmg.sh \
  --version 1.0.4 \
  --architectures universal \
  --unsigned
```

The command writes the DMG and checksum to `dist`. It also creates a matching universal MCPB package, MCPB checksum, and generated `dist/server.json`. Each checksum records only its artifact filename, so it can be verified from the download directory with `shasum -a 256 -c FILE.sha256`.

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
  --version 1.0.4 \
  --architectures universal \
  --sign-identity "Developer ID Application: YOUR NAME (TEAM_ID)" \
  --sparkle-private-key "/path/to/exported-sparkle-private-key" \
  --notary-profile derived-notary \
  --notarize
```

The script signs the application, CLI, MCP server, and DMG with hardened runtime and secure timestamps. It submits the DMG, waits for notarization, staples the application and DMG tickets, runs Gatekeeper assessment, and creates checksums. It also generates the signed Sparkle feed and app-only update ZIP. Delete the exported Sparkle private-key file after the build. The MCPB is built from the same signed universal MCP executable contained in the notarized DMG.

## GitHub release automation

Configure these GitHub Actions secrets:

- `DEVELOPER_ID_APPLICATION_P12_BASE64`
- `DEVELOPER_ID_APPLICATION_P12_PASSWORD`
- `APP_STORE_CONNECT_API_KEY_ID`
- `APP_STORE_CONNECT_API_ISSUER_ID`
- `APP_STORE_CONNECT_API_PRIVATE_KEY_BASE64`
- `SPARKLE_EDDSA_PRIVATE_KEY`
- `HOMEBREW_TAP_DEPLOY_KEY`

`SPARKLE_EDDSA_PRIVATE_KEY` contains the private EdDSA key exported by Sparkle's `generate_keys` tool. Keep the original in the release maintainer's Keychain. `HOMEBREW_TAP_DEPLOY_KEY` is a repository-scoped SSH deploy key with write access only to `adiaz0511/homebrew-derived`.

Run the Release workflow manually with its default unsigned setting before the first public release. Then create and push the release tag:

```sh
git tag v1.0.4
git push origin v1.0.4
```

The tag workflow publishes only the notarized DMG and MCPB as public GitHub Release assets. GitHub adds the source code ZIP and TAR.GZ archives automatically. The workflow continues generating and validating checksum files internally, but it does not publish those files as public Release assets.

After publication, the same workflow performs two distribution updates:

1. It creates an application ZIP, signs it with the Sparkle EdDSA key, and deploys the ZIP and `appcast.xml` through GitHub Pages. The application contains the signed Agent Tools payload used to update DMG-managed installations.
2. It updates the `derived` and `derived-tools` casks in `adiaz0511/homebrew-derived` with the release version and DMG checksum.
3. It publishes `tools-version.json` through GitHub Pages for the CLI's advisory update check.

The Sparkle feed, application ZIP, and tools version manifest are not public GitHub Release assets. The separate ZIP prevents the bundled Agent Tools installer from being treated as a second update application. The Homebrew casks reuse the published DMG, so Homebrew does not require a separate binary archive.

The generated `dist/server.json` is stored as a GitHub Actions workflow artifact named `Derived-VERSION-mcp-registry-metadata` on tagged releases. Download that workflow artifact from the tagged Release run before publishing to the MCP Registry. The manual validation workflow artifact continues to include the DMG, MCPB, checksums, and `server.json`.

## Publish MCP metadata

After the GitHub Release and MCPB URL are publicly accessible, download the `Derived-VERSION-mcp-registry-metadata` workflow artifact from the tagged Release run. Then authenticate with the official MCP Registry publisher and validate the downloaded metadata:

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
4. Open **Derived Agent Tools** from the DMG and select **Install for Codex**.
5. Restart Codex.
6. Run `"$HOME/.local/bin/derived" --version` and `codex mcp get derived`.
7. Ask Codex to use `$derived-cleanup` for a read-only scan.
8. Confirm the agent selects MCP before CLI or Computer Use.
