import Foundation
import CHMLib

/// Represents a single entry (file) within a CHM archive.
public struct CHMEntry: Identifiable, Hashable {
    public let path: String
    public let offset: UInt64
    public let length: Int64
    public let space: Int32

    public var id: String { path }

    /// Whether this entry is a content file (not a metadata entry).
    public var isContent: Bool {
        space == CHM_UNCOMPRESSED || space == CHM_COMPRESSED
    }

    /// Whether this entry is an HTML file.
    public var isHTML: Bool {
        let lower = path.lowercased()
        return lower.hasSuffix(".htm") || lower.hasSuffix(".html")
    }

    /// The filename portion of the path.
    public var filename: String {
        (path as NSString).lastPathComponent
    }
}
