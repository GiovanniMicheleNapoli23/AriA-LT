//
//  AdminUsageStorageSection.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  La scheda "Knowledge storage" (contratto 3.8): i GB usati, la barra della capacità (con la parte oltre tratteggiata),
//  l'avviso e, per un titolare, l'azione per scrivere alle vendite. In attesa con un segnaposto, fallita con "Retry".
//

import SwiftUI

struct AdminUsageStorageSection: View {
    let state: AdminUsageStorageState
    let title: String
    let retry: () -> Void

    var body: some View {
        switch state {
        case .loading:
            AdminUsageCardFrame(title: Text(verbatim: title)) {
                AdminUsagePlaceholderLines(lines: 3)
            }
        case .failed:
            AdminUsageCardFrame(title: Text(verbatim: title)) {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Storage usage isn't available right now").font(.subheadline.weight(.semibold))
                        Text("Your documents are safe and chat keeps working.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityElement(children: .combine)
                    Button(action: retry) { Label("Retry", systemImage: "arrow.clockwise") }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                }
            }
        case .ready(let card):
            AdminUsageStorageReady(card: card)
        }
    }
}

private struct AdminUsageStorageReady: View {
    let card: AdminUsageStorageCard

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        AdminUsageCardFrame(title: Text(verbatim: card.title)) {
            VStack(alignment: .leading, spacing: 10) {
                facts
                if card.hasCapacity {
                    AdminUsageStorageBar(fill: card.fillFraction, over: card.overFraction, tint: card.tone.tint)
                    footer
                }
                if let note = card.contractNote { footnote(note) }
                if let addon = card.addonText { footnote(addon) }
                if let asOf = card.asOfToday { footnote(asOf) }
                if let notice = card.notice { noticeView(notice) }
                if let action = card.action { actionLink(action) }
            }
        }
    }

    private var facts: some View {
        VStack(alignment: .leading, spacing: 4) {
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
                : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 6))
            layout {
                Text(verbatim: card.used).font(.title2.weight(.semibold).monospacedDigit())
                Text(verbatim: card.ofText).font(.footnote).foregroundStyle(.secondary)
                if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 8) }
                if let badge = card.badge { badgeView(badge) }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var footer: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
        return layout {
            if let percent = card.percentText { Text(verbatim: percent).monospacedDigit() }
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 8) }
            if let left = card.leftText { Text(verbatim: left).monospacedDigit() }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
    }

    private func badgeView(_ text: String) -> some View {
        Text(verbatim: text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(card.tone.tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(card.tone.tint.opacity(0.14), in: Capsule())
    }

    private func footnote(_ text: String) -> some View {
        Text(verbatim: text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func noticeView(_ notice: AdminUsageStorageCard.Notice) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(card.tone.tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: notice.title).font(.subheadline.weight(.semibold))
                Text(verbatim: notice.body).font(.footnote).foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(card.tone.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }

    private func actionLink(_ action: AdminUsageMailAction) -> some View {
        Link(destination: action.url) {
            Text(verbatim: action.label)
                .font(.subheadline.weight(.medium))
                .multilineTextAlignment(.leading)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .foregroundStyle(.primary)
    }
}

/// La barra dell'archivio: la parte piena fino alla capacità e, a destra, quella oltre (grigia e tratteggiata).
struct AdminUsageStorageBar: View {
    let fill: Double
    let over: Double
    let tint: Color

    @ScaledMetric(relativeTo: .footnote) private var height: CGFloat = 8

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let filled = width * min(1, max(0, fill))
            let overWidth = width * min(1, max(0, over))
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.1))
                Capsule().fill(tint).frame(width: max(fill > 0 ? height : 0, filled))
                if overWidth > 0 {
                    Capsule()
                        .strokeBorder(Color.secondary, style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                        .background(Capsule().fill(Color.secondary.opacity(0.25)))
                        .frame(width: max(height, overWidth))
                        .offset(x: max(0, filled))
                }
            }
            .frame(maxHeight: .infinity)
        }
        .frame(height: height + 6)
        .animation(.smooth(duration: 0.4), value: fill)
        .accessibilityHidden(true)
    }
}
