import AaronUI
import SwiftUI

/// Native list retains desktop multi-selection and reorder semantics; rows use AaronUI chrome.
struct SettingsSelectionList<Item: Hashable, ID: Hashable, Row: View, Empty: View>: View {
    @Binding var items: [Item]
    @Binding var selection: Set<Item>
    let id: KeyPath<Item, ID>
    @ViewBuilder var row: (Binding<Item>) -> Row
    @ViewBuilder var emptyView: Empty

    var body: some View {
        if items.isEmpty {
            emptyView
        } else {
            List(selection: $selection) {
                ForEach($items, id: id) { item in
                    row(item)
                        .frame(minHeight: 44)
                        .tag(item.wrappedValue)
                        .listRowBackground(AUIColor.surface)
                        .listRowSeparator(.hidden)
                }
                .onMove { source, destination in
                    items.move(fromOffsets: source, toOffset: destination)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .frame(height: min(320, max(60, CGFloat(items.count) * 56)))
        }
    }
}
