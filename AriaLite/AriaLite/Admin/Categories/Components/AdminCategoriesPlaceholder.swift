//
//  AdminCategoriesPlaceholder.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Cosa mostrare al posto della lista: caricamento, errore con riprova, elenco vuoto, nessun risultato.
//

import SwiftUI

struct AdminCategoriesPlaceholder: View {
    let placeholder: AdminCategoriesViewModel.Placeholder
    let canCreate: Bool
    let retry: () -> Void
    let clearFilters: () -> Void

    var body: some View {
        switch placeholder {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 240)
        case .failed(let failure):
            ContentUnavailableView {
                Label("Couldn't load categories", systemImage: "exclamationmark.triangle")
            } description: {
                Text(failure.message)
            } actions: {
                if !failure.isNotFound {
                    Button("Try again", action: retry)
                        .buttonStyle(.borderedProminent)
                        .tint(Color.liteAccent)
                        .foregroundStyle(Color.liteOnAccent)
                }
            }
            .frame(minHeight: 240)
        case .empty:
            // Senza `create` non c'è il "+": niente invito a toccarlo.
            ContentUnavailableView("No categories", systemImage: "tag",
                                   description: canCreate ? Text("Tap + to add the first category.") : nil)
                .frame(minHeight: 240)
        case .noMatches:
            ContentUnavailableView {
                Label("No matching categories", systemImage: "magnifyingglass")
            } actions: {
                Button("Clear filters", action: clearFilters)
            }
            .frame(minHeight: 240)
        }
    }
}
