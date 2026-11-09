//
//  AdminCraftedLoadState.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Gli stati di Crafted quando i dati non ci sono ancora: rotella, oppure il motivo con "Retry".
//  E la riga sottile quando i dati ci sono ma l'ultimo aggiornamento è fallito.
//

import SwiftUI

struct AdminCraftedLoadState: View {
    let error: String?
    let title: LocalizedStringKey
    let retry: () async -> Void

    var body: some View {
        if let error {
            VStack(spacing: 14) {
                ContentUnavailableView(title, systemImage: "exclamationmark.triangle", description: Text(error))
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
    }
}

struct AdminCraftedErrorPill: View {
    let message: String?
    let isLoading: Bool
    let retry: () async -> Void

    var body: some View {
        if let message {
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
            .padding(.horizontal, 20)
        }
    }
}
