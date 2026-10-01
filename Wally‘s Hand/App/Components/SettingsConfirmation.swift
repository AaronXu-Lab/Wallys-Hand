import AaronUI
import SwiftUI

extension View {
    /// AaronUI supplies the content and actions; its native sheet isolates focus from the editor.
    func settingsConfirmation(_ title: String, isPresented: Binding<Bool>, message: String,
                              confirm: String, destructive: Bool = false,
                              onCancel: @escaping () -> Void = {}, action: @escaping () -> Void) -> some View {
        auiSheet(isPresented: isPresented, title: title, width: .sm, showClose: false) {
            Text(message).auiText(.bodyMd).fixedSize(horizontal: false, vertical: true)
        } actions: {
            AUIModalActions(
                primary: .init(confirm, destructive: destructive) {
                    isPresented.wrappedValue = false
                    action()
                },
                secondary: .init(String(localized: "Cancel")) {
                    isPresented.wrappedValue = false
                    onCancel()
                }
            )
        }
    }
}
