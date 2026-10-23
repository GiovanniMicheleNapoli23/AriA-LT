//
//  AdminCraftedAriaModifier.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Tutto quello che "Modifica con Aria" aggiunge a un lettore, in un solo modificatore (uguale per artifact
//  e rapporto): il pulsante flottante in basso a destra, il foglio col pannello, la pillola per riaprirlo, la
//  domanda se si butta una modifica a mano non salvata, e lo stop di una richiesta in corso quando si esce.
//

import SwiftUI

struct AdminCraftedAriaModifier: ViewModifier {
    let editor: AdminCraftedAriaEditor
    @Binding var panel: AdminCraftedAriaPanelState
    @Binding var asksDiscard: Bool
    let choices: [AdminCraftedAriaChoice]
    let summary: AdminCraftedAriaProposalSummary?
    let showsResume: Bool
    /// Il pulsante di Aria: solo quando c'è un documento da modificare e nient'altro di Aria in pagina.
    let showsButton: Bool
    let open: () -> Void
    let actions: AdminCraftedAriaActions
    let discardAndOpen: () -> Void

    private var buttonVisible: Bool { showsButton && !showsResume && !panel.isOpen }

    func body(content: Content) -> some View {
        content
            // Spazio sotto l'ultimo contenuto: il pulsante non copre niente.
            .contentMargins(.bottom, buttonVisible ? 96 : 0, for: .scrollContent)
            .overlay(alignment: .bottomTrailing) {
                if buttonVisible {
                    AdminCraftedAriaButton(action: open)
                        .padding(.trailing, 20)
                        .padding(.bottom, 12)
                        .ignoresSafeArea(.keyboard)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if showsResume {
                    AdminCraftedAriaResumeBar(isRunning: editor.isRunning) { panel.isOpen = true }
                }
            }
            .sheet(isPresented: $panel.isOpen) {
                AdminCraftedAriaSheet(editor: editor, panel: $panel, choices: choices, proposal: summary, actions: actions)
            }
            .alert("Discard changes?", isPresented: $asksDiscard) {
                Button("Discard", role: .destructive, action: discardAndOpen)
                Button("Keep editing", role: .cancel) {}
            } message: {
                Text("Aria edits the saved version, not your unsaved changes.")
            }
            .onDisappear { actions.stop() }
    }
}

extension View {
    func adminCraftedAria(editor: AdminCraftedAriaEditor, panel: Binding<AdminCraftedAriaPanelState>,
                          asksDiscard: Binding<Bool>, choices: [AdminCraftedAriaChoice],
                          summary: AdminCraftedAriaProposalSummary?, showsResume: Bool,
                          showsButton: Bool, open: @escaping () -> Void,
                          actions: AdminCraftedAriaActions, discardAndOpen: @escaping () -> Void) -> some View {
        modifier(AdminCraftedAriaModifier(editor: editor, panel: panel, asksDiscard: asksDiscard, choices: choices,
                                          summary: summary, showsResume: showsResume, showsButton: showsButton,
                                          open: open, actions: actions, discardAndOpen: discardAndOpen))
    }
}
