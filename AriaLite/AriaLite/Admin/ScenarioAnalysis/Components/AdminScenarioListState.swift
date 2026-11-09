//
//  AdminScenarioListState.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Gli stati di una lista della sezione: in caricamento, mai arrivata (con il motivo e Riprova), vuota,
//  nessun risultato per la ricerca, oppure il contenuto. Se un aggiornamento fallisce con la lista già
//  a schermo, sopra resta una riga sottile con il motivo.
//

import SwiftUI

struct AdminScenarioListState<Content: View>: View {
    let hasLoaded: Bool
    let isLoading: Bool
    let errorMessage: String?
    let isEmpty: Bool
    let searchText: String
    let failureTitle: LocalizedStringKey
    let emptyTitle: LocalizedStringKey
    let emptySystemImage: String
    let emptyDescription: LocalizedStringKey
    let retry: () async -> Void
    @ViewBuilder var content: Content

    private var isSearching: Bool { !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        if !hasLoaded {
            if let errorMessage {
                VStack(spacing: 14) {
                    ContentUnavailableView(failureTitle, systemImage: "exclamationmark.triangle",
                                           description: Text(errorMessage))
                    Button {
                        Task { await retry() }
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
        } else {
            if let errorMessage { errorPill(errorMessage) }
            if isEmpty {
                if isSearching {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    ContentUnavailableView(emptyTitle, systemImage: emptySystemImage, description: Text(emptyDescription))
                        .padding(.top, 40)
                }
            } else {
                content
            }
        }
    }

    private func errorPill(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Button("Retry") { Task { await retry() } }
                .font(.footnote.weight(.semibold))
                .disabled(isLoading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .ariaGlass(in: Capsule())
        .frame(maxWidth: .infinity)
    }
}
