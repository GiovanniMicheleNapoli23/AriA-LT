//
//  AdminTaskboardView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La sezione Taskboard, come la pagina /taskboard della web. In kanban le colonne stanno tutte affiancate,
//  ognuna con il suo scroll, e le card si trascinano da una colonna all'altra. In lista è una sola scroll view:
//  su telefono i chip degli stati (con il conteggio) scelgono la colonna e sotto stanno le sue card; su schermi
//  larghi le colonne stanno affiancate in una griglia adattiva. Dal menu contestuale di una card si sposta di
//  colonna; un tocco apre il dettaglio degli ordini di lavoro. Per persona le task aperte stanno sotto chi le
//  esegue; in calendario si sceglie un giorno e sotto ci sono le sue attività, sempre per persona.
//  Tutta la logica è in AdminTaskboardViewModel.
//

import SwiftUI

struct AdminTaskboardView: View {
    @Bindable var viewModel: AdminTaskboardViewModel

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isWide: Bool { horizontalSizeClass == .regular }
    private var isKanban: Bool { viewModel.layout == .kanban }

    var body: some View {
        NavigationStack(path: $viewModel.path) {
            Group {
                if isKanban && viewModel.hasLoaded { kanbanBoard } else { scrollingBoard }
            }
            .refreshable { await viewModel.refresh() }
            .liteBackground()
            .navigationTitle("Taskboard")
            .navigationBarTitleDisplayMode(isKanban ? .inline : .automatic)
            .navigationDestination(for: AdminWorkOrderRoute.self) { route in
                AdminWorkOrderDetailView(viewModel: viewModel.detailModel(for: route.order))
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { AriaSidebarButton() }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Layout", selection: $viewModel.layout) {
                            ForEach(AdminTaskboardLayout.allCases, id: \.self) { layout in
                                Label(layout.localized, systemImage: layout.systemImage).tag(layout)
                            }
                        }
                    } label: {
                        Label("Layout", systemImage: viewModel.layout.systemImage)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("New task", systemImage: "plus") { viewModel.startCreating() }
                        .disabled(viewModel.isForbidden || !viewModel.hasLoaded)
                }
            }
            .searchable(text: $viewModel.searchText, prompt: Text("Search title, asset, zone or person"))
            .sheet(item: $viewModel.createModel) { model in
                AdminTaskboardCreateView(viewModel: model)
            }
            .adminWorkOrderQuickActions(viewModel.quickActions)
            .alert("Couldn't move the task", isPresented: moveErrorShown) {
                Button("OK") {}
            } message: {
                Text(viewModel.moveError ?? "")
            }
            .onChange(of: viewModel.path.count) { viewModel.pathChanged() }
        }
        .task(id: viewModel.loadKey) { await viewModel.loadIfNeeded() }
    }

    private var moveErrorShown: Binding<Bool> {
        Binding(get: { viewModel.moveError != nil }, set: { if !$0 { viewModel.moveError = nil } })
    }

    // MARK: Contenuto

    /// Kanban: filtri in alto, sotto le colonne a tutta altezza (scorrono loro, non la pagina).
    private var kanbanBoard: some View {
        VStack(alignment: .leading, spacing: 12) {
            AdminTaskboardFilterBar(viewModel: viewModel)
            if let message = viewModel.errorMessage { errorPill(message) }
            footnote
            AdminTaskboardKanbanBoard(viewModel: viewModel) { item in
                card(item, isCompact: true)
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 8)
    }

    /// Lista, e il caricamento o l'errore prima che ci sia una bacheca.
    private var scrollingBoard: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                AdminTaskboardFilterBar(viewModel: viewModel)
                if viewModel.hasLoaded, let message = viewModel.errorMessage { errorPill(message) }
                content
            }
            .padding(.top, 4)
            .padding(.bottom, 24)
            .ariaReadableWidth(isWide ? 1200 : AriaLayout.readableWidth)
        }
    }

    @ViewBuilder
    private var content: some View {
        if !viewModel.hasLoaded {
            if let message = viewModel.errorMessage {
                failure(message)
            } else {
                ProgressView().frame(maxWidth: .infinity).padding(.top, 60)
            }
        } else {
            switch viewModel.layout {
            case .people:
                AdminTaskboardPeopleBoard(viewModel: viewModel) { card($0, showsStatus: true) }
                footnote
            case .calendar:
                AdminTaskboardCalendarBoard(viewModel: viewModel) { card($0, showsStatus: true) }
                footnote
            case .kanban, .list:
                if isWide { wideBoard } else { compactBoard }
            }
        }
    }

    /// Telefono: i chip scelgono la colonna, sotto le sue card.
    private var compactBoard: some View {
        VStack(alignment: .leading, spacing: 14) {
            AdminTaskboardColumnPicker(columns: AdminTaskboardViewModel.columns, selection: $viewModel.selectedStatus) {
                viewModel.count(in: $0)
            }
            column(viewModel.selectedStatus, showsHeader: false, minimumCardWidth: 320)
                .padding(.horizontal, 16)
            footnote
        }
    }

    /// Schermo largo: tutte le colonne affiancate, a capo quando non ci stanno. Niente scroll orizzontale.
    private var wideBoard: some View {
        VStack(alignment: .leading, spacing: 14) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 16, alignment: .top)],
                      alignment: .leading, spacing: 20) {
                ForEach(AdminTaskboardViewModel.columns, id: \.self) { status in
                    column(status, showsHeader: true, minimumCardWidth: 300)
                }
            }
            .padding(.horizontal, 16)
            footnote
        }
    }

    private func column(_ status: AdminWorkOrderStatus, showsHeader: Bool, minimumCardWidth: CGFloat) -> some View {
        let items = viewModel.cards(in: status)
        return AdminTaskboardColumnSection(status: status, items: items, minimumCardWidth: minimumCardWidth,
                                           showsHeader: showsHeader) { item in
            card(item)
        }
    }

    private func card(_ item: AdminWorkOrderRowItem, isCompact: Bool = false, showsStatus: Bool = false) -> some View {
        NavigationLink(value: AdminWorkOrderRoute(order: item.order)) {
            AdminTaskboardCard(item: item, isCompact: isCompact, showsStatus: showsStatus)
        }
        .buttonStyle(.plain)
        .contextMenu {
            AdminTaskboardMoveMenu(choices: viewModel.moveChoices(for: item)) { viewModel.move(item, to: $0) }
        }
        .disabled(item.isBusy)
    }

    @ViewBuilder
    private var footnote: some View {
        if viewModel.isTruncated {
            AdminSectionNotice(text: String(localized: "Only the most recent work orders are shown."))
                .padding(.horizontal, 16)
        }
    }

    // MARK: Errori

    private func failure(_ message: String) -> some View {
        VStack(spacing: 14) {
            if viewModel.isForbidden {
                ContentUnavailableView("No access to the taskboard", systemImage: "lock", description: Text(message))
            } else {
                ContentUnavailableView("Can't load the taskboard", systemImage: "wifi.exclamationmark",
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
        .frame(maxWidth: .infinity)
    }

    /// Bacheca già a schermo ma l'ultimo aggiornamento è fallito: una riga col motivo.
    private func errorPill(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: viewModel.isForbidden ? "lock" : "wifi.exclamationmark").foregroundStyle(.orange)
            Text(message).font(.footnote).foregroundStyle(.secondary).lineLimit(2)
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
    }
}
