# CHM Reader for macOS — Implementation Plan
## Context
Build a native macOS app that opens and reads Microsoft Compiled HTML Help (.chm) files. CHM is a legacy but widely-used format that bundles HTML, images, CSS, and a table-of-contents into a compressed binary archive. No Swift-native CHM library exists, so we'll wrap the battle-tested C library CHMLib (Jed Wing) via Swift Package Manager's C target support.

## Architecture Overview

```
Package.swift
Sources/
  CHMLib/              ← Vendored C library (chm_lib.c, lzx.c)
    include/
      module.modulemap
      chm_lib.h, lzx.h
  CHMKit/              ← Swift wrapper library
    CHMFile.swift       ← Core wrapper around chmFile*
    CHMEntry.swift      ← Value type for archive entries
    CHMTableOfContents.swift  ← .hhc state-machine parser → TOCNode tree
    CHMSearchIndex.swift      ← In-memory inverted index for full-text search
    CHMError.swift
  CHMReader/           ← SwiftUI macOS app
    CHMReaderApp.swift          ← @main, DocumentGroup(viewing:)
    CHMDocument.swift           ← FileDocument (copies to temp file for CHMLib)
    CHMViewModel.swift          ← @Observable view model
    ContentView.swift           ← NavigationSplitView (sidebar + detail)
    SidebarView.swift           ← Recursive TOC tree via List(children:)
    WebContentView.swift        ← NSViewRepresentable wrapping WKWebView
    CHMURLSchemeHandler.swift   ← WKURLSchemeHandler serving content from CHM
    SearchView.swift            ← Search results UI
Tests/
  CHMKitTests/
```

### Key tech choices:

macOS 14+ (Sonoma) — @Observable, stable NavigationSplitView
SwiftUI with WKWebView via NSViewRepresentable
Custom URL scheme (chm-internal://) so WKWebView loads all resources from the CHM archive via WKURLSchemeHandler
In-memory inverted index for search (CHM files are small enough)
## Implementation Steps
### Phase 1: Project Skeleton + C Library Integration
Create SPM project — Package.swift with three targets:
CHMLib (C target): vendored chm_lib.c, lzx.c with public headers and modulemap
CHMKit (Swift library): depends on CHMLib
CHMReader (executable): depends on CHMKit
Vendor CHMLib sources — copy chm_lib.{h,c} and lzx.{h,c} from jedwing/CHMLib
Write modulemap in Sources/CHMLib/include/module.modulemap
Verify compilation — swift build must succeed with no errors
### Phase 2: Swift Wrapper (CHMKit)
CHMEntry — value type with path, offset, length, space fields
CHMError — LocalizedError enum for open/extract/parse failures
CHMFile — core class wrapping chmFile*:
init(url:) calls chm_open(), deinit calls chm_close()
resolveEntry(path:) → CHMEntry?
extractData(for:) → Data? via chm_retrieve_object()
enumerateEntries() → [CHMEntry] via chm_enumerate() with C callback + Unmanaged context
findHHCPath() — enumerate entries for *.hhc
TOCParser — state-machine parser for .hhc (not XMLParser — .hhc files are malformed HTML):
Track <UL>/</UL> nesting via a stack of [TOCNode] arrays
Extract Name and Local params from <OBJECT> blocks
Output: [TOCNode] tree (title, path, children)
CHMSearchIndex — strip HTML → tokenize → inverted index ([word: Set<path>]):
build(from:) async — enumerate HTML entries, extract text, index
search(query:) → [SearchResult] with title, path, snippet
### Phase 3: SwiftUI App Shell
CHMReaderApp — DocumentGroup(viewing: CHMDocument.self) + UTType declaration for .chm
CHMDocument — FileDocument that copies regularFileContents to a temp file (CHMLib needs a file path)
CHMViewModel — @Observable class: holds CHMFile, tocNodes, selectedPath, search state
ContentView — NavigationSplitView with sidebar + detail, .searchable() modifier
SidebarView — List(tocNodes, children: \.optionalChildren, selection:) with disclosure triangles
WebContentView — NSViewRepresentable wrapping WKWebView:
Create WKWebViewConfiguration with CHMURLSchemeHandler in makeNSView
Load chm-internal://content/<path> in updateNSView when selectedPath changes
Guard against re-entrant navigation (check webView.url != url)
CHMURLSchemeHandler — WKURLSchemeHandler:
Convert chm-internal://content/path/to/file → extract from CHMFile
Serve with correct MIME type based on file extension
Handle missing resources gracefully
### Phase 4: Search Integration
Build search index asynchronously on document open
Wire .searchable() to CHMViewModel.performSearch() with debounce
Display results as search suggestions; selecting a result navigates the web view
### Phase 5: Polish
Handle encoding edge cases (Windows-1252, UTF-8 BOM)
Fallback flat TOC when no .hhc exists
Forward/back navigation buttons
Keyboard shortcuts (Cmd+F focus search, arrow keys in sidebar)
Info.plist with UTImportedTypeDeclarations for .chm file association
# Critical Implementation Details
C callback interop: chm_enumerate() takes a C function pointer — must use a free function (not a closure) with Unmanaged<Context> passed through the void *context parameter
WKURLSchemeHandler must be registered before WKWebView is created — cannot add it after init
TOC parser must be a state machine, not XMLParser, because .hhc files are frequently malformed HTML
FileDocument temp-file approach: since CHMLib opens files by path, and FileDocument provides Data, we write to a temp file in init(configuration:) and pass that to CHMFile(url:)

# Verification
swift build succeeds with no warnings
Unit tests pass: open sample CHM, enumerate entries, extract HTML content, parse TOC
App launches, opens a .chm file via File > Open
TOC sidebar displays hierarchical tree from .hhc
Clicking TOC entries renders HTML in the detail pane (including images/CSS)
Links within HTML content navigate correctly
Search finds terms across all HTML pages and navigates to results