//
//  AdminWorkOrdersView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Gli ordini di lavoro dell'azienda, come la pagina /work-orders della web: lista, dettaglio, creazione e modifica.
//  Qui solo la lista, compatta: chip dei filtri e ordinamento, ricerca, pull-to-refresh, altre pagine scorrendo.
//  È una List per gli swipe (iOS 18): da sinistra "Start"/"Hold", da destra "Complete"; il menu contestuale
//  cambia lo stato o assegna in automatico. Tutta la logica è in AdminWorkOrdersViewModel.
//

import SwiftUI

struct AdminWorkOrdersView: View {
    @Bindable var viewModel: AdminWorkOrdersViewModel

    init(viewModel: AdminWorkOrdersViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        NavigationStack {
            List {
                AdminWorkOrderFilterBar(viewModel: viewModel)
                    .ariaReadableWidth()
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 10, trailing: 0))
                    .plainListRow()
                errorPill
                content
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.defaultMinListRowHeight, 0)
            .refreshable { await viewModel.refresh() }
            .liteBackground()
            .navigationTitle("Work Orders")
            .navigationDestination(for: AdminWorkOrderRoute.self) { route in
                AdminWorkOrderDetailView(viewModel: viewModel.detailModel(for: route.order))
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { AriaSidebarButton() }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("New Work Order", systemImage: "plus") { viewModel.startCreating() }
                        .disabled(viewModel.isForbidden)
                }
            }
            .searchable(text: $viewModel.searchText, prompt: Text("Search title, asset or zone"))
            .sheet(item: $viewModel.createForm) { form in
                AdminWorkOrderCreateView(viewModel: form)
            }
            .adminWorkOrderQuickActions(viewModel.actions)
        }
        .task(id: viewModel.backend.activePlantId) { await viewModel.loadIfNeeded() }
    }

    // MARK: Contenuto

    @ViewBuilder
    private var content: some View {
        if !viewModel.hasLoaded {
            Group {
                if let message = viewModel.errorMessage {
                    failure(message)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                }
            }
            .plainListRow()
        } else if viewModel.rows.isEmpty {
            Group {
                if viewModel.isSearching {
                    ContentUnavailableView.search(text: viewModel.searchText)
                } else {
                    ContentUnavailableView("No work orders", systemImage: "wrench.and.screwdriver",
                                           description: Text("Nothing matches these filters."))
                        .padding(.top, 40)
                }
            }
            .plainListRow()
        } else {
            ForEach(viewModel.rows) { item in
                row(item)
            }
            footer.plainListRow()
        }
    }

    private func row(_ item: AdminWorkOrderRowItem) -> some View {
        // Il link nascosto dietro la riga: niente freccia della List, la riga resta tutta toccabile.
        AdminWorkOrderRow(item: item)
            .background {
                NavigationLink(value: AdminWorkOrderRoute(order: item.order)) { EmptyView() }.opacity(0)
            }
            .ariaReadableWidth()
            .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
            .plainListRow()
            .onAppear { viewModel.loadMoreIfNeeded(after: item) }
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                if let status = viewModel.leadingSwipe(for: item) {
                    Button {
                        viewModel.changeStatus(item, to: status)
                    } label: {
                        if status == .inProgress {
                            Label("Start", systemImage: "play.fill")
                        } else {
                            Label("Hold", systemImage: "pause.fill")
                        }
                    }
                    .tint(status == .inProgress ? .orange : .gray)
                }
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                if viewModel.canComplete(item) {
                    Button { viewModel.changeStatus(item, to: .completed) } label: {
                        Label("Complete", systemImage: "checkmark")
                    }
                    .tint(.green)
                }
            }
            .contextMenu {
                Menu {
                    AdminWorkOrderStatusMenuItems(choices: viewModel.statusChoices(for: item)) { status in
                        viewModel.changeStatus(item, to: status)
                    }
                } label: {
                    Label("Change status", systemImage: "arrow.triangle.2.circlepath")
                }
                if !item.order.isClosed {
                    Button("Auto-assign", systemImage: "person.crop.circle.badge.checkmark") { viewModel.autoAssign(item) }
                }
            }
            .disabled(item.isBusy)
    }

    /// Altre pagine: si caricano scorrendo; il pulsante serve quando la ricerca nasconde l'ultima riga.
    @ViewBuilder
    private var footer: some View {
        if viewModel.isLoadingMore {
            ProgressView().frame(maxWidth: .infinity).padding(.vertical, 12)
        } else if viewModel.canLoadMore {
            Button("Load more") { viewModel.loadMore() }
                .ariaGlassButtonStyle()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        } else {
            Color.clear.frame(height: 12)
        }
    }

    /// Mai arrivata la lista: si dice perché, con "Retry" se riprovare ha senso (non per un 403).
    private func failure(_ message: String) -> some View {
        VStack(spacing: 14) {
            if viewModel.isForbidden {
                ContentUnavailableView("No access to work orders", systemImage: "lock", description: Text(message))
            } else {
                ContentUnavailableView("Can't load work orders", systemImage: "wifi.exclamationmark",
                                       description: Text(message))
                Button {
                    Task { await viewModel.load() }
                } label: {
                    Label("Retry", systemImage: "arrow.clockwise")
                }
                .ariaGlassButtonStyle()
            }
        }
        .padding(.top, 40)
    }

    /// Lista già a schermo ma l'ultimo caricamento è fallito: una riga sottile col motivo.
    @ViewBuilder
    private var errorPill: some View {
        if viewModel.hasLoaded, let message = viewModel.errorMessage {
            HStack(spacing: 8) {
                Image(systemName: viewModel.isForbidden ? "lock" : "wifi.exclamationmark").foregroundStyle(.orange)
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                if !viewModel.isForbidden {
                    Button("Retry") { Task { await viewModel.load() } }
                        .font(.footnote.weight(.semibold))
                        .buttonStyle(.borderless)
                        .disabled(viewModel.isLoading)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .ariaGlass(in: Capsule())
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
            .plainListRow()
        }
    }
}

private extension View {
    /// Riga della List senza sfondo né separatore: la lista resta a schede di vetro.
    func plainListRow() -> some View {
        listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}
