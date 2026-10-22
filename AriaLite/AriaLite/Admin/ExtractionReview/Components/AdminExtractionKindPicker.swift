//
//  AdminExtractionKindPicker.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il tipo da rivedere (asset, allarmi, piani, ricambi) con il numero dei pending. Segmentato quando
//  ci sta; con il testo grande diventa un menu, così le etichette non si tagliano.
//

import SwiftUI

struct AdminExtractionKindPicker: View {
    @Bindable var viewModel: AdminExtractionReviewViewModel

    var body: some View {
        ViewThatFits(in: .horizontal) {
            Picker("Type", selection: $viewModel.kind) {
                ForEach(AdminExtractionKind.allCases) { kind in
                    Text(viewModel.segmentTitle(kind)).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            .fixedSize()

            Menu {
                Picker("Type", selection: $viewModel.kind) {
                    ForEach(AdminExtractionKind.allCases) { kind in
                        Label(viewModel.segmentTitle(kind), systemImage: kind.systemImage).tag(kind)
                    }
                }
            } label: {
                AdminFilterChip(title: "Type", value: viewModel.segmentTitle(viewModel.kind), isActive: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
