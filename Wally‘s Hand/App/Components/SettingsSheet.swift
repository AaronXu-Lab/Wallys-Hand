import AaronUI
import SwiftUI

extension View {
    /// AaronUI 0.1.1's icon-only sheet close loses its AX label on macOS.
    /// Use a named library button in the action slot while keeping native modal focus.
    func settingsSheet<Content: View>(isPresented: Binding<Bool>, title: String,
                                     width: AUISheetWidth = .sm,
                                     @ViewBuilder content: @escaping () -> Content) -> some View {
        auiSheet(isPresented: isPresented, title: title, width: width, showClose: false, content: content) {
            AUIButton(String(localized: "Close"), variant: .outline, size: .sm) {
                isPresented.wrappedValue = false
            }
            .keyboardShortcut(.cancelAction)
        }
    }
}
