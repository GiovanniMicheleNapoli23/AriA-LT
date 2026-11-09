//
//  AdminAgentStudioLoadState.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il contenuto di una lista che non c'è ancora: caricamento, errore con "Riprova" o vuoto.
//  Se la lista c'è mostra il contenuto, con una riga sottile se l'ultimo aggiornamento è fallito.
//

import SwiftUI

struct AdminAgentStudioLoadState<Content: View>: View {
    let hasLoaded: Bool
    let isEmpty: Bool
    let errorMessage: String?
    let failureTitle: LocalizedStringKey
    let emptyTitle: LocalizedStringKey
    let emptyImage: String
    let emptyDescription: LocalizedStringKey
    let retry: () async -> Void
    @ViewBuilder var content: Content

    var body: some View {
        if !hasLoaded || (isEmpty && errorMessage != nil) {
            if let errorMessage {
                // La lista non è mai arrivata: non si dice "vuota", si dice perché.
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
                .padding(.top, 32)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 48)
            }
        } else if isEmpty {
            ContentUnavailableView(emptyTitle, systemImage: emptyImage, description: Text(emptyDescription))
                .padding(.top, 32)
        } else {
            if let errorMessage {
                AdminSectionNotice(text: errorMessage, isError: true)
            }
            content
        }
    }
}
