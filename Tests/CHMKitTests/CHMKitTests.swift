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
