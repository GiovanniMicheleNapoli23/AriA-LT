//
//  AdminDocumentUploadJobRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 27/10/26.
//
//  Un file in caricamento: nome, barra con peso e percentuale; se è fallito, il motivo con
//  "Riprova" e "Togli".
//

import SwiftUI

struct AdminDocumentUploadJobRow: View {
    let job: AdminDocumentUploadJob
    let progress: Double
    let onRetry: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AdminDocumentFileIcon(fileName: job.filename, mimeType: job.mimeType)
            VStack(alignment: .leading, spacing: 6) {
                Text(job.filename)
                    .font(.subheadline)
                    .lineLimit(2)
                if let failure = job.failure {
                    Label(failure, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Retry", systemImage: "arrow.clockwise", action: onRetry)
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(Color.liteAccent)
                } else {
                    ProgressView(value: progress)
                        .tint(Color.liteAccent)
                        .animation(.smooth, value: progress)
                    Text(statusLine)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 4)
            Button(job.isFailed ? String(localized: "Remove") : String(localized: "Cancel upload"),
                   systemImage: "xmark.circle.fill", action: onRemove)
                .labelStyle(.iconOnly)
                .font(.title3)
                .foregroundStyle(.secondary)
                .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// "12,4 MB · 45%", o "In attesa" prima del primo byte.
    private var statusLine: String {
        let size = job.size.formatted(.byteCount(style: .file))
        guard progress > 0 else { return String(localized: "\(size) · Waiting to upload") }
        if progress >= 1 { return String(localized: "\(size) · Starting processing…") }
        return "\(size) · \(progress.formatted(.percent.precision(.fractionLength(0))))"
    }
}
