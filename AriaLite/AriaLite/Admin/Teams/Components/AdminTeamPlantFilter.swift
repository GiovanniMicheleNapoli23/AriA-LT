//
//  AdminTeamPlantFilter.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il filtro per stabilimento sopra la lista: un menu con "All plants" e gli stabilimenti che hanno squadre.
//

import SwiftUI

struct AdminTeamPlantFilter: View {
    @Bindable var viewModel: AdminTeamsViewModel

    var body: some View {
        Menu {
            Picker("Plant", selection: $viewModel.plantFilter) {
                Text("All plants").tag(String?.none)
                ForEach(viewModel.plantOptions) { plant in
                    Text(verbatim: plant.name).tag(Optional(plant.id))
                }
            }
        } label: {
            Label {
                Text(verbatim: viewModel.plantFilterTitle)
            } icon: {
                Image(systemName: "building.2")
            }
            .font(.footnote.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .ariaGlass(in: Capsule(), interactive: true)
        }
        .tint(.primary)
    }
}
