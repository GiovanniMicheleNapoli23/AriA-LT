//
//  AdminTeamsPlaceholder.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Cosa si vede al posto della lista: caricamento, errore (con Riprova, tranne se il ruolo non ha accesso),
//  nessuna squadra, nessun risultato della ricerca o del filtro.
//

import SwiftUI

struct AdminTeamsPlaceholder: View {
    let placeholder: AdminTeamsViewModel.Placeholder
    let retry: () -> Void
    let clearFilters: () -> Void

    var body: some View {
        Group {
            switch placeholder {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
            case .failed(let failure):
                VStack(spacing: 14) {
                    let title: LocalizedStringKey = failure.isForbidden ? "No access" : "Can't load teams"
                    ContentUnavailableView(title,
                                           systemImage: failure.isForbidden ? "lock" : "wifi.exclamationmark",
                                           description: Text(verbatim: failure.message))
                    if !failure.isForbidden {
                        Button(action: retry) {
                            Label("Retry", systemImage: "arrow.clockwise")
                        }
                        .ariaGlassButtonStyle()
                    }
                }
            case .empty:
                ContentUnavailableView("No teams", systemImage: "person.3",
                                       description: Text("Teams of your company appear here."))
            case .noResults(let query):
                ContentUnavailableView.search(text: query)
            case .noMatches:
                VStack(spacing: 14) {
                    ContentUnavailableView("No matching teams", systemImage: "line.3.horizontal.decrease.circle",
                                           description: Text("No team matches this plant."))
                    Button("Clear filters", action: clearFilters)
                        .ariaGlassButtonStyle()
                }
            }
        }
        .padding(.top, 24)
    }
}
