# CHM Reader — Implementation Progress

## Phase 1: Project Skeleton + C Library Integration
- [x] Create Package.swift with three targets (CHMLib, CHMKit, CHMReader)
- [x] Vendor CHMLib sources (chm_lib.{h,c}, lzx.{h,c})
- [x] Write module.modulemap
- [x] Verify compilation (swift build)

## Phase 2: Swift Wrapper (CHMKit)
- [x] CHMEntry value type
- [x] CHMError enum
- [x] CHMFile core class (open, close, resolve, extract, enumerate)
- [x] TOCParser (state-machine .hhc parser)
- [x] CHMSearchIndex (inverted index)

## Phase 3: SwiftUI App Shell
- [x] CHMReaderApp (WindowGroup + NSOpenPanel)
- [x] CHMViewModel (@Observable)
- [x] ContentView (NavigationSplitView)
- [x] SidebarView (recursive DisclosureGroup TOC tree)
- [x] WebContentView (WebViewStore + NSViewRepresentable)
- [x] CHMURLSchemeHandler
- [x] SearchView

## Phase 4: Search Integration
- [x] Async index build on document open
- [x] Wire .searchable() with debounce
- [x] Search results navigation

## Phase 5: Polish
- [x] Encoding edge cases (Windows-1252, UTF-8 BOM)
- [x] Fallback flat TOC
- [x] Forward/back navigation (toolbar buttons + gestures)
- [x] Keyboard shortcuts (Cmd+[/] for back/forward)
- [x] Info.plist UTImportedTypeDeclarations
- [x] CLI argument support (swift run CHMReader /path/to/file.chm)
- [x] URL fragment handling for TOC anchors

## Verification
- [x] `swift build` succeeds
- [x] Unit tests pass (8/8)
- [x] App opens real CHM file (NVAPI 6MB), TOC navigates, content renders
