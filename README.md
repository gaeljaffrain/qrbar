# QRBar

A tiny, offline QR code generator that lives in the macOS menu bar.

Type or paste a URL, get a QR code. Copy it, save it as PNG or SVG, or drag it
straight into another app. Codes are generated locally with Core Image
(`CIQRCodeGenerator`): no network, no accounts, no dependencies. The app is
sandboxed without a network entitlement, so it cannot go online.

## Contents

- `Sources/QRBarCore`: QR generation plus PNG/SVG output (UI-free, unit-tested). Built as a framework embedded in the app.
- `Sources/QRBar`: SwiftUI `MenuBarExtra` app. Its `Info.plist` is generated from build settings (`LSUIElement`, so no Dock icon).
- `Resources`: sandbox entitlements and app icon.

## Versioning

The marketing version (`X.Y.Z`) is set once per release; the build number
increases with every distributed build and never resets.

1. **Start a release:** in Xcode, set **Marketing Version** at the project
   level, then commit only that change: `Bump version to X.Y.Z`.
2. **Before archiving any build you distribute** (including beta builds), run
   `agvtool next-version` from the repo root, then commit only that change:
   `Bump build number to N`.
3. **Ship the release:** tag the commit the shipped build was made from and
   push the tag:
```sh
   git tag -a vX.Y.Z -m "QRBar X.Y.Z"
   git push origin vX.Y.Z
```

## Build

Requires macOS 14+ and Xcode. Open `QRBar.xcodeproj`, select the `QRBar` scheme, and run. `Cmd-U` runs the tests.

## Packaging a DMG

`scripts/make-dmg.sh` turns an exported, notarized `QRBar.app` into a signed,
notarized, and stapled DMG with a drag-to-Applications window.

### One-time setup

1. Install [create-dmg](https://github.com/create-dmg/create-dmg):
   ```sh
   brew install create-dmg
   ```
2. Make sure a **Developer ID Application** certificate is in your keychain:
   ```sh
   security find-identity -v -p codesigning
   ```
   If none is listed, create one in Xcode → Settings → Accounts → Manage Certificates → **+** → Developer ID Application.
3. Save notarization credentials as a keychain profile named `notary`, using an
   app-specific password from [account.apple.com](https://account.apple.com):
   ```sh
   xcrun notarytool store-credentials "notary" \
     --apple-id you@example.com --team-id TEAMID
   ```

### Building a release

1. In Xcode, choose Product → Archive, then Distribute App → Direct Distribution
   and export the notarized app.
2. Run the script with the path to the exported app:
   ```sh
   scripts/make-dmg.sh path/to/QRBar.app
   ```

The DMG is written to the current directory as `QRBar-<version>.dmg`, where the
version is read from the app's `CFBundleShortVersionString`.

### Options

Set these environment variables to change the defaults:

| Variable | Default | Purpose |
| --- | --- | --- |
| `SIGN_IDENTITY` | `Developer ID Application` | Code-signing identity. Use the full name if you have more than one, e.g. `Developer ID Application: Your Name (TEAMID)`. |
| `NOTARY_PROFILE` | `notary` | Keychain profile used by `notarytool`. |
| `SKIP_NOTARIZE` | `0` | Set to `1` to build and sign only, for checking the window layout quickly. |

```sh
SKIP_NOTARIZE=1 scripts/make-dmg.sh path/to/QRBar.app
```

## License

QRBar is released under the MIT License. See [LICENSE](LICENSE) for details.
