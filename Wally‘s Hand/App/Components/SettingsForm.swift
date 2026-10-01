import AaronUI
import SwiftUI

/// Application-specific composition of AaronUI surfaces; not a second control library.
struct SettingsForm<Content: View>: View {
    var scrolls = true
    @ViewBuilder var content: Content

    var body: some View {
        Group {
            if scrolls {
                ScrollView { fields }
            } else {
                fields
            }
        }
        .buttonStyle(AUIButtonStyle(variant: .outline, size: .sm))
        .foregroundStyle(AUIColor.onSurface)
    }

    private var fields: some View {
        VStack(alignment: .leading, spacing: AUISpacing.xxl) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AUISpacing.xxl)
    }
}

struct SettingsSection<Content: View>: View {
    private let title: String?
    private let content: Content

    init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AUISpacing.md) {
            if let title {
                Text(title).auiText(.headlineSm).accessibilityAddTraits(.isHeader)
            }
            AUIItemSectionGroup(size: .sm) {
                Group(subviews: content) { rows in
                    ForEach(rows) { row in
                        row.padding(.vertical, AUISpacing.lg)
                    }
                }
            }
        }
    }
}

struct SettingsToggle<Label: View>: View {
    @Binding var isOn: Bool
    @ViewBuilder var label: Label

    var body: some View {
        Toggle(isOn: $isOn) {
            label.frame(maxWidth: .infinity, alignment: .leading)
        }
        .toggleStyle(.auiSwitch)
    }
}

extension SettingsToggle where Label == Text {
    init(_ title: String, isOn: Binding<Bool>) {
        self._isOn = isOn
        self.label = Text(LocalizedStringKey(title))
    }
}

struct SettingsActions<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        HStack(spacing: AUISpacing.md) { content; Spacer(minLength: 0) }
            .buttonStyle(AUIButtonStyle(variant: .outline, size: .sm))
    }
}

struct SettingsActionRow<Label: View, Content: View>: View {
    @ViewBuilder var label: Label
    @ViewBuilder var content: Content
    var action: () -> Void
    var body: some View {
        HStack {
            label.auiText(.bodyMd)
            Spacer()
            Button(action: action) { content }
                .buttonStyle(AUIButtonStyle(variant: .outline, size: .sm))
        }
    }
}

extension SettingsActionRow where Label == Text, Content == Text {
    init(_ title: String, _ button: String, action: @escaping () -> Void) {
        label = Text(LocalizedStringKey(title))
        content = Text(LocalizedStringKey(button))
        self.action = action
    }
}

/// AaronUI has no icon-grid picker; selection and focus use its button control.
struct SettingsChoiceGrid<Value: Hashable, Content: View>: View {
    let elements: [Value]
    @Binding var selection: Value
    let columns: Int
    @ViewBuilder var content: (Value) -> Content

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: columns), spacing: AUISpacing.md) {
            ForEach(elements, id: \.self) { value in
                Button { selection = value } label: {
                    content(value).frame(maxWidth: .infinity)
                }
                .buttonStyle(AUIButtonStyle(variant: selection == value ? .fill : .outline, size: .md))
                .accessibilityAddTraits(selection == value ? .isSelected : [])
            }
        }
    }
}
