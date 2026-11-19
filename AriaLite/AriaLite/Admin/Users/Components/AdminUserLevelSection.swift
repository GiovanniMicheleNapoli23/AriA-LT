//
//  AdminUserLevelSection.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Il livello della persona (§5.2): una riga che apre la pagina di scelta, oppure il livello come testo per chi
//  non può cambiarlo.
//

import SwiftUI

struct AdminUserLevelSection: View {
    let viewModel: AdminUserDetailViewModel

    var body: some View {
        Section {
            if viewModel.levelOptions != nil {
                NavigationLink {
                    AdminUserLevelPage(viewModel: viewModel)
                } label: {
                    LabeledContent("Level") { Text(verbatim: viewModel.levelText) }
                }
            } else {
                LabeledContent("Level") { Text(verbatim: viewModel.levelText) }
            }
        }
    }
}
