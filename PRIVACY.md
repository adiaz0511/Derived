# Privacy

Derived processes information locally on the Mac where it runs.

## Data processed

The application reads filesystem metadata for approved Xcode, Simulator, and XCTest storage locations. It also reads local process names to determine whether development tools are active and executes local `simctl` commands to inspect or remove simulator resources.

## Data storage

Preferences are stored through `UserDefaults`. Cleanup results are stored locally as JSON Lines under the user's Application Support directory.

## Data transmission

Derived does not include analytics, advertising, accounts, telemetry, or network services. It does not transmit scanned paths, process information, preferences, or cleanup history.
