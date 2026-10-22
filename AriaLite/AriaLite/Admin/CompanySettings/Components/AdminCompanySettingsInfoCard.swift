//
//  AdminCompanySettingsInfoCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La scheda in cima: l'azienda attiva e quanti stabilimenti ha.
//

import SwiftUI

struct AdminCompanySettingsInfoCard: View {
    let viewModel: AdminCompanySettingsViewModel

    var body: some View {
        AdminCard(title: "Company", systemImage: "building.2") {
            VStack(alignment: .leading, spacing: 6) {
                Text(viewModel.companyName ?? String(localized: "No company selected"))
                    .font(.title3.weight(.semibold))
                Text("\(viewModel.plantCount) plants")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
