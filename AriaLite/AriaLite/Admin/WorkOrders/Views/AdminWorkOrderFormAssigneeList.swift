//
//  AdminWorkOrderFormAssigneeList.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La scelta dell'assegnatario dal form: gli operatori sul campo (con pallino di disponibilità e lavori
//  aperti) e le persone dell'azienda. Si cerca, si tocca una voce e si torna indietro; "None" toglie la scelta.
//

import SwiftUI

struct AdminWorkOrderFormAssigneeList: View {
    let operators: [AdminWorkOrderFormAssignee]
    let users: [AdminWorkOrderFormAssignee]
    let selection: String?
    let onSelect: (String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        let operators = AdminWorkOrderFormAssignee.matching(query, in: operators)
        let users = AdminWorkOrderFormAssignee.matching(query, in: users)
        List {
            Button { pick(nil) } label: {
                HStack {
                    Text("None").foregroundStyle(.primary)
                    Spacer()
                    if selection == nil { checkmark }
                }
                .contentShape(Rectangle())
            }
            if !operators.isEmpty {
                Section("Field operators") {
                    ForEach(operators) { row($0) }
                }
            }
            if !users.isEmpty {
                Section("Users") {
                    ForEach(users) { row($0) }
                }
            }
        }
        .listStyle(.insetGrouped)
        .environment(\.defaultMinListRowHeight, 40)
        .overlay {
            if self.operators.isEmpty && self.users.isEmpty {
                ContentUnavailableView("Nothing to choose from", systemImage: "tray")
            }
        }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always))
        .navigationTitle("Assignee")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func pick(_ id: String?) {
        onSelect(id)
        dismiss()
    }

    private func row(_ item: AdminWorkOrderFormAssignee) -> some View {
        Button { pick(item.id) } label: {
            HStack(spacing: 10) {
                if item.workload != nil {
                    AdminWorkOrderFormAvailabilityDot(availability: item.availability)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.title).foregroundStyle(.primary)
                    if let subtitle = item.subtitle, !subtitle.isEmpty {
                        Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                if let workload = item.workload {
                    Text(workload)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                if item.id == selection { checkmark }
            }
            .contentShape(Rectangle())
        }
    }

    private var checkmark: some View {
        Image(systemName: "checkmark").foregroundStyle(Color.liteAccent).fontWeight(.semibold)
    }
}

/// Il pallino di disponibilità di un operatore: verde disponibile, arancio occupato, grigio fuori turno.
struct AdminWorkOrderFormAvailabilityDot: View {
    let availability: AriaAvailability?

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .accessibilityLabel(Text(availability?.localized ?? String(localized: "Unknown")))
    }

    private var color: Color {
        switch availability {
        case .available?: .green
        case .busy?: .orange
        case .offDuty?: .gray
        case nil: .gray.opacity(0.4)
        }
    }
}
