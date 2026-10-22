//
//  AdminCompanySettingsDangerZone.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La "Danger zone" in rosso: cancellare i dati di uno stabilimento (si sceglie dal menu) o di tutta l'azienda.
//  Ogni pulsante apre la conferma nella VM; qui solo si mostrano.
//

import SwiftUI

struct AdminCompanySettingsDangerZone: View {
    let viewModel: AdminCompanySettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Danger zone", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.red)
            Text("Deleting data can't be undone.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Menu {
                ForEach(viewModel.plants) { plant in
                    Button(plant.name, role: .destructive) { viewModel.requestPlantDeletion(plant) }
                }
            } label: {
                Label("Delete plant data", systemImage: "building")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .disabled(!viewModel.canDeletePlant)

            Button(role: .destructive) {
                viewModel.requestCompanyDeletion()
            } label: {
                Label("Delete all company data", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(!viewModel.canDeleteCompany)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).stroke(Color.red.opacity(0.5), lineWidth: 1))
    }
}
