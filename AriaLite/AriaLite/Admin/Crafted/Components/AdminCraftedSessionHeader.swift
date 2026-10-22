//
//  AdminCraftedSessionHeader.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  L'intestazione di una sessione conclusa: titolo, verdetto con la sua fonte e i fatti principali
//  (allarme, data, review dell'operatore).
//

import SwiftUI

struct AdminCraftedSessionHeader: View {
    let viewModel: AdminCraftedSessionViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(viewModel.title)
                    .font(.title2.weight(.bold))
                Label(viewModel.verdictLabel, systemImage: AdminCraftedVerdict.systemImage(viewModel.review.verdict))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AdminCraftedVerdict.tint(viewModel.review.verdict))
                if let source = viewModel.verdictSourceLabel {
                    Text(source)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            if !viewModel.facts.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(viewModel.facts) { field in
                        AdminFieldRow(field: field, showsDivider: field != viewModel.facts.last)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
                .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }
}
