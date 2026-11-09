//
//  AdminLearnedKnowledgeView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La memoria dell'azienda, come la pagina /settings/memory della web: filtri (stato, stabilimento,
//  autore), ricerca, "+" per un fatto scritto a mano, menu contestuale per moderare. Dettaglio in AdminMemoryFactDetailView.
//

import SwiftUI

struct AdminLearnedKnowledgeView: View {
    @Bindable var viewModel: AdminLearnedKnowledgeViewModel

    @State private var path: [String] = []
    @State private var isCreating = false
    @State private var editForm: AdminMemoryFactFormViewModel?

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    AdminLearnedKnowledgeFilters(viewModel: viewModel)
                    errorPill
                    content
                }
                .padding(.top, 4)
                .padding(.bottom, 24)
                .ariaReadableWidth()
            }
            .refreshable { await viewModel.load() }
            .liteBackground()
            .navigationTitle("Learned knowledge")
            .navigationDestination(for: String.self) { factId in
                AdminMemoryFactDetailView(viewModel: viewModel.makeDetailViewModel(factId: factId))
            }
            .toolbar { toolbar }
            .searchable(text: $viewModel.searchText, prompt: Text("Fact, context, category, author"))
            .sheet(isPresented: $isCreating) {
                AdminMemoryFactFormView(viewModel: viewModel.makeCreateForm()) { viewModel.didCreate($0) }
            }
            .sheet(item: $editForm) { form in
                AdminMemoryFactFormView(viewModel: form) { viewModel.apply($0) }
            }
        }
        .task(id: viewModel.loadKey) { await viewModel.load() }
        // Sullo stack e non sulla lista: valgono anche col dettaglio aperto, che usa le stesse azioni.
        .alert(viewModel.pendingConfirmation?.title ?? "", isPresented: $viewModel.showsConfirmation,
               presenting: viewModel.pendingConfirmation) { confirmation in
            Button(confirmation.actionTitle, role: .destructive) { Task { await viewModel.confirm(confirmation) } }
            Button("Cancel", role: .cancel) {}
        } message: { confirmation in
            Text(confirmation.message)
        }
        .alert("Couldn't update the fact", isPresented: $viewModel.showsActionError) {
            Button("OK") {}
        } message: {
            Text(viewModel.actionError ?? "")
        }
        .alert("Already known", isPresented: $viewModel.showsActionNotice) {
            Button("OK") {}
        } message: {
            Text(viewModel.actionNotice ?? "")
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) { AriaSidebarButton() }
        if viewModel.hasTranslations {
            ToolbarItem(placement: .topBarTrailing) {
                Toggle(isOn: $viewModel.showsOriginals) {
                    Label("Show original text", systemImage: "translate")
                }
                .toggleStyle(.button)
                .tint(Color.liteAccent)
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button("New fact", systemImage: "plus") { isCreating = true }
                .disabled(!viewModel.canCreate)
        }
    }

    // MARK: Contenuto

    @ViewBuilder
    private var content: some View {
        if !viewModel.hasLoaded {
            if let message = viewModel.errorMessage {
                // La lista non è mai arrivata: non si dice "nessun fatto", si dice perché.
                VStack(spacing: 14) {
                    ContentUnavailableView("Can't load the company memory", systemImage: "exclamationmark.triangle",
                                           description: Text(message))
                    Button {
                        Task { await viewModel.load() }
                    } label: {
                        Label("Retry", systemImage: "arrow.clockwise")
                    }
                    .ariaGlassButtonStyle()
                }
                .padding(.top, 40)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
            }
        } else if viewModel.visibleFacts.isEmpty {
            if viewModel.isSearching {
                ContentUnavailableView.search(text: viewModel.searchText)
            } else {
                ContentUnavailableView("No facts", systemImage: "brain",
                                       description: Text("Aria hasn't learned anything that matches these filters yet."))
                    .padding(.top, 40)
            }
            loadMoreButton
        } else {
            list
        }
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.subtitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 20)
                .padding(.top, 4)
            ForEach(viewModel.visibleFacts) { fact in
                NavigationLink(value: fact.id) {
                    AdminMemoryFactRow(fact: fact, text: viewModel.displayText(for: fact),
                                       isTranslated: viewModel.isTranslated(fact),
                                       metaLine: viewModel.metaLine(for: fact), isBusy: viewModel.isBusy(fact))
                }
                .buttonStyle(.plain)
                .contextMenu {
                    AdminMemoryFactActionButtons(
                        canApprove: viewModel.canApprove(fact), canReject: viewModel.canReject(fact),
                        onApprove: { Task { await viewModel.approve(fact) } },
                        onReject: { viewModel.askToReject(fact) },
                        onEdit: { editForm = viewModel.makeEditForm(for: fact) },
                        onDelete: { viewModel.askToDelete(fact) })
                }
                .padding(.horizontal, 20)
            }
            loadMoreButton
            if let updated = viewModel.lastUpdated {
                Text("Updated \(updated.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)
            }
        }
    }

    /// Le pagine dopo la prima: anche i filtri locali cercano solo fra i fatti scaricati.
    @ViewBuilder
    private var loadMoreButton: some View {
        if viewModel.canLoadMore {
            Button {
                Task { await viewModel.loadMore() }
            } label: {
                if viewModel.isLoadingMore {
                    ProgressView()
                } else {
                    Label("Load more", systemImage: "arrow.down.circle")
                }
            }
            .ariaGlassButtonStyle()
            .disabled(viewModel.isLoadingMore)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
        }
    }

    /// Lista già a schermo ma l'ultimo aggiornamento è fallito: una riga sottile con il motivo.
    @ViewBuilder
    private var errorPill: some View {
        if viewModel.hasLoaded, let message = viewModel.errorMessage {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Button("Retry") { Task { await viewModel.load() } }
                    .font(.footnote.weight(.semibold))
                    .disabled(viewModel.isLoading)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .ariaGlass(in: Capsule())
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
        }
    }
}
