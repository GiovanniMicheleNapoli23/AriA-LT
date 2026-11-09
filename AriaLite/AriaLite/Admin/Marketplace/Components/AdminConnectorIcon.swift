//
//  AdminConnectorIcon.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  L'icona di un connettore: il logo del marchio se c'è, altrimenti un simbolo per i sistemi noti o l'iniziale.
//  Il quadrato cresce col Dynamic Type come il testo accanto.
//

import SwiftUI

struct AdminConnectorIcon: View {
    let provider: String
    let name: String
    /// Sostituisce il lato scalato di 44 (come in AdminMarketplaceGlyph).
    var side: CGFloat? = nil
    @ScaledMetric(relativeTo: .title3) private var scaledSide: CGFloat = 44
    @Environment(\.colorScheme) private var colorScheme

    private var resolvedSide: CGFloat { side ?? scaledSide }

    /// Il colore del marchio; senza, l'accento dell'app. Nel dark mode un marchio molto scuro diventa `.primary`.
    private func tintColor(for brand: AdminConnectorBrand) -> Color {
        guard let color = brand.color else { return .liteAccent }
        if colorScheme == .dark, let luminance = brand.relativeLuminance, luminance < 0.2 {
            return .primary
        }
        return color
    }

    /// Simboli per famiglia di sistema: la parola chiave basta anche per slug come `google-drive-acme`.
    private var systemImage: String? {
        let key = provider.lowercased()
        let symbols: [(String, String)] = [
            ("maintainx", "wrench.and.screwdriver.fill"), ("hubspot", "person.2.fill"), ("salesforce", "cloud.fill"),
            ("gmail", "envelope.fill"), ("mail", "envelope.fill"), ("outlook", "envelope.fill"),
            ("calendar", "calendar"), ("drive", "folder.fill"), ("sharepoint", "folder.fill"),
            ("notion", "doc.text.fill"), ("confluence", "doc.text.fill"), ("slack", "bubble.left.and.bubble.right.fill"),
            ("teams", "bubble.left.and.bubble.right.fill"), ("jira", "checklist"), ("github", "chevron.left.forwardslash.chevron.right"),
            ("odoo", "shippingbox.fill"), ("erpipe", "shippingbox.fill"), ("sap", "shippingbox.fill"),
            ("sql", "cylinder.split.1x2.fill"), ("database", "cylinder.split.1x2.fill")
        ]
        return symbols.first { key.contains($0.0) }?.1
    }

    var body: some View {
        let brand = AdminConnectorBrand.forProvider(provider)
        let tint = tintColor(for: brand)
        Group {
            if let imageName = brand.imageName {
                // Il colore vale solo per le immagini monocrome (template); i loghi a colori restano originali.
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .padding(resolvedSide * 0.22)
                    .foregroundStyle(tint)
            } else if let systemImage {
                Image(systemName: systemImage)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(tint)
            } else {
                Text(String(name.prefix(1)).uppercased())
                    .font(.title3.weight(.bold))
                    .foregroundStyle(tint)
            }
        }
        .frame(width: resolvedSide, height: resolvedSide)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: resolvedSide * 0.28, style: .continuous))
        .accessibilityHidden(true)
    }
}
