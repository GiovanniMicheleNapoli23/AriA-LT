//
//  AdminSparePartHeader.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  L'intestazione del dettaglio: foto (se c'è un URL https valido), codice, stato e nome.
//

import SwiftUI

struct AdminSparePartHeader: View {
    let part: AdminSparePart
    let photoURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let photoURL { photo(photoURL) }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(verbatim: part.code)
                    .font(.subheadline.monospaced().weight(.semibold))
                    .foregroundStyle(Color.liteAccent)
                    .textSelection(.enabled)
                if let status = part.status { AdminSparePartStatusBadge(status: status) }
                Spacer()
            }
            Text(verbatim: part.title)
                .font(.title3.weight(.bold))
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
    }

    private func photo(_ url: URL) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFit()
            case .failure:
                Image(systemName: "photo")
                    .font(.largeTitle)
                    .foregroundStyle(.tertiary)
            default:
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, minHeight: 120, maxHeight: 220)
        .background(Color.liteAccent.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityLabel(Text("Photo of the spare part"))
    }
}
