//
//  AriaOfflineNotice.swift
//  AriaLite
//
//  Created by Giovanni Michele on 08/10/26.
//
//  "Aria è offline": il sistema non si raggiunge. Non è un guasto né una password sbagliata,
//  quindi non è rosso: un avviso ambra con icona, spiegazione e, se serve, "Riprova".
//

import SwiftUI

struct AriaOfflineNotice: View {
    enum Style { case card, compact }

    var style: Style = .card
    var detail: LocalizedStringKey = "The system can't be reached right now. Check your connection, or try again in a moment."
    var onRetry: (() -> Void)? = nil
    var onDismiss: (() -> Void)? = nil

    private let tint = Color.orange

    var body: some View {
        switch style {
        case .card: card
        case .compact: compact
        }
    }

    private var card: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text("Aria is offline")
                    .font(.system(size: 14, weight: .semibold))
                Text(detail)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let onRetry {
                    Button("Retry", action: onRetry)
                        .font(.system(size: 13, weight: .semibold))
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                        .controlSize(.small)
                        .tint(tint)
                        .padding(.top, 6)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss")
            }
        }
        .padding(12)
        .background(tint.opacity(0.09), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(tint.opacity(0.25), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var compact: some View {
        Label("Aria is offline. Try again in a moment.", systemImage: "wifi.slash")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(tint)
    }
}

#Preview {
    VStack(spacing: 16) {
        AriaOfflineNotice(onRetry: {}, onDismiss: {})
        AriaOfflineNotice(style: .compact)
    }
    .padding()
}
