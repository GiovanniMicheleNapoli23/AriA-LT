//
//  AriaStepSheets.swift
//  AriaLite
//
//  Created by Giovanni Michele on 15/10/26.
//
//  Fogli di testo del lavoro: la nota di un passo (obbligatoria se il passo non è stato fatto)
//  e le note di chiusura dell'ordine (obbligatorie).
//

import SwiftUI

/// Nota di un passo, fino a 2000 caratteri. `isRequired`: il passo "non fatto" ha bisogno del motivo.
struct AriaStepNoteSheet: View {
    let title: LocalizedStringKey
    let prompt: LocalizedStringKey?
    let isRequired: Bool
    let saveLabel: LocalizedStringKey
    let onSave: (String) -> Void

    @State private var text: String
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool

    private static let limit = 2000

    init(title: LocalizedStringKey, prompt: LocalizedStringKey? = nil, text: String, isRequired: Bool,
         saveLabel: LocalizedStringKey = "Save", onSave: @escaping (String) -> Void) {
        self.title = title
        self.prompt = prompt
        self.isRequired = isRequired
        self.saveLabel = saveLabel
        self.onSave = onSave
        _text = State(initialValue: text)
    }

    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSave: Bool { trimmed.count <= Self.limit && (!isRequired || !trimmed.isEmpty) }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 10) {
                if let prompt {
                    Text(prompt)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                TextEditor(text: $text)
                    .focused($focused)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                Text(verbatim: "\(trimmed.count)/\(Self.limit)")
                    .font(.caption)
                    .foregroundStyle(trimmed.count > Self.limit ? Color.red : Color.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(16)
            .background(Color(.systemGroupedBackground))
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.tint(Color.liteAccent)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        onSave(trimmed)
                        dismiss()
                    } label: {
                        Text(saveLabel).fontWeight(.semibold)
                    }
                    .tint(Color.liteAccent)
                    .disabled(!canSave)
                }
            }
            .onAppear { focused = true }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

/// Chiusura dell'ordine: cosa è stato fatto. `onComplete` restituisce il messaggio d'errore, `nil` se è andata.
struct AriaCompleteSheet: View {
    let unreportedCount: Int
    let onComplete: (String) async -> String?

    @State private var notes = ""
    @State private var isSending = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    private var trimmed: String { notes.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("Describe what was done. The task will be closed and sent for verification.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if unreportedCount > 0 {
                    Label("Steps without a result: \(unreportedCount)", systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.orange)
                }
                TextEditor(text: $notes)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .disabled(isSending)
                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.red)
                }
                Button {
                    Task {
                        isSending = true
                        errorMessage = await onComplete(trimmed)
                        isSending = false
                        if errorMessage == nil { dismiss() }
                    }
                } label: {
                    ZStack {
                        if isSending { ProgressView().tint(.white) } else {
                            Label("Complete task", systemImage: "checkmark.seal.fill")
                                .font(.system(size: 17, weight: .semibold))
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .tint(Color.liteAccent)
                .disabled(trimmed.isEmpty || unreportedCount > 0 || isSending)
            }
            .padding(16)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Complete task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.tint(Color.liteAccent).disabled(isSending)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(isSending)
    }
}
