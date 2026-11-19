//
//  AdminUsageNoticePeopleSheet.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  "Sent to" di un avviso: i ruoli (Owners, Members) e le persone nominate, scelte fra i membri attivi con una ricerca. Le
//  persone nominate prendono il posto dei ruoli e della lista "Usage notices", per questo avviso soltanto. Una persona
//  scelta che non è più un membro attivo resta in cima, spuntata e "Inactive", per poterla togliere. Il foglio disegna il
//  modello del view model (`peopleList`).
//

import SwiftUI

struct AdminUsageNoticePeopleSheet: View {
    let billing: AdminUsageBillingViewModel
    let notice: AriaNoticeKey

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        let list = billing.peopleList(for: notice, query: query)
        NavigationStack {
            List {
                if let list {
                    Section {
                        ForEach(list.roles) { role in
                            row(title: role.title, checked: role.isOn, chip: nil, inactive: false) {
                                billing.toggleRole(notice, role.role)
                            }
                        }
                        .disabled(list.rolesDisabled)
                    } header: {
                        Text("Roles")
                    } footer: {
                        Text("Named people replace the roles for this notice.")
                    }
                    Section {
                        ForEach(list.former + list.people) { person in
                            row(title: person.name, checked: person.isOn, chip: person.chip, inactive: person.isInactive) {
                                billing.togglePerson(notice, person.id)
                            }
                        }
                    } header: {
                        Text("Active members")
                    }
                }
            }
            .searchable(text: $query, prompt: Text("Search members"))
            .navigationTitle(String(localized: "usage.noticeSettings.sentTo", defaultValue: "Sent to"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func row(title: String, checked: Bool, chip: String?, inactive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(verbatim: title).foregroundStyle(inactive ? Color.secondary : Color.primary)
                Spacer(minLength: 8)
                if let chip { AdminUsageBillingChip(text: chip, tone: inactive ? .over : .normal) }
                Image(systemName: checked ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(checked ? Color.liteAccent : Color.secondary)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityAddTraits(checked ? .isSelected : [])
    }
}
