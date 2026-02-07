import SwiftUI
import UniformTypeIdentifiers
import CHMKit

/// FileDocument that copies the CHM data to a temp file for CHMLib.
/// CHMLib requires a file path (not raw data), so we persist to a temp location.
final class CHMDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.chm] }

    let chmFile: CHMFile?
    private let tempURL: URL?

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            self.chmFile = nil
            self.tempURL = nil
            return
        }

        // Write to temp file — CHMLib needs a path
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent(UUID().uuidString + ".chm")
        try data.write(to: tempFile)
        self.tempURL = tempFile
        self.chmFile = try CHMFile(url: tempFile)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        throw CocoaError(.fileWriteNoPermission)
    }

    deinit {
        // Clean up temp file
        if let url = tempURL {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
