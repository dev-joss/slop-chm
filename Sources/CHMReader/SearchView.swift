import SwiftUI
import CHMKit

/// Displays search results from the CHM search index.
struct SearchView: View {
    let results: [SearchResult]
    @Binding var selectedPath: String?

    var body: some View {
        List(selection: $selectedPath) {
            ForEach(results) { result in
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.title)
                        .fontWeight(.medium)
                    Text(result.snippet)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .tag(result.path)
            }
        }
    }
}
