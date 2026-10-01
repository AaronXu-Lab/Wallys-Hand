import AaronUI
import SwiftUI

/// A named, keyboard-reachable help button; macOS owns popover focus and dismissal.
private struct SettingsHelp<Help: View>: ViewModifier {
    let hidden: Bool
    let help: Help
    @State private var presented = false

    func body(content: Content) -> some View {
        HStack(spacing: AUISpacing.xs) {
            content
            if !hidden {
                AUIButton(String(localized: "More information"), systemImage: "info.circle", iconOnly: true,
                          variant: .ghost, size: .xs) { presented.toggle() }
                    .accessibilityLabel(Text("More information"))
                    .popover(isPresented: $presented) {
                        AUIItemSurface {
                            help.auiText(.bodySm).padding(AUISpacing.lg)
                        }
                        .frame(maxWidth: 340)
                        .padding(AUISpacing.md)
                    }
            }
        }
    }
}

extension View {
    func settingsHelp<Help: View>(hidden: Bool = false,
                                 @ViewBuilder content: () -> Help) -> some View {
        modifier(SettingsHelp(hidden: hidden, help: content()))
    }
}
