//
//  AdminMarketplaceSetFold.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Una voce ripiegabile del set (procedura, allarme, piano, checklist): titolo e un dato in riga, il dettaglio all'apertura.
//

import SwiftUI

struct AdminMarketplaceSetFold<Content: View>: View {
    var code: String?
    let title: String
    var meta: String?
    @ViewBuilder var content: Content

    var body: some View {
        DisclosureGroup {
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 10)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                if let code { AdminMarketplaceCodeBadge(code: code) }
                Text(verbatim: title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                if let meta {
                    Text(verbatim: meta)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .tint(Color.liteAccent)
        .padding(12)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
