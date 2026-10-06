import AppKit
import SwiftUI

@main
struct QRBarApp: App {
    init() {
        // Menubar-only: no Dock icon even when run outside an app bundle.
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra("QRBar", systemImage: "qrcode") {
            ContentView()
        }
        .menuBarExtraStyle(.window)
    }
}
