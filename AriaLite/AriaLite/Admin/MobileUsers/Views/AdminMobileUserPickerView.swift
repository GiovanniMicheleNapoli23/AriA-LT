//
//  AdminMobileUserPickerView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il foglio "Add existing user": gli utenti dell'azienda che non sono ancora operatori, con ricerca.
//  Toccarne uno lo promuove a operatore mobile (occupa un posto).
//

import SwiftUI

struct AdminMobileUserPickerView: View {
    @State private var viewModel: AdminMobileUserPickerViewModel

    @Environment(\.dismiss) private var dismiss

    init(viewModel: AdminMobileUserPickerViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            List {
                if let message = viewModel.errorMessage {
                    Section {
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                if viewModel.hasLoaded {
                    Section {
                        ForEach(viewModel.visibleCandidates) { candidate in
                            Button { add(candidate) } label: { row(candidate) }
                                .disabled(viewModel.addingId != nil)
                        }
                    } footer: {
                        Text("Only active users who aren't mobile operators yet are listed.")
                    }
                }
            }
            .overlay { overlay }
            .navigationTitle("Add existing user")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $viewModel.searchText, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: Text("Name or email"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .tint(Color.liteAccent)
                        .disabled(viewModel.addingId != nil)
                }
            }
            .task { await viewModel.load() }
            .refreshable { await viewModel.load() }
        }
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(viewModel.addingId != nil)
    }

    private func row(_ candidate: AdminMobileUserCandidate) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(candidate.displayName)
                    .font(.body)
                    .foregroundStyle(.primary)
                let subtitle = viewModel.subtitle(for: candidate)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            if viewModel.addingId == candidate.userId {
                ProgressView()
            } else {
                Image(systemName: "plus.circle")
                    .foregroundStyle(Color.liteAccent)
            }
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var overlay: some View {
        if !viewModel.hasLoaded {
            if viewModel.isLoading {
                ProgressView()
            } else if let message = viewModel.errorMessage {
                ContentUnavailableView {
                    Label("Can't load the users", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                } actions: {
                    Button("Retry") { Task { await viewModel.load() } }
                }
            }
        } else if viewModel.visibleCandidates.isEmpty {
            if viewModel.isSearching {
                ContentUnavailableView.search(text: viewModel.searchText)
            } else {
                ContentUnavailableView("No users to add", systemImage: "person.2.slash",
                                       description: Text("Everyone in the company is already a mobile operator."))
            }
        }
    }

    private func add(_ candidate: AdminMobileUserCandidate) {
        Task { if await viewModel.add(candidate) { dismiss() } }
    }
}
