import SwiftUI
import CHMKit

/// High-performance tree view for the CHM table of contents.
/// Flattens the tree into visible rows so `LazyVStack` only creates views on screen.
struct SidebarView: View {
    let nodes: [TOCNode]
    @Binding var selectedPath: String?

    @State private var expandedIDs: Set<UUID> = []
    @FocusState private var isFocused: Bool

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(visibleRows, id: \.node.id) { row in
                    TOCRowView(
                        node: row.node,
                        depth: row.depth,
                        isExpanded: expandedIDs.contains(row.node.id),
                        isSelected: row.node.path != nil && row.node.path == selectedPath,
                        onToggle: { toggleExpansion(row.node) },
                        onSelect: {
                            if let path = row.node.path {
                                selectedPath = path
                            }
                        }
                    )
                }
            }
            .padding(.vertical, 4)
        }
        .focusable()
        .focused($isFocused)
        .focusEffectDisabled()
        .onKeyPress(.upArrow) {
            navigateUp()
            return .handled
        }
        .onKeyPress(.downArrow) {
            navigateDown()
            return .handled
        }
        .onKeyPress(.leftArrow) {
            navigateLeft()
            return .handled
        }
        .onKeyPress(.rightArrow) {
            navigateRight()
            return .handled
        }
        .onAppear {
            isFocused = true
        }
    }

    private struct FlatRow {
        let node: TOCNode
        let depth: Int
    }

    private var visibleRows: [FlatRow] {
        var result: [FlatRow] = []
        func walk(_ nodes: [TOCNode], depth: Int) {
            for node in nodes {
                result.append(FlatRow(node: node, depth: depth))
                if !node.children.isEmpty && expandedIDs.contains(node.id) {
                    walk(node.children, depth: depth + 1)
                }
            }
        }
        walk(nodes, depth: 0)
        return result
    }

    private func toggleExpansion(_ node: TOCNode) {
        if expandedIDs.contains(node.id) {
            expandedIDs.remove(node.id)
        } else {
            expandedIDs.insert(node.id)
        }
    }

    private func navigateUp() {
        let rows = visibleRows
        guard !rows.isEmpty else { return }

        if let currentIndex = rows.firstIndex(where: { $0.node.path != nil && $0.node.path == selectedPath }) {
            // Scan backwards past path-less nodes
            for i in stride(from: currentIndex - 1, through: 0, by: -1) {
                if let path = rows[i].node.path {
                    selectedPath = path
                    return
                }
            }
        } else {
            selectedPath = rows.first(where: { $0.node.path != nil })?.node.path
        }
    }

    private func navigateDown() {
        let rows = visibleRows
        guard !rows.isEmpty else { return }

        if let currentIndex = rows.firstIndex(where: { $0.node.path != nil && $0.node.path == selectedPath }) {
            // Scan forwards past path-less nodes
            for i in (currentIndex + 1)..<rows.count {
                if let path = rows[i].node.path {
                    selectedPath = path
                    return
                }
            }
        } else {
            selectedPath = rows.first(where: { $0.node.path != nil })?.node.path
        }
    }

    private func navigateLeft() {
        let rows = visibleRows
        guard !rows.isEmpty else { return }

        // Find current selection
        guard let currentIndex = rows.firstIndex(where: { $0.node.path != nil && $0.node.path == selectedPath }) else { return }
        let currentRow = rows[currentIndex]

        // If current item has children and is expanded, collapse it
        if !currentRow.node.children.isEmpty && expandedIDs.contains(currentRow.node.id) {
            expandedIDs.remove(currentRow.node.id)
        } else {
            // Navigate to parent
            // Find parent by searching backwards for a row with depth one less
            let targetDepth = currentRow.depth - 1
            if targetDepth >= 0 {
                for i in stride(from: currentIndex - 1, through: 0, by: -1) {
                    if rows[i].depth == targetDepth {
                        if let path = rows[i].node.path {
                            selectedPath = path
                        }
                        break
                    }
                }
            }
        }
    }

    private func navigateRight() {
        let rows = visibleRows
        guard !rows.isEmpty else { return }

        // Find current selection
        guard let currentIndex = rows.firstIndex(where: { $0.node.path != nil && $0.node.path == selectedPath }) else { return }
        let currentRow = rows[currentIndex]

        // Only act if current item has children
        guard !currentRow.node.children.isEmpty else { return }

        if expandedIDs.contains(currentRow.node.id) {
            // Already expanded, move to first child
            if currentIndex + 1 < rows.count && rows[currentIndex + 1].depth > currentRow.depth {
                if let path = rows[currentIndex + 1].node.path {
                    selectedPath = path
                }
            }
        } else {
            // Not expanded, expand it
            expandedIDs.insert(currentRow.node.id)
        }
    }
}

private struct TOCRowView: View {
    let node: TOCNode
    let depth: Int
    let isExpanded: Bool
    let isSelected: Bool
    let onToggle: () -> Void
    let onSelect: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            if !node.children.isEmpty {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: 12)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onToggle)
            } else {
                Spacer().frame(width: 12)
            }

            Image(systemName: node.children.isEmpty ? "doc.text" : "folder")
                .foregroundStyle(.secondary)
                .frame(width: 16)

            Text(node.title)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, CGFloat(depth) * 16)
        .padding(.vertical, 3)
        .padding(.horizontal, 4)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        .cornerRadius(4)
        .contentShape(Rectangle())
        .onTapGesture {
            if !node.children.isEmpty {
                onToggle()
            }
            onSelect()
        }
    }
}
