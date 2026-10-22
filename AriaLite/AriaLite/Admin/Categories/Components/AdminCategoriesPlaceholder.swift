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
                }
            }
            .frame(minHeight: 240)
        case .empty:
            ContentUnavailableView("No categories", systemImage: "tag",
                                   description: Text("Tap + to add the first category."))
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
