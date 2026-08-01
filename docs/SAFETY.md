# Safety Model

Derived permanently deletes files and simulator resources. The application therefore treats discovery, selection, validation, and deletion as separate operations.

## Approved filesystem roots

Filesystem deletion is restricted to descendants of these locations:

- `~/Library/Developer/Xcode/DerivedData`
- `~/Library/Developer/Xcode/Archives`
- `~/Library/Developer/Xcode/iOS DeviceSupport`
- `~/Library/Developer/Xcode/watchOS DeviceSupport`
- `~/Library/Developer/Xcode/UserData/Previews`
- `~/Library/Developer/Xcode/UserData/IB Support`
- `~/Library/Developer/CoreSimulator/Devices`
- `~/Library/Developer/CoreSimulator/Caches`
- `~/Library/Developer/XCTestDevices`
- `~/Library/Caches/com.apple.dt.Xcode`
- `~/Library/Logs/CoreSimulator`
- `~/Library/Logs/DiagnosticReports`

The validator resolves and standardizes paths before comparison. It rejects relative paths, category root directories, and targets outside these approved roots.

## Simulator resources

Simulator devices and runtimes are removed through `/usr/bin/xcrun simctl`. Device identifiers must be valid UUIDs. Runtime identifiers must use the `com.apple.CoreSimulator.SimRuntime.` prefix.

## Selection safeguards

- Active targets cannot be deleted.
- Archives and Simulator Runtimes are never selected automatically.
- The newest installed runtime for each platform receives an additional warning.
- Pinned runtimes receive an additional warning.
- XCTest devices with APFS-shared data use logical-size classification and do not contribute to verified reclaimable totals.
- Category deletion is scoped to that category and cannot include selections from another category.

## Automatic cleanup

Automatic cleanup is limited to Derived Data, Xcode Logs, and Xcode Caches. It is disabled by default.

Before automatic deletion, Derived checks for Xcode, Simulator, XCTest, CoreSimulator, `xcodebuild`, `simctl`, and related build processes. Cleanup is deferred if a related process is active. Cleanup is also deferred when process inspection cannot be completed.

## Confirmation and history

Manual deletion requires a confirmation alert. Deletion is permanent and does not use the Trash.

Each cleanup produces a local history record containing the trigger, target category, path, operation, outcome, and byte count. History records do not leave the Mac.
