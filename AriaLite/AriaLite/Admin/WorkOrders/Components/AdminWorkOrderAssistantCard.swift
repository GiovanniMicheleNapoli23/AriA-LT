//
//  AdminWorkOrderAssistantCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Una risposta dell'assistente AI: l'azione chiesta, il testo, i campi proposti, gli elenchi (passi,
//  sicurezza, attrezzi, ricambi) e i pulsanti per portarli sull'ordine. Cosa si può applicare lo decide
//  il view model; qui solo il disegno.
//

import SwiftUI

struct AdminWorkOrderAssistantCard: View {
    let entry: AdminWorkOrderAssistantEntry
    let rows: [AdminWorkOrderAssistantFieldRow]
    let canApplyFields: Bool
    let canUseTextAsDescription: Bool
    let canAppendToNotes: Bool
    let isApplying: Bool
    let isBusy: Bool
    let onApply: (AdminWorkOrderAssistantApply) -> Void
    let onCopy: () -> Void

    private var suggestion: AdminWorkOrderAISuggestion { entry.answer.suggestion }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            if let text = entry.answer.text {
                AriaFormattedTextView(text: text, collapsible: true)
                    .font(.subheadline)
            }
            if let description = suggestion.description {
                section(String(localized: "Proposed description")) {
                    AriaFormattedTextView(text: description, collapsible: true).font(.subheadline)
                }
            }
            if !rows.isEmpty { fieldRows }
            list(String(localized: "Steps"), suggestion.steps, numbered: true)
            list(String(localized: "Safety"), suggestion.safetyWarnings, numbered: false)
            list(String(localized: "Tools"), suggestion.toolsNeeded, numbered: false)
            list(String(localized: "Parts"), suggestion.partsNeeded, numbered: false)
            if let notes = suggestion.notes {
                section(String(localized: "Proposed notes")) {
                    Text(notes).font(.subheadline).textSelection(.enabled)
                }
            }
            if let raw = entry.answer.raw {
                Text(raw)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            actions
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Label(entry.title, systemImage: entry.systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.liteText)
                Spacer(minLength: 8)
                Text(entry.date, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            if let prompt = entry.prompt {
                Text("“\(prompt)”")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
    }

    private var fieldRows: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(rows) { row in
                HStack(alignment: .firstTextBaseline) {
                    Text(row.label).foregroundStyle(.secondary)
                    Spacer(minLength: 8)
                    Text(row.value)
                        .fontWeight(row.unchanged ? .regular : .semibold)
                        .foregroundStyle(row.unchanged ? Color.secondary : Color.primary)
                        .multilineTextAlignment(.trailing)
                }
                .font(.subheadline)
            }
        }
        .padding(10)
        .background(Color.liteAccent.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private func list(_ title: String, _ items: [String], numbered: Bool) -> some View {
        if !items.isEmpty {
            section(title) {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(numbered ? "\(index + 1)." : "•")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                            Text(item).fixedSize(horizontal: false, vertical: true)
                        }
                        .font(.subheadline)
                    }
                }
                .textSelection(.enabled)
            }
        }
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            content()
        }
    }

    // MARK: Azioni

    private var actions: some View {
        HStack(alignment: .center, spacing: 8) {
            // I pulsanti stanno in fila se ci stanno, altrimenti uno sotto l'altro.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { applyButtons }
                VStack(alignment: .leading, spacing: 6) { applyButtons }
            }
            Spacer(minLength: 0)
            if isApplying { ProgressView().controlSize(.small) }
            Button("Copy", systemImage: "doc.on.doc", action: onCopy)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
        }
        .font(.footnote.weight(.semibold))
        .padding(.top, 2)
    }

    @ViewBuilder
    private var applyButtons: some View {
        if canApplyFields { applyButton(.fields, title: "Apply", systemImage: "checkmark.circle") }
        if canUseTextAsDescription {
            applyButton(.textAsDescription, title: "Use as description", systemImage: "text.badge.checkmark")
        }
        if canAppendToNotes { applyButton(.appendToNotes, title: "Add to notes", systemImage: "note.text.badge.plus") }
    }

    @ViewBuilder
    private func applyButton(_ kind: AdminWorkOrderAssistantApply, title: LocalizedStringKey, systemImage: String) -> some View {
        if entry.applied.contains(kind) {
            Label("Applied", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        } else {
            Button(title, systemImage: systemImage) { onApply(kind) }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(Color.liteAccent)
                .disabled(isBusy)
        }
    }
}
