//
//  AdminUserLevelPickerPage.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  La pagina del livello, come un selettore di Impostazioni: le voci a gruppi (Owner, "High roles", "Low roles", "No
//  role"), la scelta col segno di spunta e, per una voce spenta, il motivo ("3 owners already"). Si chiude scegliendo.
//

import SwiftUI

struct AdminUserLevelPickerPage: View {
    let groups: [AdminUserAddViewModel.LevelGroup]
    @Binding var selection: AdminUserLevelValue

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            ForEach(groups) { group in
                Section {
                    ForEach(group.options) { option in
                        Button {
                            selection = option.value
                            dismiss()
                        } label: {
                            optionRow(option)
                        }
                        .disabled(option.isDisabled)
                    }
                } header: {
                    if let title = group.title { Text(verbatim: title) }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .liteBackground()
        .navigationTitle("Level")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func optionRow(_ option: AdminUserLevelOption) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: option.title)
                    .foregroundStyle(option.isDisabled ? Color.secondary : Color.primary)
                if let hint = option.hint {
                    Text(verbatim: hint.text)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            if option.value == selection {
                Image(systemName: "checkmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.liteAccent)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(option.value == selection ? .isSelected : [])
    }
}
