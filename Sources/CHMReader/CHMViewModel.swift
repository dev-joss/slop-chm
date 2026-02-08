import Foundation
import CHMKit

@MainActor @Observable
final class CHMViewModel {
    var tocNodes: [TOCNode] = []
    var selectedPath: String?
    var searchText: String = ""
    var searchResults: [SearchResult] = []
    var isSearching: Bool = false
    var isIndexBuilt: Bool = false

    private let chmFile: CHMFile
    private let searchIndex = CHMSearchIndex()
    private var searchTask: Task<Void, Never>?

    init(chmFile: CHMFile) {
        self.chmFile = chmFile
        loadTOC()
        buildSearchIndex()
    }

    var currentCHMFile: CHMFile { chmFile }

    // MARK: - TOC

    private func loadTOC() {
        guard let hhcPath = chmFile.findHHCPath() else {
            // Fallback: flat list of HTML files
            tocNodes = buildFlatTOC()
            return
        }
        do {
            let data = try chmFile.extractData(path: hhcPath)
            tocNodes = try TOCParser.parse(data: data)
        } catch {
            tocNodes = buildFlatTOC()
        }

        // Select default page
        if selectedPath == nil {
            selectedPath = chmFile.findDefaultPage() ?? firstLeafPath(in: tocNodes)
        }
    }

    private func buildFlatTOC() -> [TOCNode] {
        let entries = chmFile.enumerateEntries()
        return entries
            .filter { $0.isHTML }
            .sorted { $0.path.localizedCaseInsensitiveCompare($1.path) == .orderedAscending }
            .map { TOCNode(title: $0.filename, path: $0.path, children: []) }
    }

    private func firstLeafPath(in nodes: [TOCNode]) -> String? {
        for node in nodes {
            if let path = node.path { return path }
            if let path = firstLeafPath(in: node.children) { return path }
        }
        return nil
    }

    // MARK: - Search

    private func buildSearchIndex() {
        let url = chmFile.url
        Task {
            // Task inherits @MainActor; the await hops to the actor's executor
            try? await searchIndex.build(from: url)
            // Back on @MainActor after await
            isIndexBuilt = true
        }
    }

    func performSearch() {
        searchTask?.cancel()
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }
        isSearching = true
        searchTask = Task {
            // Debounce
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            let results = await searchIndex.search(query: query)
            guard !Task.isCancelled else { return }
            // Back on @MainActor after await — no manual hop needed
            searchResults = results
            isSearching = false
        }
    }
}
