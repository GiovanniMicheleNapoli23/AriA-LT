//
//  AdminCraftedReportStatus.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Il rapporto in apertura (una pagina bianca con la rotella) e il rapporto che non si apre: il motivo,
//  "Retry" e, se il file è arrivato ma non si legge, "Share original".
//

import SwiftUI

struct AdminCraftedReportLoading: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Opening the document…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}

struct AdminCraftedReportFailure: View {
    let message: String
    /// C'è il file scaricato, solo non si legge.
    let hasFile: Bool
    let retry: () async -> Void
    let shareOriginal: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            ContentUnavailableView("The document could not be opened.", systemImage: "exclamationmark.triangle",
                                   description: Text(message))
            HStack(spacing: 12) {
                Button {
                    Task { await retry() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                        Text("Retry")
                    }
                }
                .ariaGlassButtonStyle()
                if hasFile {
                    Button(action: shareOriginal) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share original")
                        }
                    }
                    .ariaGlassButtonStyle()
                }
            }
        }
        .padding(.top, 40)
    }
}
