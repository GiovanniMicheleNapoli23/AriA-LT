//
//  AdminConnectorIcon.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  L'icona di un connettore: un simbolo per i sistemi noti, altrimenti l'iniziale del nome.
//  Il quadrato cresce col Dynamic Type come il testo accanto.
//

import SwiftUI

struct AdminConnectorIcon: View {
    let provider: String
    let name: String
    @ScaledMetric(relativeTo: .title3) private var side: CGFloat = 44

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
        Group {
            if let systemImage {
                Image(systemName: systemImage)
            } else {
                Text(String(name.prefix(1)).uppercased())
            }
        }
        .font(.title3.weight(.bold))
        .foregroundStyle(Color.liteAccent)
        .frame(width: side, height: side)
        .background(Color.liteAccent.opacity(0.1), in: RoundedRectangle(cornerRadius: side * 0.28, style: .continuous))
        .accessibilityHidden(true)
    }
}
