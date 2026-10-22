//
//  AdminWorkOrderQuickActionsModifier.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Quello che le azioni rapide aprono, uguale in lista e dettaglio: il foglio delle note di chiusura, la
//  conferma dell'annullamento e l'avviso con l'esito (assegnazione automatica o errore). Più le voci del
//  menu di stato, riusate da intestazione, menu contestuale e swipe.
//

import SwiftUI

private struct AdminWorkOrderQuickActionsModifier: ViewModifier {
    @Bindable var actions: AdminWorkOrderQuickActions

    func body(content: Content) -> some View {
        content
            .sheet(item: $actions.completion) { completion in
                AdminWorkOrderCompletionSheet(viewModel: completion)
            }
            .confirmationDialog("Cancel this work order?", isPresented: $actions.isConfirmingCancel,
                                titleVisibility: .visible, presenting: actions.cancelling) { _ in
                Button("Cancel work order", role: .destructive) { Task { await actions.confirmCancel() } }
                Button("Keep it", role: .cancel) {}
            } message: { order in
                Text("\"\(order.title)\" will be closed as cancelled.")
            }
            .alert(actions.outcome?.title ?? "", isPresented: $actions.isShowingOutcome,
                   presenting: actions.outcome) { _ in
                Button("OK") {}
            } message: { outcome in
                Text(outcome.message)
            }
    }
}

extension View {
    /// Il foglio di chiusura, la conferma di annullamento e l'avviso con l'esito delle azioni rapide.
    func adminWorkOrderQuickActions(_ actions: AdminWorkOrderQuickActions) -> some View {
        modifier(AdminWorkOrderQuickActionsModifier(actions: actions))
    }
}

/// Le voci "cambia stato": una per stato possibile, con icona e colore.
struct AdminWorkOrderStatusMenuItems: View {
    let choices: [AdminWorkOrderStatus]
    let onSelect: (AdminWorkOrderStatus) -> Void

    var body: some View {
        ForEach(choices, id: \.self) { status in
            Button(role: status == .cancelled ? .destructive : nil) {
                onSelect(status)
            } label: {
                Label(status == .completed ? String(localized: "Complete…") : status.localized,
                      systemImage: status.systemImage)
            }
        }
    }
}
