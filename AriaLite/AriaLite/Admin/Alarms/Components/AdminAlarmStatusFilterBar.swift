//
//  AdminAlarmStatusFilterBar.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La fila di filtri sopra la lista: un chip per ogni stato (Approved è quello di partenza, come sul server).
//  Scorre in orizzontale se non ci sta.
//

import SwiftUI

struct AdminAlarmStatusFilterBar: View {
    let viewModel: AdminAlarmsViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(AdminAlarmStatus.allCases) { status in
                    let isSelected = viewModel.statusFilter == status
                    Button {
                        withAnimation(.snappy) { viewModel.selectStatus(status) }
                    } label: {
                        AdminAlarmStatusChip(status: status, isSelected: isSelected)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 4)
        }
        .scrollClipDisabled()
    }
}
