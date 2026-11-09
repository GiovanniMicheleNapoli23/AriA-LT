//
//  AdminInspectionItemRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un controllo della checklist, compilabile sul posto: il cerchio lo spunta, la nota si scrive sotto e si
//  salva con "Save note" (o uscendo dal campo). Un controllo non spuntato con una nota è evidenziato.
//

import SwiftUI

struct AdminInspectionItemRow: View {
    let item: AdminInspectionItem
    /// L'ispezione si può scrivere e l'item ha un id.
    let canEdit: Bool
    /// Una richiesta per questo item è in corso: spunta e nota aspettano.
    let isPending: Bool
    let onToggle: () -> Void
    let onNote: (String) -> Void

    @State private var draft: String
    @State private var showsNote: Bool
    @FocusState private var isFocused: Bool
    @ScaledMetric(relativeTo: .title3) private var checkSize = 28.0

    init(item: AdminInspectionItem, canEdit: Bool, isPending: Bool,
         onToggle: @escaping () -> Void, onNote: @escaping (String) -> Void) {
        self.item = item
        self.canEdit = canEdit
        self.isPending = isPending
        self.onToggle = onToggle
        self.onNote = onNote
        _draft = State(initialValue: item.notes ?? "")
        _showsNote = State(initialValue: item.notes != nil)
    }

    private var isDirty: Bool { draft.trimmingCharacters(in: .whitespacesAndNewlines) != (item.notes ?? "") }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Button(action: onToggle) {
                    Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(item.isChecked ? Color.green : Color.secondary)
                        .frame(width: checkSize, height: checkSize)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
                .disabled(!canEdit || isPending)
                .accessibilityLabel(Text(item.description))
                .accessibilityValue(item.isChecked ? Text("Done") : Text("To do"))
                .accessibilityHint(Text("Toggles this check"))

                Text(item.description)
                    .font(.subheadline)
                    .foregroundStyle(item.isChecked ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)

                if isPending {
                    ProgressView()
                } else if canEdit {
                    Button {
                        withAnimation(.snappy) { showsNote.toggle() }
                        if showsNote { isFocused = true }
                    } label: {
                        Image(systemName: item.notes == nil ? "text.bubble" : "text.bubble.fill")
                            .foregroundStyle(item.needsAttention ? Color.orange : Color.liteAccent)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Note"))
                }
            }
            if showsNote { noteEditor } else if let note = item.notes { noteText(note) }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background {
            if item.needsAttention {
                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.orange.opacity(0.12))
            }
        }
        .onChange(of: item.notes) { _, new in
            if !isFocused { draft = new ?? "" }
        }
        .onChange(of: isFocused) { _, focused in
            if !focused, isDirty { commit() }
        }
    }

    private var noteEditor: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Note", text: $draft, axis: .vertical)
                .lineLimit(1...5)
                .font(.subheadline)
                .focused($isFocused)
                .disabled(isPending)
                .padding(10)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            if isDirty {
                Button("Save note") { commit() }
                    .font(.footnote.weight(.semibold))
                    .buttonStyle(.bordered)
                    .tint(Color.liteAccent)
                    .disabled(isPending)
            }
        }
        .padding(.leading, checkSize + 12)
    }

    private func noteText(_ note: String) -> some View {
        Text(note)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, checkSize + 12)
    }

    private func commit() {
        isFocused = false
        onNote(draft)
    }
}
