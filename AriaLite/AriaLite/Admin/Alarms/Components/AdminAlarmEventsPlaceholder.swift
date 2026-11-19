//
//  AdminAlarmEventsPlaceholder.swift
//  AriaLite
//
//  Created by Giovanni Michele on 10/11/26.
//
//  Cosa si vede al posto delle righe dell'inbox: caricamento, errore (con Riprova, tranne se il ruolo non
//  ha accesso) o nessun evento per il filtro scelto.
//

import SwiftUI

struct AdminAlarmEventsPlaceholder: View {
    let placeholder: AdminAlarmEventsViewModel.Placeholder
    let retry: () -> Void

    var body: some View {
        Group {
            switch placeholder {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 36)
            case .failed(let failure):
                VStack(spacing: 14) {
                    let title: LocalizedStringKey = failure.isForbidden ? "No access" : "Can't load alarm events"
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
            case .empty(let filter):
                switch filter {
                case .all:
                    ContentUnavailableView("No alarm events", systemImage: "bell.slash",
                                           description: Text("The site hasn't raised any alarm yet."))
                case .unread:
                    ContentUnavailableView("All caught up", systemImage: "checkmark.circle",
                                           description: Text("There are no unread alarm events."))
                case .read:
                    ContentUnavailableView("No read events", systemImage: "tray",
                                           description: Text("Alarm events you've marked as read show up here."))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
    }
}
