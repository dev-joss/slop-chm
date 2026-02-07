import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static var chm: UTType {
        UTType(filenameExtension: "chm") ?? UTType(importedAs: "com.microsoft.chm", conformingTo: .data)
    }
}

@main
struct CHMReaderApp: App {
    @State private var openedURL: URL?

    var body: some Scene {
        WindowGroup {
            ContentView(fileURL: $openedURL)
                .onAppear {
                    // Support: swift run CHMReader /path/to/file.chm
                    if openedURL == nil {
                        let args = ProcessInfo.processInfo.arguments
                        if let path = args.dropFirst().first(where: { $0.hasSuffix(".chm") }) {
                            openedURL = URL(fileURLWithPath: path)
                        }
                    }
                }
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open...") {
                    openFile()
                }
                .keyboardShortcut("o", modifiers: .command)
            }
        }
    }

    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    private func openFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.chm]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }
        openedURL = url
    }
}
