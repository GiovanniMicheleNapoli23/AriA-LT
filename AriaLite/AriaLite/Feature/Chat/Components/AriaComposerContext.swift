//
//  AriaComposerContext.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il contesto nel composer: foto, file e strumenti attivi sopra il campo, e l'anello della
//  memoria della conversazione con i suoi dettagli.
//

import SwiftUI

/// Strumenti attivi e contesto aggiunto, in una riga che scorre sopra il campo.
struct AriaComposerTray: View {
    let model: AriaChatComposerViewModel
    @ScaledMetric(relativeTo: .footnote) private var pillHeight: CGFloat = 32
    @ScaledMetric(relativeTo: .caption2) private var removeSide: CGFloat = 18

    var body: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .bottom, spacing: 8) {
                if model.webSearch {
                    toolPill(String(localized: "Web search"), icon: "globe") { model.clearWebSearch() }
                }
                if model.style != .auto {
                    toolPill(model.style.shortTitle, icon: model.style.icon) { model.clearStyle() }
                }
                ForEach(model.contextItems) { item in
                    AriaContextTile(item: item) { model.removeContextItem(item.id) }
                }
            }
            .padding(.horizontal, 6)
            .padding(.top, 6)
        }
        .scrollIndicators(.hidden)
        .animation(.snappy, value: model.contextItems)
    }

    private func toolPill(_ title: String, icon: String, remove: @escaping () -> Void) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.caption.weight(.semibold))
            Text(title).font(.footnote.weight(.medium))
            Button(action: remove) {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.bold))
                    .frame(width: removeSide, height: removeSide)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove")
        }
        .foregroundStyle(Color.accentColor)
        .padding(.leading, 11)
        .padding(.trailing, 6)
        .frame(minHeight: pillHeight)
        .background(Color.accentColor.opacity(0.12), in: Capsule())
    }
}

/// Una foto o un file aggiunto, con la "x" per toglierlo.
private struct AriaContextTile: View {
    let item: AriaContextItem
    var onRemove: () -> Void
    /// Foto e file alti uguali: crescono insieme col testo del nome.
    @ScaledMetric(relativeTo: .footnote) private var tileSide: CGFloat = 56
    @ScaledMetric(relativeTo: .caption2) private var removeSide: CGFloat = 20
    @ScaledMetric(relativeTo: .footnote) private var nameWidth: CGFloat = 140

    var body: some View {
        Group {
            if item.kind == .image, let data = item.thumbnail, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: tileSide, height: tileSide)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "doc.fill")
                        .font(.body)
                        .foregroundStyle(Color.accentColor)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.name)
                            .font(.footnote.weight(.medium))
                            .lineLimit(1)
                        if let size = item.size {
                            Text(Int64(size), format: .byteCount(style: .file))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: nameWidth, alignment: .leading)
                }
                .padding(.horizontal, 10)
                .frame(minHeight: tileSide)
                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .overlay(alignment: .topTrailing) {
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: removeSide, height: removeSide)
                    .background(Color.black.opacity(0.6), in: Circle())
            }
            .buttonStyle(.plain)
            .offset(x: 6, y: -6)
            .accessibilityLabel(Text("Remove \(item.name)"))
        }
        .padding(.top, 6)
        .padding(.trailing, 6)
    }
}

/// Quanto della memoria di Aria usa la conversazione: un anello che si riempie. Tocco = dettagli e "Fai spazio".
struct AriaContextRing: View {
    @Bindable var model: AriaChatComposerViewModel
    let usage: AriaContextUsage

    private var fraction: Double { model.contextFraction(usage) }

    private var tint: Color {
        switch model.contextLevel(usage) {
        case .full: .red
        case .high: .orange
        case .normal: .secondary
        }
    }

    var body: some View {
        Button { model.showContext = true } label: {
            // Il limite sta sull'etichetta: il popover dei dettagli segue il testo di sistema.
            AriaContextRingGlyph(fraction: fraction, tint: tint)
                .dynamicTypeSize(...AriaChatComposer.maxButtonTypeSize)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Conversation memory")
        .accessibilityValue(Text(fraction, format: .percent.precision(.fractionLength(0))))
        .accessibilityIdentifier("chat.contextRing")
        .popover(isPresented: $model.showContext, arrowEdge: .bottom) {
            AriaContextPopover(usage: usage, fraction: fraction, tint: tint, isCompacting: model.isCompacting) {
                model.compactContext()
            }
            .presentationCompactAdaptation(.popover)
        }
    }
}

/// L'anello cresce col testo come gli altri cerchi della barra (stesso limite).
private struct AriaContextRingGlyph: View {
    let fraction: Double
    let tint: Color
    @ScaledMetric(relativeTo: .body) private var ring: CGFloat = 18
    @ScaledMetric(relativeTo: .body) private var width: CGFloat = 36
    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 44

    var body: some View {
        ZStack {
            Circle().stroke(Color.primary.opacity(0.12), lineWidth: 2.5)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(tint, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.smooth(duration: 0.5), value: fraction)
        }
        .frame(width: ring, height: ring)
        .frame(width: width, height: height)
        .contentShape(Rectangle())
    }
}

/// I dettagli dell'anello: percentuale, dove è finito lo spazio e "Fai spazio" quando il server lo permette.
/// Compattare riassume i messaggi più vecchi per Aria; la conversazione salvata resta intera.
private struct AriaContextPopover: View {
    let usage: AriaContextUsage
    let fraction: Double
    let tint: Color
    let isCompacting: Bool
    let compact: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Conversation memory")
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 16)
                Text(fraction, format: .percent.precision(.fractionLength(0)))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(tint)
            }
            Gauge(value: fraction) { EmptyView() }
                .gaugeStyle(.accessoryLinearCapacity)
                .tint(tint)
                .accessibilityHidden(true)
            Text("\(usage.usedTokens.formatted(.number.notation(.compactName))) of \(usage.limitTokens.formatted(.number.notation(.compactName))) tokens")
                .font(.caption)
                .foregroundStyle(.secondary)
            if usage.isMostlyOverhead {
                Text("Most of it is manuals and instructions Aria reads, which making room can't reduce.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("When it fills up, Aria summarizes the oldest messages. The conversation itself is kept.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if usage.canCompact {
                Button(action: compact) {
                    HStack(spacing: 6) {
                        if isCompacting { ProgressView().controlSize(.small) }
                        Text("Make room")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(isCompacting)
                .accessibilityIdentifier("chat.makeRoom")
            }
        }
        .padding(16)
        .frame(width: 280)
    }
}
