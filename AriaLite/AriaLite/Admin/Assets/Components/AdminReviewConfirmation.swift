//
//  AdminReviewConfirmation.swift
//  AriaLite
//
//  Created by Giovanni Michele on 10/11/26.
//
//  L'alert di conferma delle decisioni di revisione che tolgono un record dal lavoro (Reject, Unapprove),
//  uguale nei dettagli di allarmi, piani, asset e ricambi: il dettaglio dà la decisione in attesa e cosa fare
//  se si conferma.
//

import SwiftUI

private struct AdminReviewConfirmation: ViewModifier {
    @Binding var isPresented: Bool
    let action: AdminReviewAction?
    let confirm: (AdminReviewAction) -> Void
    /// L'ultima decisione chiesta: il titolo non cambia mentre l'alert si chiude e `action` torna `nil`.
    @State private var shown: AdminReviewAction?

    func body(content: Content) -> some View {
        content.alert(title, isPresented: $isPresented, presenting: action) { action in
            Button(action.title, role: action == .reject ? .destructive : nil) { confirm(action) }
            Button("Cancel", role: .cancel) {}
        } message: { action in
            Text(message(for: action))
        }
        .onChange(of: action, initial: true) { _, new in if let new { shown = new } }
    }

    private var title: LocalizedStringKey {
        (action ?? shown) == .unapprove ? "Unapprove it?" : "Reject it?"
    }

    private func message(for action: AdminReviewAction) -> LocalizedStringKey {
        action == .unapprove ? "It goes back to draft and waits for review."
            : "It will no longer be used by the assistant until it is approved again."
    }
}

extension View {
    /// Chiede conferma di `action` (Reject o Unapprove) e chiama `confirm` se si accetta.
    func adminReviewConfirmation(isPresented: Binding<Bool>, action: AdminReviewAction?,
                                 confirm: @escaping (AdminReviewAction) -> Void) -> some View {
        modifier(AdminReviewConfirmation(isPresented: isPresented, action: action, confirm: confirm))
    }
}
