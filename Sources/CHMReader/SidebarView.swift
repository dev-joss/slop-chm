import SwiftUI
import CHMKit

/// Recursive tree view for the CHM table of contents.
struct SidebarView: View {
    let nodes: [TOCNode]
    @Binding var selectedPath: String?

    var body: some View {
        List {
            ForEach(nodes) { node in
                TOCNodeView(node: node, selectedPath: $selectedPath)
            }
        }
    }
}

private struct TOCNodeView: View {
    let node: TOCNode
    @Binding var selectedPath: String?

    var body: some View {
        if node.children.isEmpty {
            row
        } else {
            DisclosureGroup {
                ForEach(node.children) { child in
                    TOCNodeView(node: child, selectedPath: $selectedPath)
                }
            } label: {
                row
            }
        }
    }

    private var row: some View {
        HStack {
            Image(systemName: node.children.isEmpty ? "doc.text" : "folder")
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Text(node.title)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        .cornerRadius(4)
        .onTapGesture {
            if let path = node.path {
                selectedPath = path
            }
        }
    }

    private var isSelected: Bool {
        guard let path = node.path, let selected = selectedPath else { return false }
        return path == selected
    }
}
