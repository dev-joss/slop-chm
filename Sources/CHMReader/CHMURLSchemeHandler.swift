import Foundation
import WebKit
import CHMKit

/// Serves CHM archive content via a custom URL scheme (chm-internal://).
/// Must be registered on WKWebViewConfiguration BEFORE creating the WKWebView.
final class CHMURLSchemeHandler: NSObject, WKURLSchemeHandler {
    private let chmFile: CHMFile

    init(chmFile: CHMFile) {
        self.chmFile = chmFile
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            urlSchemeTask.didFailWithError(CHMError.invalidData)
            return
        }

        // Extract path from chm-internal://content/path/to/file
        var path = components.path
        if path.hasPrefix("/content") {
            path = String(path.dropFirst("/content".count))
        }
        if path.isEmpty { path = "/" }

        // Decode percent-encoded path
        path = path.removingPercentEncoding ?? path

        do {
            var data = try chmFile.extractData(path: path)
            let mimeType = Self.mimeType(for: path)

            // Handle encoding edge cases for text content
            var encoding: String? = nil
            if mimeType.hasPrefix("text/") {
                // Strip UTF-8 BOM if present
                let bom: [UInt8] = [0xEF, 0xBB, 0xBF]
                if data.count >= 3 && Array(data.prefix(3)) == bom {
                    data = data.dropFirst(3)
                }
                // Detect encoding — prefer UTF-8, fall back to Windows-1252
                if String(data: data, encoding: .utf8) != nil {
                    encoding = "utf-8"
                } else {
                    encoding = "windows-1252"
                }
            }

            let response = URLResponse(
                url: url,
                mimeType: mimeType,
                expectedContentLength: data.count,
                textEncodingName: encoding
            )
            urlSchemeTask.didReceive(response)
            urlSchemeTask.didReceive(data)
            urlSchemeTask.didFinish()
        } catch {
            urlSchemeTask.didFailWithError(error)
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {
        // Nothing to cancel — extraction is synchronous
    }

    // MARK: - MIME Type

    private static func mimeType(for path: String) -> String {
        let ext = (path as NSString).pathExtension.lowercased()
        switch ext {
        case "htm", "html": return "text/html"
        case "css":         return "text/css"
        case "js":          return "application/javascript"
        case "png":         return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif":         return "image/gif"
        case "bmp":         return "image/bmp"
        case "svg":         return "image/svg+xml"
        case "ico":         return "image/x-icon"
        case "xml":         return "application/xml"
        case "txt":         return "text/plain"
        default:            return "application/octet-stream"
        }
    }
}
