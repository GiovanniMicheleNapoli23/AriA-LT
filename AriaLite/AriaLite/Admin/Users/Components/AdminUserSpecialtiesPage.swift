//
//  AdminUserSpecialtiesPage.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  La pagina delle specialità (§5.4): una riga con spunta per ogni categoria (più i valori che la persona ha già),
//  poi "Save specialties", acceso solo quando l'insieme scelto è diverso da quello salvato. Manda la lista intera.
//

import SwiftUI

struct AdminUserSpecialtiesPage: View {
    let viewModel: AdminUserDetailViewModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                ForEach(viewModel.specialtyChoices, id: \.self) { value in
                    Button {
                        viewModel.toggleSpecialty(value)
                    } label: {
                        HStack {
                            Text(verbatim: AdminUserDetailViewModel.specialtyTitle(value))
                            Spacer()
                            if viewModel.specialtyDraft.contains(value) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.liteAccent)
                                    .accessibilityHidden(true)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .foregroundStyle(.primary)
                    .accessibilityAddTraits(viewModel.specialtyDraft.contains(value) ? .isSelected : [])
                }
            }
            Section {
                Button("Save specialties") { viewModel.saveSpecialties() }
                    .disabled(!viewModel.canSaveSpecialties)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .liteBackground()
        .ariaReadableWidth()
        .navigationTitle("Specialties")
        .navigationBarTitleDisplayMode(.inline)
        .adminUsersToast(viewModel.owner)
        .onAppear { viewModel.startSpecialties() }
        .onChange(of: viewModel.specialtyPageCloses) { dismiss() }
    }
}
