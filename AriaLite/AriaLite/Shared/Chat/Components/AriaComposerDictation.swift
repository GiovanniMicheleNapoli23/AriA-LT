//
//  AriaComposerDictation.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La dettatura nel composer: il microfono (tocco = detta, tocco lungo = lingua) e la striscia
//  sopra il campo mentre si ascolta o si trascrive.
//

import SwiftUI

/// Tocco = detta nel campo; tocco lungo = lingua di dettatura e chi trascrive (la lingua si sceglie anche
/// dal menu "···" della chat).
struct AriaDictationMicButton: View {
    let model: AriaChatComposerViewModel
    @AppStorage(AriaDictation.languageKey) private var dictationLanguage = AriaDictation.automatic

    var body: some View {
        Menu {
            Section {
                Picker(selection: $dictationLanguage) {
                    Text("Automatic").tag(AriaDictation.automatic)
                    ForEach(AriaDictation.languages) { language in
                        Text(verbatim: language.label).tag(language.code)
                    }
                } label: {
                    Label("Dictation language", systemImage: "globe")
                    Text(model.dictationLanguageName(dictationLanguage))
                }
                .pickerStyle(.menu)
                // La lingua vale per tutta la dettatura: si cambia da fermi.
                .disabled(model.isDictating)
            } header: {
                Text(model.dictationSourceTitle)
            }
        } label: {
            // Il limite sta sull'etichetta, non sul Menu: le voci del menu seguono il testo di sistema.
            AriaMicGlyph(dictation: model.dictation)
                .dynamicTypeSize(...AriaChatComposer.maxButtonTypeSize)
        } primaryAction: {
            model.toggleDictation()
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .disabled(model.isMicDisabled)
        .accessibilityLabel(Text(model.micAccessibilityLabel))
        .accessibilityValue(Text(model.dictationLanguageName(dictationLanguage)))
        .accessibilityHint("Touch and hold to choose the dictation language.")
        .accessibilityIdentifier("chat.mic")
    }
}

/// Il microfono della barra. Sta in una vista sua: il volume cambia decine di volte al secondo e ridisegna
/// solo questo cerchio, non tutta la barra.
private struct AriaMicGlyph: View {
    let dictation: AriaDictation
    @ScaledMetric(relativeTo: .body) private var side: CGFloat = 38

    var body: some View {
        ZStack {
            if dictation.isListening {
                Circle()
                    .fill(Color.accentColor.opacity(0.14))
                    .scaleEffect(1 + CGFloat(dictation.level) * 0.35)
                    .animation(.linear(duration: 0.09), value: dictation.level)
            }
            if dictation.isTranscribing || dictation.isStarting {
                ProgressView()
            } else {
                Image(systemName: dictation.isListening ? "stop.fill" : "mic")
                    .font(dictation.isListening ? Font.subheadline : .body)
                    .foregroundStyle(dictation.isListening ? Color.accentColor : .primary)
                    .contentTransition(.symbolEffect(.replace))
            }
        }
        .frame(width: side, height: side)
        .contentShape(Circle())
    }
}

/// In ascolto: da quanto si parla e quanto resta, chi trascrive e "Scarta". Poi l'attesa del testo finale.
struct AriaDictationStrip: View {
    let model: AriaChatComposerViewModel

    private var dictation: AriaDictation { model.dictation }
    @ScaledMetric(relativeTo: .caption2) private var buttonSide: CGFloat = 26

    var body: some View {
        HStack(spacing: 8) {
            if dictation.isListening, let startedAt = dictation.startedAt {
                Image(systemName: "circle.fill")
                    .font(.caption2)
                    .imageScale(.small)
                    .foregroundStyle(.red)
                    .symbolEffect(.pulse)
                    .accessibilityHidden(true)
                TimelineView(.periodic(from: startedAt, by: 1)) { context in
                    let elapsed = max(0, context.date.timeIntervalSince(startedAt))
                    let limit = Double(dictation.recordingLimit.components.seconds)
                    Text(Duration.seconds(elapsed).formatted(.time(pattern: .minuteSecond)))
                        .monospacedDigit()
                        .foregroundStyle(limit - elapsed <= 10 ? Color.orange : Color.primary)
                        .accessibilityLabel(Text("Dictating for \(Duration.seconds(elapsed).formatted(.units(allowed: [.minutes, .seconds], width: .wide)))"))
                }
                .font(.caption.weight(.semibold))
                Text(model.dictationSourceTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .accessibilityIdentifier("chat.dictation.source")
                Spacer(minLength: 4)
                stripButton(systemImage: "xmark", label: "Discard dictation", identifier: "chat.dictation.discard") {
                    model.discardDictation()
                }
            } else {
                ProgressView().controlSize(.mini)
                Text("Writing it down…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 4)
                stripButton(systemImage: "checkmark", label: "Keep the text as it is", identifier: "chat.dictation.keep") {
                    model.keepDictatedText()
                }
            }
        }
        .padding(.leading, 10)
        .padding(.top, 2)
    }

    /// Cerchio piccolo da vedere, area da 44 pt da toccare (si usa anche coi guanti).
    private func stripButton(systemImage: String, label: LocalizedStringKey, identifier: String,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
                .frame(width: buttonSide, height: buttonSide)
                .background(Color(.tertiarySystemFill), in: Circle())
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }
}
