//
//  AdminAlarmsPlaceholder.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Cosa si vede al posto della lista: caricamento, errore (con Riprova, tranne se il ruolo non ha accesso),
//  nessun allarme in quello stato o nessun risultato della ricerca.
//

import SwiftUI

struct AdminAlarmsPlaceholder: View {
    let placeholder: AdminAlarmsViewModel.Placeholder
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
                    let title: LocalizedStringKey = failure.isForbidden ? "No access" : "Can't load alarms"
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
            case .empty(let status):
                ContentUnavailableView("No alarms", systemImage: "bell.slash",
                                       description: Text("No alarm has the status “\(status.label)”."))
            case .noResults(let query):
                ContentUnavailableView.search(text: query)
            }
        }
        .padding(.top, 24)
    }
}
