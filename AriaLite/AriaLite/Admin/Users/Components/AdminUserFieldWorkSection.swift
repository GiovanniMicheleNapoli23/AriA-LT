//
//  AdminUserFieldWorkSection.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Le specialità (una pagina di modifica) e "Assign a work order" (un foglio): per un lavoratore sul campo (§5.4);
//  l'assegnazione solo se è attivo.
//

import SwiftUI

struct AdminUserFieldWorkSection: View {
    let viewModel: AdminUserDetailViewModel

    var body: some View {
        let controls = viewModel.controls
        if controls.specialties || controls.assignWorkOrder {
            Section {
                if controls.specialties {
                    NavigationLink {
                        AdminUserSpecialtiesPage(viewModel: viewModel)
                    } label: {
                        LabeledContent("Specialties") { Text(verbatim: viewModel.specialtiesSummary) }
                    }
                    .disabled(!viewModel.specialtiesReady)
                }
                if controls.assignWorkOrder {
                    Button {
                        viewModel.startAssigning()
                    } label: {
                        Label("Assign a work order", systemImage: "list.clipboard")
                    }
                    .disabled(viewModel.isWorking)
                }
            }
        }
    }
}
