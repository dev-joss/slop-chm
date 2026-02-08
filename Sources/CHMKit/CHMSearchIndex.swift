import Foundation
import CHMLib

/// Search result from the in-memory index.
public struct SearchResult: Identifiable, Hashable {
    public let id = UUID()
    public let title: String
    public let path: String
    public let snippet: String
}

/// In-memory inverted index for full-text search across CHM HTML content.
public actor CHMSearchIndex {
    /// Inverted index: word → set of paths containing that word.
    private var index: [String: Set<String>] = [:]
    /// Maps path → extracted plain text (for snippet generation).
    private var textCache: [String: String] = [:]
    /// Maps path → title.
    private var titles: [String: String] = [:]
    /// Whether the index has been built.
    public private(set) var isBuilt = false

    public init() {}

    /// Build the index by opening its own CHMFile handle (avoids sharing the C pointer).
    public func build(from url: URL) throws {
        let chmFile = try CHMFile(url: url)
        let entries = chmFile.enumerateEntries(
            flags: CHM_ENUMERATE_NORMAL | CHM_ENUMERATE_FILES
        )
        let htmlEntries = entries.filter { $0.isHTML }

        for entry in htmlEntries {
            guard let data = try? chmFile.extractData(for: entry) else { continue }
            let html = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .windowsCP1252)
                ?? ""
            let title = extractTitle(from: html) ?? entry.filename
            let text = stripHTML(html)

            titles[entry.path] = title
            textCache[entry.path] = text

            let words = tokenize(text)
            for word in words {
                index[word, default: []].insert(entry.path)
            }
        }
        isBuilt = true
    }

    /// Search for a query string, returning matching results.
    public func search(query: String) -> [SearchResult] {
        let queryWords = tokenize(query)
        guard !queryWords.isEmpty else { return [] }

        // Intersect result sets for all query words
        var matchingPaths: Set<String>?
        for word in queryWords {
            let matches = index.keys
                .filter { $0.hasPrefix(word) }
                .reduce(into: Set<String>()) { result, key in
                    result.formUnion(index[key] ?? [])
                }
            if matchingPaths == nil {
                matchingPaths = matches
            } else {
                matchingPaths?.formIntersection(matches)
            }
        }

        guard let paths = matchingPaths else { return [] }

        return paths.compactMap { path in
            let title = titles[path] ?? (path as NSString).lastPathComponent
            let snippet = generateSnippet(for: path, query: query)
            return SearchResult(title: title, path: path, snippet: snippet)
        }
        .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    // MARK: - Private

    private func tokenize(_ text: String) -> [String] {
        text.lowercased()
            .components(separatedBy: .alphanumerics.inverted)
            .filter { $0.count >= 2 }
    }

    private func stripHTML(_ html: String) -> String {
        var result = html
        // Remove script/style blocks
        let blockPattern = #"<(script|style)[^>]*>[\s\S]*?</\1>"#
        if let regex = try? NSRegularExpression(pattern: blockPattern, options: .caseInsensitive) {
            result = regex.stringByReplacingMatches(
                in: result, range: NSRange(result.startIndex..., in: result), withTemplate: " "
            )
        }
        // Remove tags
        let tagPattern = #"<[^>]+>"#
        if let regex = try? NSRegularExpression(pattern: tagPattern) {
            result = regex.stringByReplacingMatches(
                in: result, range: NSRange(result.startIndex..., in: result), withTemplate: " "
            )
        }
        // Decode entities
        result = result
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
        // Collapse whitespace
        if let regex = try? NSRegularExpression(pattern: #"\s+"#) {
            result = regex.stringByReplacingMatches(
                in: result, range: NSRange(result.startIndex..., in: result), withTemplate: " "
            )
        }
        return result.trimmingCharacters(in: .whitespaces)
    }

    private func extractTitle(from html: String) -> String? {
        let pattern = #"<title[^>]*>(.*?)</title>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let range = Range(match.range(at: 1), in: html) else { return nil }
        let title = String(html[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? nil : title
    }

    private func generateSnippet(for path: String, query: String) -> String {
        guard let text = textCache[path] else { return "" }
        let lower = text.lowercased()
        let queryLower = query.lowercased()

        guard let range = lower.range(of: queryLower) else {
            // Show beginning of text
            return String(text.prefix(120))
        }

        let matchIndex = lower.distance(from: lower.startIndex, to: range.lowerBound)
        let start = max(0, matchIndex - 40)
        let startIdx = text.index(text.startIndex, offsetBy: start)
        let endIdx = text.index(startIdx, offsetBy: min(120, text.distance(from: startIdx, to: text.endIndex)))
        var snippet = String(text[startIdx..<endIdx])
        if start > 0 { snippet = "..." + snippet }
        if endIdx < text.endIndex { snippet = snippet + "..." }
        return snippet
    }
}
