//
//  AdminTaskboardPeopleBoard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 27/10/26.
//
//  La bacheca per persona: una sezione per chi esegue le task aperte (persone, squadre, non assegnate).
//  Sta dentro lo scroll della pagina, come la lista.
//

import SwiftUI

struct AdminTaskboardPeopleBoard<CardView: View>: View {
    let viewModel: AdminTaskboardViewModel
    @ViewBuilder var card: (AdminWorkOrderRowItem) -> CardView

    var body: some View {
        let groups = viewModel.peopleGroups
        VStack(alignment: .leading, spacing: 24) {
            if groups.isEmpty {
                AdminSectionNotice(text: String(localized: "No open tasks."), systemImage: "tray")
            }
            ForEach(groups) { group in
                AdminTaskboardPersonSection(group: group, card: card)
            }
        }
        .padding(.horizontal, 16)
    }
}
