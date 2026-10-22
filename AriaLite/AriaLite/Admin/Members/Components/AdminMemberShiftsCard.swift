//
//  AdminMemberShiftsCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I prossimi turni del membro, per data, con "Assign shift" per aggiungerne uno. Ogni riga ha il menu per
//  toglierlo (con conferma, gestita dal view model).
//

import SwiftUI

struct AdminMemberShiftsCard: View {
    let viewModel: AdminMemberDetailViewModel

    var body: some View {
        AdminCard(title: "Upcoming shifts", systemImage: "calendar") {
            Button("Assign shift", systemImage: "plus") { viewModel.startAssigning() }
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.borderless)
                .foregroundStyle(Color.liteAccent)
        } content: {
            VStack(alignment: .leading, spacing: 12) {
                Text(verbatim: viewModel.horizonText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let failure = viewModel.shiftsFailure, !viewModel.hasLoadedShifts {
                    AdminMemberFailureNote(failure: failure)
                } else if !viewModel.hasLoadedShifts {
                    ProgressView().frame(maxWidth: .infinity)
                } else if viewModel.shifts.isEmpty {
                    Text("No shifts assigned in this period.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.shifts) { shift in
                        if shift.id != viewModel.shifts.first?.id { Divider() }
                        AdminMemberShiftRow(shift: shift, onRemove: { viewModel.confirmRemoval(of: shift) })
                    }
                }
            }
        }
        .disabled(viewModel.isRemoving)
    }
}
