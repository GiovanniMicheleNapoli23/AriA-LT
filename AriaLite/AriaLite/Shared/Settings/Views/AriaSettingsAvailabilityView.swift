//
//  AriaSettingsAvailabilityView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 20/11/26.
//
//  La disponibilità dell'operatore: decide se l'assegnazione automatica gli manda ordini nuovi. Tre scelte e, sotto,
//  cosa comporta quella attiva.
//

import SwiftUI

struct AriaSettingsAvailabilityView: View {
    let viewModel: AriaSettingsViewModel

    var body: some View {
        List {
            Section {
                ForEach(AriaAvailability.allCases, id: \.self) { option in
                    let isSelected = viewModel.availability == option
                    AriaSettingsChoiceRow(isSelected: isSelected,
                                          isBusy: isSelected && viewModel.isUpdatingAvailability) {
                        viewModel.setAvailability(option)
                    } label: {
                        Label {
                            Text(verbatim: option.localized)
                        } icon: {
                            Image(systemName: option.systemImage).foregroundStyle(option.color)
                        }
                    }
                    .disabled(viewModel.isUpdatingAvailability)
                }
            } footer: {
                Text(verbatim: viewModel.availabilityCaption)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .ariaReadableWidth()
        .liteBackground()
        .sensoryFeedback(.selection, trigger: viewModel.availability)
        .navigationTitle("Availability")
        .navigationBarTitleDisplayMode(.inline)
    }
}
