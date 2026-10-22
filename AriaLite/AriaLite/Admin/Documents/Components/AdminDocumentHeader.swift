//
//  AdminDocumentHeader.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  L'intestazione del dettaglio: icona del tipo, nome, file e stato complessivo.
//

import SwiftUI

struct AdminDocumentHeader: View {
    let document: AdminDocument

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            AdminDocumentFileIcon(fileName: document.fileName, mimeType: document.mimeType)
            VStack(alignment: .leading, spacing: 4) {
                Text(document.displayName)
                    .font(.title3.weight(.bold))
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                if let fileName = document.fileName, fileName != document.displayName {
                    Text(fileName)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                if !document.summaryLine.isEmpty {
                    Text(document.summaryLine)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                AdminDocumentStatusBadge(group: document.statusGroup)
                    .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
    }
}
