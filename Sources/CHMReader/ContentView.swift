import SwiftUI
import WebKit
import CHMKit

struct ContentView: View {
    @Binding var fileURL: URL?

    @State private var viewModel: CHMViewModel?
    @State private var errorMessage: String?
    @State private var loadedURL: URL?

    var body: some View {
        Group {
            if let vm = viewModel {
                MainContentView(viewModel: vm)
            } else if let error = errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Failed to open CHM file")
                        .font(.headline)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("Open a CHM file to get started")
                        .foregroundStyle(.secondary)
                    Text("File \u{2192} Open (\u{2318}O)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onChange(of: fileURL) {
            loadFile()
        }
        .frame(minWidth: 700, minHeight: 500)
    }

    private func loadFile() {
        guard let url = fileURL, url != loadedURL else { return }
        loadedURL = url
        do {
            let chmFile = try CHMFile(url: url)
            viewModel = CHMViewModel(chmFile: chmFile)
            errorMessage = nil
        } catch {
            viewModel = nil
            errorMessage = error.localizedDescription
        }
    }
}

struct MainContentView: View {
    @Bindable var viewModel: CHMViewModel
    @State private var webViewStore = WebViewStore()

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 200, ideal: 260, max: 400)
        } detail: {
            WebContentView(webViewStore: webViewStore)
        }
        .searchable(text: $viewModel.searchText, prompt: "Search help content")
        .onChange(of: viewModel.searchText) {
            viewModel.performSearch()
        }
        .onChange(of: viewModel.selectedPath) {
            if let path = viewModel.selectedPath {
                webViewStore.navigate(to: path)
            }
        }
        .onAppear {
            webViewStore.setup(chmFile: viewModel.currentCHMFile)
            if let path = viewModel.selectedPath {
                webViewStore.navigate(to: path)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button {
                    webViewStore.webView?.goBack()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .help("Back")
                .keyboardShortcut("[", modifiers: .command)

                Button {
                    webViewStore.webView?.goForward()
                } label: {
                    Image(systemName: "chevron.right")
                }
                .help("Forward")
                .keyboardShortcut("]", modifiers: .command)
            }
        }
    }

    @ViewBuilder
    private var sidebar: some View {
        if !viewModel.searchText.isEmpty {
            if viewModel.isSearching {
                ProgressView("Searching...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.searchResults.isEmpty {
                ContentUnavailableView.search(text: viewModel.searchText)
            } else {
                SearchView(results: viewModel.searchResults, selectedPath: $viewModel.selectedPath)
            }
        } else {
            SidebarView(nodes: viewModel.tocNodes, selectedPath: $viewModel.selectedPath)
        }
    }
}
