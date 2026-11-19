//
//  AdminUserLevelPage.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  La pagina di scelta del livello, come un selettore di Impostazioni: Owner, ruoli alti, ruoli bassi, nessun
//  ruolo. Le voci spente restano grigie con il loro motivo. La spunta viene sempre dalla riga: dopo un rifiuto
//  mostra di nuovo il livello salvato. Qui stanno anche le conferme e il foglio del nuovo ruolo.
//

import SwiftUI

struct AdminUserLevelPage: View {
    let viewModel: AdminUserDetailViewModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            ForEach(viewModel.levelGroups) { group in
                Section {
                    ForEach(group.options) { option in
                        optionRow(option)
                    }
                } header: {
                    if let title = group.title { Text(verbatim: title) }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .liteBackground()
        .ariaReadableWidth()
        .navigationTitle("Level")
        .navigationBarTitleDisplayMode(.inline)
        .adminUsersToast(viewModel.owner)
        .onChange(of: viewModel.levelPageCloses) { dismiss() }
        .alert(Text(verbatim: levelAlert?.title ?? ""), isPresented: confirmationBinding,
               presenting: viewModel.levelConfirmation) { item in
            let content = viewModel.levelAlert(item)
            Button(content.confirmTitle, role: content.isDestructive ? .destructive : nil) {
                viewModel.confirmLevel(item)
            }
            Button("Cancel", role: .cancel) {}
        } message: { item in
            Text(verbatim: viewModel.levelAlert(item).message)
        }
        .sheet(item: demotionBinding, onDismiss: { viewModel.demotionSheetDismissed() }) { _ in
            AdminUserDemotionSheet(viewModel: viewModel)
        }
    }

    private var levelAlert: AdminUserAlertContent? {
        viewModel.levelConfirmation.map(viewModel.levelAlert)
    }

    private var confirmationBinding: Binding<Bool> {
        Binding(get: { viewModel.levelConfirmation != nil },
                set: { if !$0 { viewModel.levelConfirmation = nil } })
    }

    private var demotionBinding: Binding<AdminUserDemotion?> {
        Binding(get: { viewModel.demotion }, set: { viewModel.demotion = $0 })
    }

    private func optionRow(_ option: AdminUserLevelOption) -> some View {
        Button {
            viewModel.chooseLevel(option.value)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: option.title)
                    if let hint = option.hint {
                        Text(verbatim: hint.text)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if option.value == viewModel.currentLevel {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.liteAccent)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
        }
        .foregroundStyle(option.isDisabled ? Color.secondary : Color.primary)
        .disabled(option.isDisabled || viewModel.isWorking)
        .accessibilityAddTraits(option.value == viewModel.currentLevel ? .isSelected : [])
    }
}
