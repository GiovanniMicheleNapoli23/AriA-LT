//
//  AdminUsageRecipientPickerSheet.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  "Add a member": la lista con ricerca dei membri attivi che non sono né sempre avvisati né già aggiunti. Vuota: "Every
//  active member is already notified.". Toccare un membro lo aggiunge e chiude il foglio.
//

import SwiftUI

struct AdminUsageRecipientPickerSheet: View {
    let billing: AdminUsageBillingViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        NavigationStack {
            List {
                if !billing.hasCandidates {
                    Text("Every active member is already notified.").foregroundStyle(.secondary)
                } else {
                    Section {
                        ForEach(billing.candidates(matching: query)) { candidate in
                            Button {
                                billing.addRecipient(candidate.id)
                                dismiss()
                            } label: {
                                HStack(spacing: 8) {
                                    Text(verbatim: candidate.name).foregroundStyle(.primary)
                                    Spacer(minLength: 8)
                                    AdminUsageBillingChip(text: candidate.role)
                                }
                            }
                        }
                    } header: {
                        Text("Active members")
                    }
                }
            }
            .searchable(text: $query, prompt: Text("Search members"))
            .navigationTitle("Add a member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
