//
//  AriaUsageErrorView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Lo stato di errore dei fogli di effort e crediti: titolo, spiegazione e "Try again". La chat continua a
//  funzionare, quindi il tono è calmo (ambra, mai rosso).
//

import SwiftUI

struct AriaUsageErrorView: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    var isBusy = false
    let retry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(Color.liteWarning)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button(action: retry) {
                HStack(spacing: 8) {
                    if isBusy { ProgressView().controlSize(.small) }
                    Label("Try again", systemImage: "arrow.clockwise")
                }
            }
            .buttonStyle(.bordered)
            .disabled(isBusy)
            .accessibilityIdentifier("usage.retry")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.liteSurface, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .contain)
    }
}
