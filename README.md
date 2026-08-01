# Derived

Derived is a native macOS menu-bar application for inspecting and removing storage created by Xcode, Simulator, and XCTest.

> [!WARNING]
> Derived is under active development. Cleanup is permanent and does not move files to the Trash. Review the selected category and confirmation message before deleting data.

## Features

- Reports Mac storage usage and reclaimable developer data.
- Groups cleanup candidates by Derived Data, previews, XCTest devices, simulators, runtimes, Device Support, logs, caches, archives, and temporary data.
- Supports category-specific and cross-category selection.
- Uses `simctl` for simulator device and runtime removal.
- Protects active targets and checks for running development tools.
- Supports scheduled cleanup for Derived Data, Xcode logs, and Xcode caches.
- Supports Launch at Login through the native macOS login-item service.
- Keeps a local JSON Lines cleanup history.

## Safety model

Derived validates every filesystem target against a fixed allowlist immediately before deletion. It rejects category roots, targets outside approved developer directories, malformed simulator identifiers, active targets, and symbolic-link escapes. Automatic cleanup waits until related development tools are closed and fails safely when process inspection is unavailable.

Archives and simulator runtimes are never selected automatically. XCTest APFS clone sizes are reported as logical sizes and are excluded from verified reclaimable totals.

See [Safety](docs/SAFETY.md) for the complete deletion model and approved paths.

## Requirements

- macOS 26.4 or later
- Xcode 26.4 or later

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

Launch at Login requires a signed application installed in a stable location. It may not work from an unsigned development build.

## Project structure

- `Derived/App`: application lifecycle, menu-bar item, and panel management
- `Derived/Features`: SwiftUI presentation grouped by feature
- `Derived/Models`: cleanup, scan, automation, and reporting models
- `Derived/Services`: scanning, validation, process inspection, deletion, and persistence
- `Derived/Shared`: shared formatting and design constants
- `DerivedTests`: safety and behavior tests

## Privacy

Derived operates locally. It does not include analytics, advertising, accounts, or network services. See [Privacy](PRIVACY.md).

## Contributing

Contributions are welcome after the repository becomes public. Read [Contributing](CONTRIBUTING.md) before changing scanner, validation, or deletion behavior.

## License

Derived is available under the [MIT License](LICENSE).
