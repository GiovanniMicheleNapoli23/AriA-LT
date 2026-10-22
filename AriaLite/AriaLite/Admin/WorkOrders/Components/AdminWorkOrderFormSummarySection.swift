//
//  AdminWorkOrderFormSummarySection.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un passo nel riepilogo della creazione: quello che è stato scritto, cosa manca in rosso, e "Edit" per
//  tornare a quella pagina.
//

import SwiftUI

struct AdminWorkOrderFormSummarySection: View {
    let group: AdminWorkOrderFormSummaryGroup
    let onEdit: () -> Void

    var body: some View {
        Section {
            if let issue = group.issue {
                Button(action: onEdit) {
                    Label(issue, systemImage: "exclamationmark.circle.fill")
                        .foregroundStyle(.red)
                }
            } else if group.rows.isEmpty {
                Text("Nothing set").foregroundStyle(.tertiary)
            }
            ForEach(group.rows) { row in
                LabeledContent(row.label) {
                    Text(row.value)
                        .lineLimit(3)
                        .multilineTextAlignment(.trailing)
                }
            }
        } header: {
            HStack {
                Label(group.step.title, systemImage: group.step.systemImage)
                Spacer()
                Button("Edit", action: onEdit)
                    .font(.subheadline.weight(.medium))
                    .textCase(nil)
            }
        }
    }
}
