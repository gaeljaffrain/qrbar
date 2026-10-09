# QRBar

A tiny, offline QR code generator that lives in the macOS menu bar.

Type or paste a URL, get a QR code. Copy it, save it as PNG or SVG, or drag it
straight into another app. Codes are generated locally with Core Image
(`CIQRCodeGenerator`): no network, no accounts, no dependencies. The app is
sandboxed without a network entitlement, so it cannot go online.

## Build

Requires macOS 13+ and Xcode. Open `QRBar.xcodeproj`, select the `QRBar` scheme, and run. `Cmd-U` runs the tests.

## Layout

- `Sources/QRBarCore`: QR generation plus PNG/SVG output (UI-free, unit-tested). Built as a framework embedded in the app.
- `Sources/QRBar`: SwiftUI `MenuBarExtra` app. Its `Info.plist` is generated from build settings (`LSUIElement`, so no Dock icon).
- `Resources`: sandbox entitlements.

## License

QRBar is released under the MIT License. See [LICENSE](LICENSE) for details.
