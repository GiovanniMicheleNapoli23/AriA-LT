//
//  AdminLLMUsageNote.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il messaggio di una sezione che non si è caricata, con "Riprova", e le note sui conteggi senza prezzo.
//

import SwiftUI

struct AdminLLMUsageNote: View {
    let message: String
    var retry: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.footnote)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let retry {
                Button("Try again", action: retry)
                    .font(.footnote.weight(.semibold))
                    .buttonStyle(.borderless)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 12))
    }
}
