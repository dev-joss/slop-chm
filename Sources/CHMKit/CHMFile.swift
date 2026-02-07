import Foundation
import CHMLib

/// Swift wrapper around a CHMLib `chmFile*`.
public final class CHMFile: @unchecked Sendable {
    private let handle: OpaquePointer
    public let url: URL

    public init(url: URL) throws {
        self.url = url
        guard let h = chm_open(url.path) else {
            throw CHMError.openFailed(path: url.path)
        }
        self.handle = h
    }

    deinit {
        chm_close(handle)
    }

    // MARK: - Resolve & Extract

    /// Look up a single entry by path.
    public func resolveEntry(path: String) -> CHMEntry? {
        var ui = chmUnitInfo()
        let result = chm_resolve_object(handle, path, &ui)
        guard result == CHM_RESOLVE_SUCCESS else { return nil }
        return CHMEntry(unitInfo: ui)
    }

    /// Extract the data for a given entry.
    public func extractData(for entry: CHMEntry) throws -> Data {
        guard var ui = unitInfo(for: entry) else {
            throw CHMError.entryNotFound(path: entry.path)
        }
        let length = Int(ui.length)
        guard length > 0 else { return Data() }

        var buffer = [UInt8](repeating: 0, count: length)
        let bytesRead = chm_retrieve_object(handle, &ui, &buffer, 0, Int64(length))
        guard bytesRead > 0 else {
            throw CHMError.extractionFailed(path: entry.path)
        }
        return Data(buffer[0..<Int(bytesRead)])
    }

    /// Extract data by path convenience.
    public func extractData(path: String) throws -> Data {
        guard let entry = resolveEntry(path: path) else {
            throw CHMError.entryNotFound(path: path)
        }
        return try extractData(for: entry)
    }

    // MARK: - Enumeration

    /// Enumerate all entries in the archive.
    public func enumerateEntries(
        flags: Int32 = CHM_ENUMERATE_ALL
    ) -> [CHMEntry] {
        let context = EnumerationContext()
        let ptr = Unmanaged.passUnretained(context).toOpaque()
        chm_enumerate(handle, flags, enumerateCallback, ptr)
        return context.entries
    }

    // MARK: - TOC Discovery

    /// Find the path to the .hhc (table of contents) file.
    public func findHHCPath() -> String? {
        let entries = enumerateEntries(flags: CHM_ENUMERATE_NORMAL | CHM_ENUMERATE_FILES)
        return entries.first { $0.path.lowercased().hasSuffix(".hhc") }?.path
    }

    /// Find the default page path from the #SYSTEM file or by convention.
    public func findDefaultPage() -> String? {
        // Try #SYSTEM metadata first - it contains the default topic
        if let systemEntry = resolveEntry(path: "/#SYSTEM"),
           let data = try? extractData(for: systemEntry) {
            if let page = parseSystemDefaultTopic(data: data) {
                return page
            }
        }
        // Fallback: common default page names
        let candidates = ["/index.htm", "/index.html", "/default.htm", "/default.html"]
        return candidates.first { resolveEntry(path: $0) != nil }
    }

    // MARK: - Private

    private func unitInfo(for entry: CHMEntry) -> chmUnitInfo? {
        var ui = chmUnitInfo()
        let result = chm_resolve_object(handle, entry.path, &ui)
        guard result == CHM_RESOLVE_SUCCESS else { return nil }
        return ui
    }

    /// Parse the #SYSTEM file for the default topic (entry type 2).
    private func parseSystemDefaultTopic(data: Data) -> String? {
        guard data.count > 4 else { return nil }
        var offset = 4 // skip version DWORD
        while offset + 4 <= data.count {
            let code = UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
            let length = Int(UInt16(data[offset + 2]) | (UInt16(data[offset + 3]) << 8))
            offset += 4
            guard offset + length <= data.count else { break }
            if code == 2 { // Default Topic
                let strData = data[offset..<(offset + length)]
                if let str = String(data: strData, encoding: .utf8)?
                    .trimmingCharacters(in: .init(charactersIn: "\0")) {
                    let path = str.hasPrefix("/") ? str : "/\(str)"
                    return path
                }
            }
            offset += length
        }
        return nil
    }
}

// MARK: - C Callback Interop

private class EnumerationContext {
    var entries: [CHMEntry] = []
}

private func enumerateCallback(
    _ h: OpaquePointer?,
    _ ui: UnsafeMutablePointer<chmUnitInfo>?,
    _ context: UnsafeMutableRawPointer?
) -> Int32 {
    guard let ui = ui, let context = context else {
        return CHM_ENUMERATOR_CONTINUE
    }
    let ctx = Unmanaged<EnumerationContext>.fromOpaque(context).takeUnretainedValue()
    ctx.entries.append(CHMEntry(unitInfo: ui.pointee))
    return CHM_ENUMERATOR_CONTINUE
}

// MARK: - CHMEntry init from chmUnitInfo

extension CHMEntry {
    init(unitInfo ui: chmUnitInfo) {
        let pathTuple = ui.path
        let path = withUnsafePointer(to: pathTuple) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: Int(CHM_MAX_PATHLEN) + 1) {
                String(cString: $0)
            }
        }
        self.init(
            path: path,
            offset: ui.start,
            length: Int64(ui.length),
            space: Int32(ui.space)
        )
    }
}
