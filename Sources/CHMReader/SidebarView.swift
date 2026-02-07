import SwiftUI
import CHMKit

/// High-performance tree view for the CHM table of contents.
/// Flattens the tree into visible rows so `LazyVStack` only creates views on screen.
struct SidebarView: View {
    let nodes: [TOCNode]
    @Binding var selectedPath: String?

    @State private var expandedIDs: Set<UUID> = []

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
