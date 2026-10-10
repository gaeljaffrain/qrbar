import AppKit
import QRBarCore
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var text = ""
    @State private var seenPasteboardChange = -1
    @AppStorage("errorCorrection") private var correction = ErrorCorrection.medium

    private var code: QRCode? { QRCode(text, correction: correction) }

    var body: some View {
        VStack(spacing: 12) {
            TextField("URL or text", text: $text)
                .textFieldStyle(.roundedBorder)
                .onSubmit(copyImage)

            preview
                .frame(width: 240, height: 240)

            HStack {
                Group {
                    Button("Copy", action: copyImage)
                    Button("Save…", action: save)
                }
                .disabled(code == nil)
                Spacer()
                Menu {
                    Button("About QRBar", action: showAbout)
                    Picker("Error correction", selection: $correction) {
                        Text("Low (7%)").tag(ErrorCorrection.low)
                        Text("Medium (15%)").tag(ErrorCorrection.medium)
                        Text("Quartile (25%)").tag(ErrorCorrection.quartile)
                        Text("High (30%)").tag(ErrorCorrection.high)
                    }
                    .pickerStyle(.inline)
                    Divider()
                    Button("Quit QRBar") { NSApplication.shared.terminate(nil) }
                } label: {
                    Image(systemName: "gearshape")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
            }
        }
        .padding(14)
        .frame(width: 280)
        .onAppear(perform: prefillFromClipboard)
        .background(OnWindowBecomesKey(perform: prefillFromClipboard))
    }

    @ViewBuilder private var preview: some View {
        if let code, let png = code.pngData(scale: 8), let image = NSImage(data: png) {
            Image(nsImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .onDrag { dragProvider(for: png) }
        } else {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.secondary.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [4]))
                .overlay(Text("Enter a URL").foregroundStyle(.secondary))
        }
    }

    private func prefillFromClipboard() {
        // The menubar popover's view outlives each open, so this runs on every open.
        // Only act on a clipboard that changed since last time, so reopening doesn't
        // overwrite what the user typed.
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != seenPasteboardChange else { return }
        seenPasteboardChange = pasteboard.changeCount
        guard let clip = pasteboard.string(forType: .string)?
                  .trimmingCharacters(in: .whitespacesAndNewlines),
              let url = URL(string: clip), url.scheme?.hasPrefix("http") == true
        else { return }
        text = clip
    }

    private func copyImage() {
        guard let png = code?.pngData(), let image = NSImage(data: png) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
    }

    private func save() {
        guard let code else { return }
        let picker = FormatPicker()
        let panel = NSSavePanel()
        panel.allowedContentTypes = [picker.format.type]
        panel.nameFieldStringValue = "qrcode"
        panel.accessoryView = picker.view
        picker.onChange = { panel.allowedContentTypes = [$0.type] }
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let data = picker.format == .png ? code.pngData() : Data(code.svgString().utf8)
        try? data?.write(to: url)
    }

    private func dragProvider(for png: Data) -> NSItemProvider {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("qrcode.png")
        try? png.write(to: url)
        return NSItemProvider(contentsOf: url) ?? NSItemProvider()
    }
    
    private func showAbout() {
        // Wait until the menu has finished closing, otherwise activation is ignored.
        DispatchQueue.main.async {
            if #available(macOS 14, *) {
                NSApp.activate()
            } else {
                NSApp.activate(ignoringOtherApps: true)
            }
            NSApp.orderFrontStandardAboutPanel(nil)
            NSApp.windows.last(where: { $0.isVisible && $0 is NSPanel })?.orderFrontRegardless() // force to front
        }
    }
}

enum SaveFormat: String, CaseIterable {
    case png = "PNG", svg = "SVG"
    var type: UTType { self == .png ? .png : .svg }
}

/// "Format:" popup shown in the save panel; switching it updates the file extension.
final class FormatPicker: NSObject {
    private let popup = NSPopUpButton(frame: .zero, pullsDown: false)
    let view = NSStackView()
    var onChange: ((SaveFormat) -> Void)?

    var format: SaveFormat { SaveFormat.allCases[popup.indexOfSelectedItem] }

    override init() {
        super.init()
        popup.addItems(withTitles: SaveFormat.allCases.map(\.rawValue))
        popup.target = self
        popup.action = #selector(changed)
        view.orientation = .horizontal
        view.edgeInsets = NSEdgeInsets(top: 8, left: 20, bottom: 8, right: 20)
        view.addArrangedSubview(NSTextField(labelWithString: "Format:"))
        view.addArrangedSubview(popup)
    }

    @objc private func changed() { onChange?(format) }
}

/// Runs `perform` each time the hosting window becomes key, i.e. each time the menubar
/// popover is opened (SwiftUI's `onAppear` fires only once for it).
struct OnWindowBecomesKey: NSViewRepresentable {
    let perform: () -> Void

    func makeNSView(context: Context) -> Tracker { Tracker() }
    func updateNSView(_ view: Tracker, context: Context) { view.perform = perform }

    final class Tracker: NSView {
        var perform: (() -> Void)?
        private var observer: NSObjectProtocol?

        override func viewDidMoveToWindow() {
            observer.map(NotificationCenter.default.removeObserver)
            observer = window.map {
                NotificationCenter.default.addObserver(
                    forName: NSWindow.didBecomeKeyNotification, object: $0, queue: .main
                ) { [weak self] _ in self?.perform?() }
            }
        }

        deinit { observer.map(NotificationCenter.default.removeObserver) }
    }
}
