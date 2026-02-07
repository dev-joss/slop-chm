import Foundation

public enum CHMError: LocalizedError {
    case openFailed(path: String)
    case extractionFailed(path: String)
    case entryNotFound(path: String)
    case tocParseFailed
    case invalidData

    public var errorDescription: String? {
        switch self {
        case .openFailed(let path):
            return "Failed to open CHM file: \(path)"
        case .extractionFailed(let path):
            return "Failed to extract entry: \(path)"
        case .entryNotFound(let path):
            return "Entry not found: \(path)"
        case .tocParseFailed:
            return "Failed to parse table of contents"
        case .invalidData:
            return "Invalid data in CHM file"
        }
    }
}
