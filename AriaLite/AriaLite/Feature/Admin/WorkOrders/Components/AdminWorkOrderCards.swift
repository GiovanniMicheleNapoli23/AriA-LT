//
//  AdminWorkOrderCards.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le schede del dettaglio admin: un gruppo di campi "etichetta — valore", un testo lungo, un elenco
//  puntato (attrezzi, ricambi) e le avvertenze di sicurezza.
//

import SwiftUI

/// Titolo con icona in testa a ogni scheda.
struct AdminWorkOrderCardTitle: View {
    let title: String
    let icon: String

    var body: some View {
        Label(title, systemImage: icon)
            .font(.headline)
            .foregroundStyle(Color.liteText)
    }
}

struct AdminWorkOrderFieldCard: View {
    let group: AdminWorkOrderFieldGroup

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            AdminWorkOrderCardTitle(title: group.title, icon: group.icon)
                .padding(.bottom, 4)
            ForEach(Array(group.fields.enumerated()), id: \.element.id) { index, field in
                // Etichetta e valore sulla stessa riga se ci stanno, altrimenti il valore va sotto.
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(field.label).foregroundStyle(.secondary)
                        Spacer(minLength: 12)
                        value(field).multilineTextAlignment(.trailing)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(field.label).foregroundStyle(.secondary)
                        value(field)
                    }
                }
                .font(.subheadline)
                .padding(.vertical, 8)
                if index < group.fields.count - 1 { Divider() }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
    }

    private func value(_ field: AdminWorkOrderField) -> some View {
        Text(field.value)
            .foregroundStyle(field.isAlert ? Color.red : Color.primary)
            .textSelection(.enabled)
    }
}

struct AdminWorkOrderTextCard: View {
    let block: AdminWorkOrderTextBlock

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            AdminWorkOrderCardTitle(title: block.title, icon: block.icon)
            Text(block.text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
    }
}

/// Attrezzi e ricambi della procedura.
struct AdminWorkOrderListCard: View {
    let sections: [(title: String, icon: String, items: [String])]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(sections, id: \.title) { section in
                VStack(alignment: .leading, spacing: 6) {
                    AdminWorkOrderCardTitle(title: section.title, icon: section.icon)
                    ForEach(Array(section.items.enumerated()), id: \.offset) { _, item in
                        Text(verbatim: "• \(item)").font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
    }
}

struct AdminWorkOrderSafetyCard: View {
    let warnings: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Safety warnings", systemImage: "exclamationmark.shield.fill")
                .font(.headline)
                .foregroundStyle(.orange)
            ForEach(Array(warnings.enumerated()), id: \.offset) { _, warning in
                Text(warning)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.orange.opacity(0.3), lineWidth: 1))
    }
}
