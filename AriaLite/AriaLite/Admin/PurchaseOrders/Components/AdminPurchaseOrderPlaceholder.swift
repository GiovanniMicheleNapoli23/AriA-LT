//
//  AdminPurchaseOrderPlaceholder.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Cosa si vede al posto della lista: caricamento, errore (con Riprova, tranne se il ruolo non ha accesso),
//  nessuno stabilimento, nessun ordine, nessun risultato della ricerca o dei filtri.
//

import SwiftUI

struct AdminPurchaseOrderPlaceholder: View {
    let placeholder: AdminPurchaseOrdersViewModel.Placeholder
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
                    let title: LocalizedStringKey = failure.isForbidden ? "No access" : "Can't load purchase orders"
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
            case .noPlant:
                ContentUnavailableView("No plant selected", systemImage: "building.2",
                                       description: Text("Choose a plant to see its purchase orders."))
            case .empty:
                ContentUnavailableView("No purchase orders", systemImage: "cart",
                                       description: Text("Purchase orders of this plant appear here. Tap + to create one."))
            case .noResults(let query):
                ContentUnavailableView.search(text: query)
            case .noMatches:
                VStack(spacing: 14) {
                    ContentUnavailableView("No matching purchase orders",
                                           systemImage: "line.3.horizontal.decrease.circle",
                                           description: Text("No purchase order matches these filters."))
                    Button("Clear filters", action: clearFilters)
                        .ariaGlassButtonStyle()
                }
            }
        }
        .padding(.top, 24)
    }
}
