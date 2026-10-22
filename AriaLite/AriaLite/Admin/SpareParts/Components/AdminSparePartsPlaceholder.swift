//
//  AdminSparePartsPlaceholder.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Cosa si vede al posto della lista: caricamento, errore (con Riprova, tranne se il ruolo non ha
//  accesso), nessun ricambio, nessun risultato della ricerca o dei filtri.
//

import SwiftUI

struct AdminSparePartsPlaceholder: View {
    let placeholder: AdminSparePartsViewModel.Placeholder
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
                    let title: LocalizedStringKey = failure.isForbidden ? "No access" : "Can't load spare parts"
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
                                       description: Text("Choose a plant to see its spare parts."))
            case .empty:
                ContentUnavailableView("No spare parts", systemImage: "shippingbox",
                                       description: Text("Spare parts of this plant appear here."))
            case .noLowStock:
                ContentUnavailableView("Stock is fine", systemImage: "checkmark.circle",
                                       description: Text("No spare part is below its minimum quantity."))
            case .noResults(let query):
                ContentUnavailableView.search(text: query)
            case .noMatches:
                VStack(spacing: 14) {
                    ContentUnavailableView("No matching spare parts", systemImage: "line.3.horizontal.decrease.circle",
                                           description: Text("No spare part matches these filters."))
                    Button("Clear filters", action: clearFilters)
                        .ariaGlassButtonStyle()
                }
            }
        }
        .padding(.top, 24)
    }
}
