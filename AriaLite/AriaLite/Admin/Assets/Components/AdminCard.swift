//
//  AdminCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Una sezione del dettaglio: titolo con icona, un'azione facoltativa a destra e il contenuto,
//  sul vetro delle schede dell'app.
//

import SwiftUI

struct AdminCard<Accessory: View, Content: View>: View {
    let title: LocalizedStringKey
    let systemImage: String
    @ViewBuilder var accessory: Accessory
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Label(title, systemImage: systemImage)
                    .font(.headline)
                    .labelStyle(AdminCardTitleStyle())
                Spacer(minLength: 8)
                accessory
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
    }
}

extension AdminCard where Accessory == EmptyView {
    init(title: LocalizedStringKey, systemImage: String, @ViewBuilder content: () -> Content) {
        self.init(title: title, systemImage: systemImage, accessory: { EmptyView() }, content: content)
    }
}

/// Icona nel colore dell'app, titolo in quello del testo.
private struct AdminCardTitleStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            configuration.icon
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.liteAccent)
            configuration.title
        }
    }
}
