//
//  AdminMarketplaceFactsCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  La scheda 'Dettagli': licenza, produttore, editore, area, dimensione. Con il testo molto grande il valore va sotto l'etichetta.
//

import SwiftUI

struct AdminMarketplaceFactsCard: View {
    let facts: [AdminMarketplaceFact]

    var body: some View {
        AdminMarketplaceDetailCard(title: Text("Details"), systemImage: "info.circle") {
            VStack(spacing: 0) {
                ForEach(facts) { fact in
                    VStack(spacing: 0) {
                        ViewThatFits(in: .horizontal) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(verbatim: fact.label).foregroundStyle(.secondary)
                                Spacer(minLength: 12)
                                Text(verbatim: fact.value).multilineTextAlignment(.trailing)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(verbatim: fact.label).foregroundStyle(.secondary)
                                Text(verbatim: fact.value)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .font(.subheadline)
                        .padding(.vertical, 10)
                        if fact.id != facts.last?.id { Divider() }
                    }
                }
            }
        }
    }
}
