//
//  AdminCraftedWidgetsSection.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La galleria dei widget salvati: griglia adattiva di card, menu contestuale per eliminare,
//  stati di caricamento, errore e vuoto.
//

import SwiftUI

struct AdminCraftedWidgetsSection: View {
    @Bindable var viewModel: AdminCraftedViewModel

    /// Fissa: scalata col Dynamic Type supererebbe la larghezza di un iPhone. Su iPad e in orizzontale più colonne.
    private let minCardWidth: CGFloat = 220

    var body: some View {
        AdminCraftedErrorPill(message: viewModel.widgetsLoaded ? viewModel.widgetsError : nil,
                              isLoading: viewModel.isLoading) {
            await viewModel.load()
        }
        if !viewModel.widgetsLoaded {
            AdminCraftedLoadState(error: viewModel.widgetsError, title: "Can't load widgets") {
                await viewModel.load()
            }
        } else if viewModel.visibleWidgets.isEmpty {
            if viewModel.isSearching {
                ContentUnavailableView.search(text: viewModel.searchText)
            } else if viewModel.widgets.isEmpty {
                ContentUnavailableView("Nothing crafted yet", systemImage: "sparkles",
                                       description: Text("Pin a table, chart or KPI card that Aria made in a session and it will appear here, always up to date."))
                    .padding(.top, 40)
            } else {
                ContentUnavailableView("No widgets", systemImage: "square.grid.2x2",
                                       description: Text("No widgets match this filter."))
                    .padding(.top, 40)
            }
        } else {
            grid
        }
    }

    private var grid: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.widgetsSubtitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.top, 4)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: minCardWidth), spacing: 12)], spacing: 12) {
                ForEach(viewModel.visibleWidgets) { widget in
                    NavigationLink(value: widget) {
                        AdminCraftedWidgetCard(widget: widget)
                    }
                    .buttonStyle(.plain)
                    .disabled(widget.serverId == nil)
                    .contextMenu {
                        Button("Delete", systemImage: "trash", role: .destructive) { viewModel.askDelete(widget) }
                            .disabled(!viewModel.canDelete(widget))
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }
}
