import AaronUI
import SwiftUI

/// AaronUI input with a native slider for continuous adjustment (not provided by AaronUI).
/// Text may exceed the slider range when permitted; dragging always stays inside it.
struct SettingsNumericField<Label: View>: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: FloatingPointFormatStyle<Double>
    let clampsUpper: Bool
    let suffix: Text
    let onEditingChanged: (Bool) -> Void
    let onEditingCommit: () -> Void
    let label: Label
    private var fieldLabel = Text("Value")
    @State private var draft = ""
    @FocusState private var isEditing: Bool

    init(value: Binding<Double>, in range: ClosedRange<Double>, step: Double = 0.1,
         format: FloatingPointFormatStyle<Double> = .number, clampsUpper: Bool = true,
         suffix: Text = Text(""), onEditingChanged: @escaping (Bool) -> Void = { _ in },
         onEditingCommit: @escaping () -> Void = {}, @ViewBuilder label: () -> Label) {
        self._value = value
        self.range = range
        self.step = step
        self.format = format
        self.clampsUpper = clampsUpper
        self.suffix = suffix
        self.onEditingChanged = onEditingChanged
        self.onEditingCommit = onEditingCommit
        self.label = label()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AUISpacing.md) {
            HStack(spacing: AUISpacing.md) {
                label.auiText(.bodyMd)
                Spacer()
                AUIInput(text: $draft, size: .xs)
                    .frame(width: 88)
                    .focused($isEditing)
                    .accessibilityLabel(fieldLabel)
                    .onSubmit(commit)
                suffix.auiText(.caption).foregroundStyle(AUIColor.onSurfaceMuted)
            }
            // Native stepped sliders draw one tick per step on macOS. Fine-grained
            // ranges turn those ticks into a second solid track. Quantize the value
            // instead, keeping the native slider and its focus/drag behavior.
            Slider(value: Binding(get: { min(range.upperBound, max(range.lowerBound, value)) },
                                  set: { value = sliderValue($0) }), in: range) { editing in
                onEditingChanged(editing)
                if !editing { onEditingCommit() }
            }
            .tint(AUIColor.primary)
            .accessibilityLabel(fieldLabel)
            .accessibilityValue(Text(value.formatted(format)))
            .accessibilityAdjustableAction { direction in
                onEditingChanged(true)
                switch direction {
                case .increment: value = sliderValue(value + step)
                case .decrement: value = sliderValue(value - step)
                @unknown default: break
                }
                onEditingChanged(false)
                onEditingCommit()
            }
        }
        .onAppear { draft = value.formatted(format) }
        .onDisappear { if isEditing { commit() } }
        .onChange(of: value) { _, value in
            if !isEditing { draft = value.formatted(format) }
        }
        .onChange(of: isEditing) { _, editing in
            if editing { onEditingChanged(true) }
            else { commit() }
        }
    }

    private func sliderValue(_ proposed: Double) -> Double {
        let stepped = range.lowerBound + ((proposed - range.lowerBound) / step).rounded() * step
        return min(range.upperBound, max(range.lowerBound, stepped))
    }

    private func commit() {
        if let parsed = try? format.parseStrategy.parse(draft), parsed.isFinite {
            value = max(range.lowerBound, clampsUpper ? min(range.upperBound, parsed) : parsed)
        }
        draft = value.formatted(format)
        onEditingChanged(false)
        onEditingCommit()
    }
}

extension SettingsNumericField where Label == Text {
    init(_ title: String, value: Binding<Double>, in range: ClosedRange<Double>, step: Double = 0.1,
         format: FloatingPointFormatStyle<Double> = .number, clampsUpper: Bool = true,
         suffix: Text = Text(""), onEditingChanged: @escaping (Bool) -> Void = { _ in },
         onEditingCommit: @escaping () -> Void = {}) {
        self.init(value: value, in: range, step: step, format: format, clampsUpper: clampsUpper,
                  suffix: suffix, onEditingChanged: onEditingChanged, onEditingCommit: onEditingCommit) {
            Text(LocalizedStringKey(title))
        }
        fieldLabel = Text(LocalizedStringKey(title))
    }
}
