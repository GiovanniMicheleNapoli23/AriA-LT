//
//  AdminUsageFooterNote.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  La nota in fondo alla pagina Usage: "Amounts in EUR, the spending limit and usage notices are managed by owners."
//

import SwiftUI

struct AdminUsageFooterNote: View {
    let text: String

    var body: some View {
        Text(verbatim: text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }
}
