//
//  AdminCraftedSessionsSection.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le sessioni concluse dello stabilimento: riepilogo in cifre e lista. Un tocco apre la conversazione
//  in sola lettura, da cui si fissano le card fra i widget e si scarica il report.
//

import SwiftUI

struct AdminCraftedSessionsSection: View {
    @Bindable var viewModel: AdminCraftedViewModel

    // Misure fisse: scalate col Dynamic Type supererebbero la larghezza di un iPhone (griglia fuori schermo).
    private let minTileWidth: CGFloat = 140
    private let minRowWidth: CGFloat = 320

    var body: some View {
        AdminCraftedErrorPill(message: viewModel.sessionsLoaded ? viewModel.sessionsError : nil,
                              isLoading: viewModel.isLoading) {
            await viewModel.load()
        }
        if !viewModel.sessionsLoaded {
            AdminCraftedLoadState(error: viewModel.sessionsError, title: "Can't load sessions") {
                await viewModel.load()
            }
        } else {
            if !viewModel.summaryTiles.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: minTileWidth), spacing: 10)], spacing: 10) {
                    ForEach(viewModel.summaryTiles) { tile in
                        AdminStatTile(title: tile.title, value: tile.value, systemImage: tile.systemImage)
                    }
                }
                .padding(.horizontal, 20)
            }
            if viewModel.visibleSessions.isEmpty {
                if viewModel.isSearching {
                    ContentUnavailableView.search(text: viewModel.searchText)
                } else {
                    ContentUnavailableView("No concluded sessions", systemImage: "bubble.left.and.text.bubble.right",
                                           description: Text("Sessions appear here once Aria or the operator closes them."))
                        .padding(.top, 40)
                }
            } else {
                list
            }
        }
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.sessionsSubtitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.top, 4)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: minRowWidth), spacing: 10)], spacing: 10) {
                ForEach(viewModel.visibleSessions) { review in
                    NavigationLink(value: review) {
                        AdminCraftedSessionRow(review: review)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 20)
    }
}
