//
//  AdminExtractionFieldEditor.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Una riga del modulo di revisione, come nelle Impostazioni: etichetta a sinistra e valore a destra per
//  testo, numeri e scelte; etichetta sopra e testo sotto per i campi lunghi e gli elenchi (una voce per riga).
//  Con il testo molto grande va tutto in colonna. Un pallino segna i campi cambiati, il corallo quelli non validi.
//

import SwiftUI

struct AdminExtractionFieldEditor: View {
    let field: AdminExtractionField
    @Binding var text: String
    var isChanged = false
    var isInvalid = false
    var isEnabled = true

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .caption) private var dotSize = 6

    private var isStacked: Bool {
        dynamicTypeSize.isAccessibilitySize || field.editor == .multiline || field.editor == .list
    }

    var body: some View {
        Group {
            if isStacked {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        label
                        Spacer(minLength: 0)
                        if field.editor == .list {
                            Text("One per line").font(.caption2).foregroundStyle(.tertiary)
                        }
                    }
                    editor.frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    label
                    editor
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
        .padding(.vertical, 12)
        .disabled(!isEnabled)
    }

    private var label: some View {
        HStack(spacing: 6) {
            Text(field.label)
                .foregroundStyle(isInvalid ? Color.liteDanger : .secondary)
                .fixedSize(horizontal: !isStacked, vertical: false)
            if isChanged {
                Circle()
                    .fill(isInvalid ? Color.liteDanger : Color.liteAccent)
                    .frame(width: dotSize, height: dotSize)
                    .accessibilityLabel(isInvalid ? Text("Invalid value") : Text("Edited"))
            }
        }
        .font(.subheadline)
    }

    @ViewBuilder
    private var editor: some View {
        switch field.editor {
        case .text:
            TextField("Not set", text: $text)
                .textInputAutocapitalization(.never)
        case .multiline:
            TextField("Not set", text: $text, axis: .vertical)
                .lineLimit(2...8)
        case .list:
            TextField("Not set", text: $text, axis: .vertical)
                .lineLimit(3...12)
        case .decimal:
            TextField("Not set", text: $text)
                .keyboardType(.decimalPad)
        case .integer:
            TextField("Not set", text: $text)
                .keyboardType(.numberPad)
        case .choice(let choices):
            Picker(field.label, selection: $text) {
                if !field.isRequired || text.isEmpty { Text("None").tag("") }
                ForEach(choices) { Text($0.label).tag($0.value) }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .tint(.primary)
        }
    }
}
