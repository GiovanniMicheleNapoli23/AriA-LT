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
            Image(systemName: icon).font(.system(size: 12, weight: .semibold))
            Text(title).font(.system(size: 13, weight: .medium))
            Button(action: remove) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 18, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove")
        }
        .foregroundStyle(Color.accentColor)
        .padding(.leading, 11)
        .padding(.trailing, 6)
        .frame(height: 32)
        .background(Color.accentColor.opacity(0.12), in: Capsule())
    }
}

/// Una foto o un file aggiunto, con la "x" per toglierlo.
private struct AriaContextTile: View {
    let item: AriaContextItem
    var onRemove: () -> Void

    var body: some View {
        Group {
            if item.kind == .image, let data = item.thumbnail, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "doc.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.accentColor)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.name)
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(1)
                        if let size = item.size {
                            Text(Int64(size), format: .byteCount(style: .file))
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: 140, alignment: .leading)
                }
                .padding(.horizontal, 10)
                .frame(height: 56)
                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .overlay(alignment: .topTrailing) {
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
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
            ZStack {
                Circle().stroke(Color.primary.opacity(0.12), lineWidth: 2.5)
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(tint, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.smooth(duration: 0.5), value: fraction)
            }
            .frame(width: 18, height: 18)
            .frame(width: 36, height: 44)
            .contentShape(Rectangle())
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
                    .font(.system(size: 15, weight: .semibold))
                Spacer(minLength: 16)
                Text(fraction, format: .percent.precision(.fractionLength(0)))
                    .font(.system(size: 15, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(tint)
            }
            Gauge(value: fraction) { EmptyView() }
                .gaugeStyle(.accessoryLinearCapacity)
                .tint(tint)
                .accessibilityHidden(true)
            Text("\(usage.usedTokens.formatted(.number.notation(.compactName))) of \(usage.limitTokens.formatted(.number.notation(.compactName))) tokens")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            if usage.isMostlyOverhead {
                Text("Most of it is manuals and instructions Aria reads, which making room can't reduce.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("When it fills up, Aria summarizes the oldest messages. The conversation itself is kept.")
                    .font(.system(size: 12))
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
