//
//  AriaComposerLockedBar.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Al posto del composer quando Aria aspetta una decisione (approvazione o LOTO).
//

import SwiftUI

/// Con una pausa aperta il backend non accetta nuovi turni: si dice perché e dove decidere.
/// Vetro come gli altri pannelli in basso (il contenuto resta nell'area sicura, mai sotto l'indicatore home);
/// i messaggi ci scorrono sotto ma la lista lascia lo spazio del pannello, quindi niente si sovrappone.
struct AriaComposerLockedBar: View {
    let isLoto: Bool
    var onReview: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .callout) private var iconBox: CGFloat = 34

    /// Col testo molto grande "Rivedi" va sotto il messaggio, che altrimenti andrebbe a capo a ogni parola.
    private var layout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(spacing: 12))
    }

    var body: some View {
        layout {
            Image(systemName: isLoto ? "lock.shield.fill" : "hand.raised.fill")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.orange)
                .frame(width: iconBox, height: iconBox)
                .background(Color.orange.opacity(0.16), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text("Aria is waiting for your decision")
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Text("Approve or reject the action to continue.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onReview) {
                Text("Review")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 6)
                    .frame(minHeight: 30)
            }
            .ariaProminentGlassButtonStyle(tint: .orange)
            .buttonBorderShape(.capsule)
            .fixedSize()
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ariaBottomPanel(stroke: Color.orange.opacity(0.35))
        .padding(.top, 4)
    }
}
