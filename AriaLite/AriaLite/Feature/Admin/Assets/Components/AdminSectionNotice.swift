//
//  AdminSectionNotice.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Una riga discreta dentro una sezione: vuota ("No downtime logged") o non caricata (con il motivo).
//

import SwiftUI

struct AdminSectionNotice: View {
    let text: String
    var systemImage = "tray"
    var isError = false

    var body: some View {
        Label {
            Text(text).fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: isError ? "exclamationmark.triangle" : systemImage)
                .foregroundStyle(isError ? Color.orange : Color.secondary)
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
