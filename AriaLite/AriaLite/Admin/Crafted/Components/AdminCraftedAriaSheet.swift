//
//  AdminCraftedAriaSheet.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  "Modifica con Aria" come foglio basso: si può tenere piccolo o a metà e il documento sotto resta
//  visibile e scorribile — è lì che la proposta si legge, contro la versione attuale. Dentro, il pannello
//  e, dietro un tocco, l'elenco per scegliere su cosa lavora Aria.
//

import SwiftUI

struct AdminCraftedAriaSheet: View {
    let editor: AdminCraftedAriaEditor
    @Binding var panel: AdminCraftedAriaPanelState
    let choices: [AdminCraftedAriaChoice]
    let proposal: AdminCraftedAriaProposalSummary?
    let actions: AdminCraftedAriaActions

    var body: some View {
        NavigationStack {
            AdminCraftedAriaPanel(editor: editor, panel: $panel, proposal: proposal, actions: actions)
                .navigationTitle("Edit with Aria")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        if #available(iOS 26.0, *) {
                            Button(role: .close, action: actions.hide)
                        } else {
                            Button(action: actions.hide) {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                            }
                            .accessibilityLabel(Text("Close"))
                        }
                    }
                }
                .navigationDestination(isPresented: $panel.showsScope) {
                    AdminCraftedAriaScopeList(choices: choices, selection: $panel.scope)
                }
        }
        .presentationDetents([.fraction(0.4), .medium, .large])
        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        .presentationDragIndicator(.visible)
    }
}
