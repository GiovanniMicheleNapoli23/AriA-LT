//
//  AdminPlantsPlaceholder.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Cosa mostrare al posto dell'elenco: caricamento, errore con riprova, vuoto, nessun risultato.
//

import SwiftUI

struct AdminPlantsPlaceholder: View {
    let placeholder: AdminPlantsViewModel.Placeholder
    let retry: () -> Void

    var body: some View {
        Group {
            switch placeholder {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
            case .failed(let failure):
                VStack(spacing: 14) {
                    let title: LocalizedStringKey = failure.isForbidden ? "No access" : "Can't load plants"
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
                ContentUnavailableView("No plants", systemImage: "building.columns",
                                       description: Text("Plants of this company appear here."))
            case .noResults(let query):
                ContentUnavailableView.search(text: query)
            }
        }
        .padding(.top, 24)
    }
}
