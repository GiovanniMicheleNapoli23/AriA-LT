//
//  AdminExtractionFieldEditor.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  L'editor di un campo del dettaglio, secondo il tipo: testo, testo lungo, elenco (una voce per riga),
//  numero o scelta. Un pallino segna i campi cambiati, il rosso quelli non validi.
//

import SwiftUI

struct AdminExtractionFieldEditor: View {
    let field: AdminExtractionField
    @Binding var text: String
    var isChanged = false
    var isInvalid = false
    var isEnabled = true

    @ScaledMetric(relativeTo: .caption) private var dotSize = 6

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(field.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                if isChanged {
                    Circle()
                        .fill(isInvalid ? Color.red : Color.liteAccent)
                        .frame(width: dotSize, height: dotSize)
                        .accessibilityLabel(isInvalid ? Text("Invalid value") : Text("Edited"))
                }
                Spacer(minLength: 0)
                if field.editor == .list {
                    Text("One per line")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            editor
                .font(.body)
                .disabled(!isEnabled)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    if isInvalid {
                        RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.red.opacity(0.6), lineWidth: 1)
                    }
                }
        }
    }

    @ViewBuilder
    private var editor: some View {
        switch field.editor {
        case .text:
            TextField(field.label, text: $text)
                .textInputAutocapitalization(.never)
        case .multiline:
            TextField(field.label, text: $text, axis: .vertical)
                .lineLimit(2...8)
        case .list:
            TextField(field.label, text: $text, axis: .vertical)
                .lineLimit(3...12)
        case .decimal:
            TextField(field.label, text: $text)
                .keyboardType(.decimalPad)
        case .integer:
            TextField(field.label, text: $text)
                .keyboardType(.numberPad)
        case .choice(let choices):
            Picker(field.label, selection: $text) {
                if !field.isRequired || text.isEmpty { Text("None").tag("") }
                ForEach(choices) { Text($0.label).tag($0.value) }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .tint(Color.liteAccent)
        }
    }
}
