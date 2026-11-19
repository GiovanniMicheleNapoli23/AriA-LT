//
//  AdminUsageAlertBanner.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  L'avviso in testa alla pagina Usage (contratto 3.3): icona del tono, titolo, frase e le azioni. Il testo arriva già
//  scritto dal view model; l'azione la esegue chi apre la vista.
//

import SwiftUI

struct AdminUsageAlertBanner: View {
    let alert: AdminUsageAlert
    let perform: (AdminUsageAlertAction) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: alert.tone.symbol)
                .font(.title3)
                .foregroundStyle(alert.tone.tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 10) {
                texts
                if !alert.actions.isEmpty { actions }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(alert.tone.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(alert.tone.tint.opacity(0.3), lineWidth: 1))
        // Il testo si legge insieme; i bottoni restano elementi a sé.
        .accessibilityElement(children: .contain)
    }

    private var texts: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: alert.title)
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            if let body = alert.body {
                Text(verbatim: body)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var actions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { buttons }
            VStack(alignment: .leading, spacing: 8) { buttons }
        }
    }

    private var buttons: some View {
        ForEach(alert.actions) { action in
            Button { perform(action) } label: {
                Text(verbatim: action.label)
                    .font(.subheadline.weight(.medium))
                    .multilineTextAlignment(.leading)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .foregroundStyle(.primary)
        }
    }
}
