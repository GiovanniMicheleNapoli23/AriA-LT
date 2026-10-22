//
//  AdminReasoningSessionEditorModifier.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Gli alert di rinomina ed eliminazione di una sessione e l'errore se il server rifiuta.
//  Lo stato è tutto nell'editor (AdminReasoningSessionEditor): qui solo la presentazione.
//

import SwiftUI

struct AdminReasoningSessionEditorModifier: ViewModifier {
    @Bindable var editor: AdminReasoningSessionEditor

    func body(content: Content) -> some View {
        content
            .alert("Rename session", isPresented: $editor.showsRename) {
                TextField("Title", text: $editor.renameTitle)
                Button("Cancel", role: .cancel) {}
                // Niente `.disabled`: negli alert non si aggiorna mentre si scrive. Il controllo è in `commitRename`.
                Button("Rename") { Task { await editor.commitRename() } }
            }
            .confirmationDialog("Delete this session?", isPresented: $editor.showsDeleteConfirmation,
                                titleVisibility: .visible) {
                Button("Delete", role: .destructive) { Task { await editor.confirmDelete() } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The conversation will be removed from your history.")
            }
            .alert("Couldn't update the session", isPresented: $editor.showsError) {
                Button("OK") {}
            } message: {
                Text(editor.errorMessage ?? "")
            }
    }
}
