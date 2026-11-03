//
//  AdminDocumentUploadsCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 27/10/26.
//
//  Sopra la lista, finché c'è qualcosa in caricamento o fallito: un file per riga con la sua barra,
//  la percentuale complessiva in alto e il promemoria che l'invio continua anche fuori dall'app.
//

import SwiftUI

struct AdminDocumentUploadsCard: View {
    let center: AdminDocumentUploadCenter

    var body: some View {
        AdminCard(title: "Uploads", systemImage: "arrow.up.doc") {
            if center.activeCount > 0 {
                Text(center.overallProgress, format: .percent.precision(.fractionLength(0)))
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        } content: {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(center.jobs) { job in
                    AdminDocumentUploadJobRow(job: job, progress: center.progress(of: job),
                                              onRetry: { Task { await center.retry(job) } },
                                              onRemove: { center.dismiss(job) })
                    if job.id != center.jobs.last?.id { Divider() }
                }
                if center.activeCount > 0 {
                    Text("Uploads continue in the background, even if you leave the app.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
