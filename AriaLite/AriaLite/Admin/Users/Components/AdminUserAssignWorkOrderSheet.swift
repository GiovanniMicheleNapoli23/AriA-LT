//
//  AdminUserAssignWorkOrderSheet.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  "Assign a work order": gli ordini pianificati che nessuno tiene ancora, con la ricerca per titolo (§5.4).
//  Il tocco su un ordine lo assegna alla persona e chiude il foglio.
//

import SwiftUI

struct AdminUserAssignWorkOrderSheet: View {
    @Bindable var viewModel: AdminUserAssignWorkOrderViewModel
    let owner: AdminUsersViewModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else if viewModel.loadFailed {
                        Text(verbatim: AdminUsersFailure.generic)
                            .foregroundStyle(.secondary)
                    } else if viewModel.isEmpty {
                        Text("No planned work orders are waiting for someone.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.visibleOrders) { order in
                            Button {
                                viewModel.pick(order)
                            } label: {
                                Label {
                                    Text(verbatim: order.title)
                                } icon: {
                                    Image(systemName: "list.clipboard")
                                }
                                .contentShape(Rectangle())
                            }
                            .foregroundStyle(.primary)
                            .disabled(viewModel.isAssigning)
                        }
                    }
                } header: {
                    Text("Planned work orders nobody holds yet")
                        .textCase(nil)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .liteBackground()
            .searchable(text: $viewModel.query, prompt: "Search work orders…")
            .navigationTitle("Assign a work order")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .adminUsersToast(owner)
            .task { await viewModel.load() }
            .onChange(of: viewModel.isDone) { _, done in if done { dismiss() } }
        }
        .presentationDetents([.medium, .large])
    }
}
