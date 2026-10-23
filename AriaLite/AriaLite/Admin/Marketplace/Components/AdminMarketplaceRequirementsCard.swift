//
//  AdminMarketplaceRequirementsCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  La scheda 'Richiede': i connettori che l'elemento si aspetta, con "x/y collegati" e se ciascuno è già collegato.
//

import SwiftUI

struct AdminMarketplaceRequirementsCard: View {
    let viewModel: AdminMarketplaceItemDetailViewModel

    var body: some View {
        let requirements = viewModel.requirements
        AdminMarketplaceDetailCard(title: Text("Requires"), systemImage: "link") {
            Text(verbatim: viewModel.requiresSummary)
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.secondary)
        } content: {
            VStack(spacing: 0) {
                ForEach(requirements) { requirement in
                    VStack(spacing: 0) {
                        ViewThatFits(in: .horizontal) {
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                Text(verbatim: requirement.name).font(.subheadline.weight(.medium))
                                Spacer(minLength: 12)
                                status(requirement)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(verbatim: requirement.name).font(.subheadline.weight(.medium))
                                status(requirement)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 10)
                        if requirement.id != requirements.last?.id { Divider() }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func status(_ requirement: AdminMarketplaceRequirement) -> some View {
        if requirement.isConnected {
            Label("Connected", systemImage: "checkmark")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.green)
        } else {
            Text("Not connected")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}
