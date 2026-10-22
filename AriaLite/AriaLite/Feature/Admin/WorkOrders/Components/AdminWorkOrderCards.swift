//
//  AdminWorkOrderCards.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le schede compatte del dettaglio admin: un gruppo di campi su due colonne (etichetta sopra il valore), un
//  testo lungo, attrezzi e ricambi in una riga ciascuno, le avvertenze di sicurezza e la traduzione dei testi.
//

import SwiftUI

/// Titolo con icona in testa a ogni scheda.
struct AdminWorkOrderCardTitle: View {
    let title: String
    let icon: String

    var body: some View {
        Label(title, systemImage: icon)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.liteText)
    }
}

/// Lo stile comune delle schede: margini stretti, vetro, angoli da 12.
private struct AdminWorkOrderCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .ariaGlass(in: RoundedRectangle(cornerRadius: 12))
    }
}

extension View {
    func adminWorkOrderCard() -> some View { modifier(AdminWorkOrderCardStyle()) }
}

struct AdminWorkOrderFieldCard: View {
    let group: AdminWorkOrderFieldGroup

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Due colonne; una sola col testo molto grande.
    private var columns: [GridItem] {
        let count = dynamicTypeSize.isAccessibilitySize ? 1 : 2
        return Array(repeating: GridItem(.flexible(), spacing: 12, alignment: .topLeading), count: count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AdminWorkOrderCardTitle(title: group.title, icon: group.icon)
            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                ForEach(group.fields) { field in
                    VStack(alignment: .leading, spacing: 1) {
                        Text(field.label)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(field.value)
                            .font(.footnote)
                            .foregroundStyle(field.isAlert ? Color.red : Color.primary)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .adminWorkOrderCard()
    }
}

struct AdminWorkOrderTextCard: View {
    let block: AdminWorkOrderTextBlock

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            AdminWorkOrderCardTitle(title: block.title, icon: block.icon)
            Text(block.text)
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .adminWorkOrderCard()
    }
}

/// Attrezzi e ricambi della procedura: un elenco per riga, separato da virgole.
struct AdminWorkOrderListCard: View {
    let sections: [(title: String, icon: String, items: [String])]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(sections, id: \.title) { section in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: section.icon)
                        .font(.caption)
                        .foregroundStyle(Color.liteAccent)
                        .accessibilityHidden(true)
                    (Text(section.title).fontWeight(.semibold) + Text(verbatim: ": ")
                        + Text(section.items.formatted(.list(type: .and, width: .narrow))))
                        .font(.footnote)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .adminWorkOrderCard()
    }
}

struct AdminWorkOrderSafetyCard: View {
    let warnings: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Safety warnings", systemImage: "exclamationmark.shield.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)
            ForEach(Array(warnings.enumerated()), id: \.offset) { _, warning in
                Text(verbatim: "• \(warning)")
                    .font(.footnote)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.orange.opacity(0.3), lineWidth: 1))
    }
}

/// I testi tradotti, in sola lettura, sopra gli originali.
struct AdminWorkOrderTranslationCard: View {
    let translation: AdminWorkOrderTranslation
    let languageName: String
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                AdminWorkOrderCardTitle(title: String(localized: "Translation · \(languageName)"), icon: "translate")
                Spacer(minLength: 8)
                Button("Show original", action: onClose)
                    .font(.caption.weight(.semibold))
            }
            if let title = translation.title {
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .textSelection(.enabled)
            }
            ForEach(translation.blocks) { block in
                VStack(alignment: .leading, spacing: 1) {
                    Text(block.title).font(.caption2).foregroundStyle(.secondary)
                    Text(block.text)
                        .font(.footnote)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.liteAccent.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.liteAccent.opacity(0.25), lineWidth: 1))
    }
}
