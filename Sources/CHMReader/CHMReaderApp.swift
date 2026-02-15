import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static var chm: UTType {
        UTType(filenameExtension: "chm") ?? UTType(importedAs: "com.microsoft.chm", conformingTo: .data)
    }
}

struct FocusedViewModelKey: FocusedValueKey {
    typealias Value = CHMViewModel
}

extension FocusedValues {
    var viewModel: CHMViewModel? {
        get { self[FocusedViewModelKey.self] }
        set { self[FocusedViewModelKey.self] = newValue }
    }
}

@main
struct CHMReaderApp: App {
    @State private var openedURL: URL?
    @FocusedValue(\.viewModel) private var viewModel

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

                Divider()

                Button("Export Page...") {
                    viewModel?.exportCurrentPage()
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(viewModel?.selectedPath == nil)

                Button("Export All...") {
                    viewModel?.exportAll()
                }
                .keyboardShortcut("e", modifiers: [.command, .shift, .option])
                .disabled(viewModel == nil)
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
