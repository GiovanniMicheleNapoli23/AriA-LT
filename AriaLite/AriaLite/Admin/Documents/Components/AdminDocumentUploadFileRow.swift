//
//  AdminDocumentUploadFileRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un file scelto per il caricamento: nome, peso, l'avviso se esiste già nello stabilimento e
//  il pulsante per toglierlo dalla scelta.
//

import SwiftUI

struct AdminDocumentUploadFileRow: View {
    let file: AdminDocumentUploadFile
    let isConflicting: Bool
    let canRemove: Bool
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            AdminDocumentFileIcon(fileName: file.filename, mimeType: file.mimeType)
            VStack(alignment: .leading, spacing: 2) {
                Text(file.filename)
                    .font(.subheadline)
                    .lineLimit(2)
                Text(file.size.formatted(.byteCount(style: .file)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if isConflicting {
                    Label("Already in this plant", systemImage: "doc.on.doc")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                }
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 8)
            Button("Remove", systemImage: "xmark.circle.fill", action: onRemove)
                .labelStyle(.iconOnly)
                .font(.title3)
                .foregroundStyle(.secondary)
                .buttonStyle(.plain)
                .disabled(!canRemove)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
