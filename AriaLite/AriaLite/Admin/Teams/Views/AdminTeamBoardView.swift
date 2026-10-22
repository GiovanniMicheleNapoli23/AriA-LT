//
//  AdminTeamBoardView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La bacheca di una squadra (pagina /board della web): una sola scroll view. Su telefono le chip degli stati
//  scelgono la colonna e sotto stanno le sue card; su schermi larghi le colonne stanno affiancate in una griglia
//  adattiva. Da ogni card un menu sposta di stato o passa l'ordine a un'altra squadra.
//

import SwiftUI

struct AdminTeamBoardView: View {
    @State private var viewModel: AdminTeamBoardViewModel

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isWide: Bool { horizontalSizeClass == .regular }

    init(owner: AdminTeamsViewModel, teamId: String?) {
        _viewModel = State(initialValue: AdminTeamBoardViewModel(owner: owner, teamId: teamId))
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                AdminTeamBoardTeamMenu(title: viewModel.teamTitle, teams: viewModel.teams,
                                       selectedId: viewModel.teamId) { viewModel.selectTeam($0) }
                    .padding(.horizontal, 16)
                content
            }
            .padding(.top, 8)
            .padding(.bottom, 24)
            .ariaReadableWidth(isWide ? 1200 : AriaLayout.readableWidth)
        }
        .refreshable { await viewModel.load() }
        .liteBackground()
        .navigationTitle("Board")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: viewModel.teamId) { await viewModel.loadIfNeeded() }
        .confirmationDialog("Cancel this work order?", isPresented: cancelShown, titleVisibility: .visible,
                            presenting: viewModel.orderPendingCancel) { _ in
            Button("Mark as cancelled", role: .destructive) { viewModel.confirmCancel() }
            Button("Keep it", role: .cancel) {}
        } message: { order in
            Text(verbatim: viewModel.cancelMessage(for: order))
        }
        .alert("Couldn't move the work order", isPresented: $viewModel.isShowingMoveError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(verbatim: viewModel.moveError ?? "")
        }
    }

    private var cancelShown: Binding<Bool> {
        Binding(get: { viewModel.orderPendingCancel != nil },
                set: { if !$0 { viewModel.orderPendingCancel = nil } })
    }

    // MARK: Contenuto

    @ViewBuilder
    private var content: some View {
        if viewModel.teamId == nil {
            ContentUnavailableView("No teams", systemImage: "person.3",
                                   description: Text("Create a team to see its board."))
        } else if !viewModel.hasLoaded {
            if let failure = viewModel.failure {
                failureView(failure)
            } else {
                ProgressView().frame(maxWidth: .infinity).padding(.top, 60)
            }
        } else {
            if let failure = viewModel.failure {
                AdminTeamFailureNote(message: failure.message, isForbidden: failure.isForbidden)
                    .padding(.horizontal, 16)
            }
            if viewModel.isEmpty {
                ContentUnavailableView("No work orders", systemImage: "tray",
                                       description: Text("Work orders assigned to this team appear here."))
            } else if isWide {
                wideBoard
            } else {
                compactBoard
            }
        }
    }

    /// Telefono: le chip scelgono la colonna, sotto le sue card.
    private var compactBoard: some View {
        VStack(alignment: .leading, spacing: 14) {
            AdminTeamBoardStatusPicker(columns: viewModel.columns, selection: $viewModel.selectedStatus) {
                viewModel.count(in: $0)
            }
            .padding(.horizontal, 16)
            column(viewModel.selectedStatus, showsHeader: false)
                .padding(.horizontal, 16)
        }
    }

    /// Schermo largo: tutte le colonne affiancate, a capo quando non ci stanno. Niente scroll orizzontale.
    private var wideBoard: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 16, alignment: .top)],
                  alignment: .leading, spacing: 20) {
            ForEach(viewModel.columns, id: \.self) { status in
                column(status, showsHeader: true)
            }
        }
        .padding(.horizontal, 16)
    }

    private func column(_ status: AdminTeamWorkOrderStatus, showsHeader: Bool) -> some View {
        AdminTeamBoardColumn(status: status, cards: viewModel.cards(in: status), showsHeader: showsHeader) { card in
            boardCard(card)
        }
    }

    private func boardCard(_ card: AdminTeamBoardCard) -> some View {
        AdminTeamBoardCardView(card: card)
            .overlay(alignment: .bottomTrailing) {
                Menu {
                    moveMenu(for: card)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .tint(.secondary)
                .accessibilityLabel(Text("Move or reassign"))
                .disabled(card.isBusy)
            }
            .contextMenu { moveMenu(for: card) }
    }

    private func moveMenu(for card: AdminTeamBoardCard) -> some View {
        AdminTeamBoardMoveMenu(statuses: viewModel.statusChoices(for: card.order),
                               teams: viewModel.teamChoices(for: card.order),
                               onMove: { viewModel.move(card.order, to: $0) },
                               onAssign: { viewModel.assign(card.order, to: $0) })
    }

    // MARK: Errori

    private func failureView(_ failure: AdminTeamsFailure) -> some View {
        VStack(spacing: 14) {
            if failure.isForbidden {
                ContentUnavailableView("No access to the board", systemImage: "lock",
                                       description: Text(verbatim: failure.message))
            } else {
                ContentUnavailableView("Can't load the board", systemImage: "wifi.exclamationmark",
                                       description: Text(verbatim: failure.message))
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
}
