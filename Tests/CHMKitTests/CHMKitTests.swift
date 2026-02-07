import Testing
import Foundation
@testable import CHMKit

@Suite("TOC Parser Tests")
struct TOCParserTests {

    @Test("Parses simple HHC structure")
    func parseSimpleHHC() throws {
        let hhc = """
        <HTML>
        <BODY>
        <UL>
          <LI><OBJECT type="text/sitemap">
            <param name="Name" value="Introduction">
            <param name="Local" value="intro.htm">
          </OBJECT>
          <LI><OBJECT type="text/sitemap">
            <param name="Name" value="Chapter 1">
            <param name="Local" value="ch1.htm">
          </OBJECT>
          <UL>
            <LI><OBJECT type="text/sitemap">
              <param name="Name" value="Section 1.1">
              <param name="Local" value="ch1_s1.htm">
            </OBJECT>
          </UL>
        </UL>
        </BODY>
        </HTML>
        """
        let nodes = TOCParser.parse(html: hhc)
        #expect(nodes.count == 2)
        #expect(nodes[0].title == "Introduction")
        #expect(nodes[0].path == "/intro.htm")
        #expect(nodes[1].title == "Chapter 1")
        #expect(nodes[1].children.count == 1)
        #expect(nodes[1].children[0].title == "Section 1.1")
    }

    @Test("Handles HTML entities in names")
    func htmlEntities() throws {
        let hhc = """
        <UL>
          <LI><OBJECT type="text/sitemap">
            <param name="Name" value="C++ &amp; Templates">
            <param name="Local" value="cpp.htm">
          </OBJECT>
        </UL>
        """
        let nodes = TOCParser.parse(html: hhc)
        #expect(nodes.count == 1)
        #expect(nodes[0].title == "C++ & Templates")
    }

    @Test("Handles empty input")
    func emptyInput() {
        let nodes = TOCParser.parse(html: "")
        #expect(nodes.isEmpty)
    }
}

@Suite("Real CHM File Tests")
struct RealCHMTests {
    static let testFile = URL(fileURLWithPath: "/Users/jgray/src/nvapi/docs/NVAPI_Reference_OpenSource.chm")

    @Test("Opens and enumerates real CHM")
    func openReal() throws {
        let file = try CHMFile(url: Self.testFile)
        let entries = file.enumerateEntries()
        print("Total entries: \(entries.count)")
        let htmlEntries = entries.filter { $0.isHTML }
        print("HTML entries: \(htmlEntries.count)")
        for e in htmlEntries.prefix(5) {
            print("  path=\(e.path) len=\(e.length)")
        }
        #expect(!entries.isEmpty)
    }

    @Test("Parses TOC from real CHM")
    func parseTOC() throws {
        let file = try CHMFile(url: Self.testFile)
        if let hhcPath = file.findHHCPath() {
            print("HHC path: \(hhcPath)")
            let data = try file.extractData(path: hhcPath)
            print("HHC data size: \(data.count)")
            let nodes = try TOCParser.parse(data: data)
            print("TOC root nodes: \(nodes.count)")
            func dump(_ nodes: [TOCNode], indent: Int = 0) {
                for n in nodes.prefix(3) {
                    let pad = String(repeating: "  ", count: indent)
                    print("\(pad)title=\"\(n.title)\" path=\(n.path ?? "nil") children=\(n.children.count)")
                    dump(n.children, indent: indent + 1)
                }
            }
            dump(nodes)
            #expect(!nodes.isEmpty)
        } else {
            print("No HHC found")
        }
    }

    @Test("Extracts HTML content")
    func extractContent() throws {
        let file = try CHMFile(url: Self.testFile)
        if let page = file.findDefaultPage() {
            print("Default page: \(page)")
            let data = try file.extractData(path: page)
            print("Page size: \(data.count) bytes")
            #expect(data.count > 0)
        } else {
            print("No default page")
            // Try first HTML entry
            let entries = file.enumerateEntries()
            if let first = entries.first(where: { $0.isHTML }) {
                print("First HTML: \(first.path)")
                let data = try file.extractData(for: first)
                print("Size: \(data.count)")
                #expect(data.count > 0)
            }
        }
    }
}

@Suite("CHMEntry Tests")
struct CHMEntryTests {

    @Test("isHTML detection")
    func htmlDetection() {
        let htm = CHMEntry(path: "/page.htm", offset: 0, length: 100, space: 0)
        let html = CHMEntry(path: "/page.HTML", offset: 0, length: 100, space: 0)
        let css = CHMEntry(path: "/style.css", offset: 0, length: 50, space: 0)

        #expect(htm.isHTML)
        #expect(html.isHTML)
        #expect(!css.isHTML)
    }

    @Test("filename extraction")
    func filename() {
        let entry = CHMEntry(path: "/docs/guide/intro.htm", offset: 0, length: 100, space: 0)
        #expect(entry.filename == "intro.htm")
    }
}
