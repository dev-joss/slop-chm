import Foundation

/// A node in the CHM table of contents tree.
public struct TOCNode: Identifiable, Hashable {
    public let id = UUID()
    public let title: String
    public let path: String?
    public var children: [TOCNode]

    public init(title: String, path: String?, children: [TOCNode]) {
        self.title = title
        self.path = path
        self.children = children
    }
}

/// State-machine parser for .hhc files (malformed HTML).
/// Does NOT use XMLParser — .hhc files frequently have unclosed tags,
/// unescaped entities, and other invalid XML.
public enum TOCParser {

    public static func parse(data: Data) throws -> [TOCNode] {
        // Try UTF-8 first, then Windows-1252
        let html: String
        if let utf8 = String(data: data, encoding: .utf8) {
            html = utf8
        } else if let win1252 = String(data: data, encoding: .windowsCP1252) {
            html = win1252
        } else {
            throw CHMError.tocParseFailed
        }
        return parse(html: html)
    }

    public static func parse(html: String) -> [TOCNode] {
        let scanner = Scanner(string: html)
        scanner.charactersToBeSkipped = nil
        scanner.caseSensitive = false

        // Stack of children arrays for nesting; the bottom is the root list.
        var stack: [[TOCNode]] = [[]]

        // Current <OBJECT> block accumulator
        var currentName: String?
        var currentLocal: String?
        var inObject = false

        while !scanner.isAtEnd {
            // Advance to the next '<'
            _ = scanner.scanUpToString("<")
            guard scanner.scanString("<") != nil else { break }

            // Read the tag name (possibly with '/')
            guard let tagRaw = scanner.scanUpToString(">") else { continue }
            _ = scanner.scanString(">")

            let tag = tagRaw.trimmingCharacters(in: .whitespaces)
            let tagLower = tag.lowercased()

            if tagLower.hasPrefix("ul") {
                // Push a new children level
                stack.append([])
            } else if tagLower.hasPrefix("/ul") {
                // Pop children and attach to last node of parent
                guard stack.count > 1 else { continue }
                let children = stack.removeLast()
                if var parent = stack[stack.count - 1].last {
                    stack[stack.count - 1].removeLast()
                    parent.children = children
                    stack[stack.count - 1].append(parent)
                } else {
                    // No parent node — merge children up
                    stack[stack.count - 1].append(contentsOf: children)
                }
            } else if tagLower.hasPrefix("object") {
                inObject = true
                currentName = nil
                currentLocal = nil
            } else if tagLower.hasPrefix("/object") {
                if inObject, let name = currentName {
                    let path = currentLocal.map { p in
                        p.hasPrefix("/") ? p : "/\(p)"
                    }
                    let node = TOCNode(title: name, path: path, children: [])
                    stack[stack.count - 1].append(node)
                }
                inObject = false
            } else if inObject && tagLower.hasPrefix("param") {
                // Parse <param name="..." value="...">
                let attrs = parseAttributes(tag)
                let paramName = attrs["name"]?.lowercased() ?? ""
                let paramValue = attrs["value"] ?? ""
                if paramName == "name" {
                    currentName = decodeHTMLEntities(paramValue)
                } else if paramName == "local" {
                    currentLocal = paramValue
                }
            }
        }

        // Flatten any remaining stack levels
        while stack.count > 1 {
            let children = stack.removeLast()
            stack[stack.count - 1].append(contentsOf: children)
        }

        return stack.first ?? []
    }

    // MARK: - Attribute Parser

    private static func parseAttributes(_ tag: String) -> [String: String] {
        var attrs: [String: String] = [:]
        let pattern = #"(\w+)\s*=\s*"([^"]*)""#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return attrs }
        let nsTag = tag as NSString
        let matches = regex.matches(in: tag, range: NSRange(location: 0, length: nsTag.length))
        for match in matches {
            let key = nsTag.substring(with: match.range(at: 1)).lowercased()
            let value = nsTag.substring(with: match.range(at: 2))
            attrs[key] = value
        }
        return attrs
    }

    // MARK: - HTML Entity Decoding

    private static func decodeHTMLEntities(_ string: String) -> String {
        var result = string
        let entities: [(String, String)] = [
            ("&amp;", "&"),
            ("&lt;", "<"),
            ("&gt;", ">"),
            ("&quot;", "\""),
            ("&#39;", "'"),
            ("&apos;", "'"),
            ("&nbsp;", " "),
        ]
        for (entity, char) in entities {
            result = result.replacingOccurrences(of: entity, with: char, options: .caseInsensitive)
        }
        return result
    }
}
