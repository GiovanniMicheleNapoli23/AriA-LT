//
//  AriaChatComposer.swift
//  AriaLite
//
//  Created by Giovanni Michele on 26/09/26.
//
//  Dove si scrive ad Aria, in stile ChatGPT: una sola barra con "+" a sinistra (foto,
//  galleria, file, stile di risposta, ricerca web), il campo al centro, il microfono
//  per dettare (tocco = detta, pressione lunga = lingua e opzioni) e un pulsante tondo
//  che cambia ruolo (assistente dal vivo → invia → stop). Il contesto aggiunto e gli
//  strumenti attivi stanno sopra il campo, dentro la barra.
//  La logica sta in AriaChatComposerViewModel.
//

import PhotosUI
import SwiftUI

struct AriaChatComposer: View {
    @Bindable var model: AriaChatComposerViewModel
    var inputFocused: FocusState<Bool>.Binding
    /// Porta alla card che aspetta la decisione (approvazione di un tool).
    var onShowPending: () -> Void

    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if model.isLocked {
                // Pannello di vetro fino al bordo dello schermo, come domanda e procedura: ha già i suoi margini.
                AriaComposerLockedBar(isLoto: model.isLotoPending, onReview: onShowPending)
            } else {
                bar
                    .padding(.horizontal, 12)
                    .padding(.top, 6)
                    .padding(.bottom, 8)
            }
        }
        .animation(.snappy(duration: 0.22), value: model.isLocked)
        .animation(.snappy(duration: 0.22), value: model.hasTray)
        .fullScreenCover(isPresented: $model.showCamera) {
            CameraPicker { model.addCameraPhoto($0) }
                .ignoresSafeArea()
        }
        .photosPicker(isPresented: $model.showPhotos, selection: $model.photoItems, maxSelectionCount: 10, matching: .images)
        .onChange(of: model.photoItems) { _, items in model.photosPicked(items) }
        .fileImporter(isPresented: $model.showFiles, allowedContentTypes: AriaChatComposerViewModel.fileTypes,
                      allowsMultipleSelection: true) { model.filesPicked($0) }
        .task(id: model.dictationKey) { await model.loadDictationSupport() }
        .onChange(of: model.isLocked) { _, locked in model.lockChanged(locked) }
        .onChange(of: model.isContextRingGone) { _, gone in model.contextRingGoneChanged(gone) }
        .task(id: model.contextRefreshKey) { await model.refreshContextUsage() }
        .onDisappear { model.disappear() }
        .onChange(of: model.isVoiceLive) { _, live in model.voiceLiveChanged(live) }
    }

    private var bar: some View {
        VStack(alignment: .leading, spacing: 8) {
            if model.hasTray {
                AriaComposerTray(model: model)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            if model.isDictating {
                AriaDictationStrip(model: model)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if let error = model.dictation.error {
                Label(error, systemImage: "mic.slash")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 10)
                    .padding(.top, 6)
                    .transition(.opacity)
                    .accessibilityIdentifier("chat.dictation.error")
            }

            if dynamicTypeSize.isAccessibilitySize {
                // Testo molto grande: il campo prende tutta la riga e i pulsanti vanno sotto,
                // altrimenti quattro cerchi lascerebbero al testo poche lettere per riga.
                VStack(alignment: .leading, spacing: 2) {
                    field
                        .padding(.horizontal, 8)
                    HStack(alignment: .bottom, spacing: 2) {
                        AriaComposerPlusMenu(model: model)
                        Spacer(minLength: 0)
                        trailingButtons
                    }
                }
            } else {
                HStack(alignment: .bottom, spacing: 2) {
                    AriaComposerPlusMenu(model: model)
                    field
                    trailingButtons
                }
            }
        }
        .animation(.snappy(duration: 0.2), value: model.dictation.error)
        .animation(.snappy(duration: 0.22), value: model.isDictating)
        .animation(.snappy(duration: 0.22), value: model.contextUsage == nil)
        .padding(6)
        // Liquid Glass (material prima di iOS 26): i messaggi scorrono sotto la barra.
        .ariaGlass(in: RoundedRectangle(cornerRadius: 26, style: .continuous), interactive: true)
    }

    private var field: some View {
        TextField(model.placeholder, text: $model.draft, axis: .vertical)
            .font(.body)
            // In orizzontale con la tastiera restano ~150 pt: oltre due righe il campo scorre al suo interno.
            .lineLimit(verticalSizeClass == .compact ? 1...2 : 1...6)
            .focused(inputFocused)
            .padding(.vertical, 9)
            .padding(.leading, 2)
            .accessibilityIdentifier("chat.input")
    }

    @ViewBuilder
    private var trailingButtons: some View {
        if let usage = model.contextUsage, !model.dictation.isListening {
            AriaContextRing(model: model, usage: usage)
                .transition(.scale(scale: 0.6).combined(with: .opacity))
        }

        AriaDictationMicButton(model: model)

        AriaComposerPrimaryButton(model: model) { inputFocused.wrappedValue = false }
            .padding(.leading, 2)
            // Il cerchio cresce col testo fino ad AX1, poi si ferma: i pulsanti devono stare in riga.
            .dynamicTypeSize(...AriaChatComposer.maxButtonTypeSize)
    }

    /// Oltre questa taglia i cerchi della barra (e le loro icone) smettono di crescere.
    static let maxButtonTypeSize = DynamicTypeSize.accessibility1
}

/// Il "+": foto, galleria, file, stile di risposta e ricerca web.
private struct AriaComposerPlusMenu: View {
    @Bindable var model: AriaChatComposerViewModel

    var body: some View {
        Menu {
            Section {
                Button("Camera", systemImage: "camera") { model.showCamera = true }
                    .disabled(!model.cameraAvailable)
                Button("Photos", systemImage: "photo.on.rectangle") { model.showPhotos = true }
                Button("Files", systemImage: "paperclip") { model.showFiles = true }
            }
            Section {
                Picker(selection: $model.style) {
                    ForEach(AriaChatStyle.allCases, id: \.self) { style in
                        Label(style.title, systemImage: style.icon).tag(style)
                    }
                } label: {
                    Label("Response style", systemImage: model.style.icon)
                }
                .pickerStyle(.menu)
                Toggle(isOn: $model.webSearch) {
                    Label("Web search", systemImage: "globe")
                }
            }
        } label: {
            // Il limite sta sull'etichetta, non sul Menu: le voci del menu seguono il testo di sistema.
            AriaComposerPlusGlyph()
                .dynamicTypeSize(...AriaChatComposer.maxButtonTypeSize)
        }
        .accessibilityLabel("Add")
    }
}

private struct AriaComposerPlusGlyph: View {
    @ScaledMetric(relativeTo: .body) private var side: CGFloat = 38

    var body: some View {
        Image(systemName: "plus")
            .font(.title3)
            .foregroundStyle(.primary)
            .frame(width: side, height: side)
            .contentShape(Circle())
    }
}

/// Il pulsante tondo: invia, ferma, o accende la voce dal vivo.
private struct AriaComposerPrimaryButton: View {
    let model: AriaChatComposerViewModel
    /// Dopo un invio la tastiera si chiude.
    var onSent: () -> Void

    @ScaledMetric(relativeTo: .body) private var side: CGFloat = 38

    var body: some View {
        Button {
            if model.primaryAction() { onSent() }
        } label: {
            ZStack {
                Circle()
                    .fill(tint)
                    .frame(width: side, height: side)
                if model.isVoiceConnecting {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: symbol)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .contentTransition(.symbolEffect(.replace))
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(model.isPrimaryDisabled)
        .opacity(model.isPrimaryDimmed ? 0.4 : 1)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
        // L'invio lo segnala la chat (AriaChatHaptics); qui solo stop e voce.
        .sensoryFeedback(.impact(weight: .medium), trigger: model.tapCount)
        .sensoryFeedback(.impact(weight: .light), trigger: model.contextItems.count) { old, new in new > old }
    }

    private var tint: Color {
        switch model.primaryRole {
        case .stop: .red
        case .idle: Color.secondary.opacity(0.35)
        case .send, .voice: .accentColor
        }
    }

    private var symbol: String {
        switch model.primaryRole {
        case .send, .idle: "arrow.up"
        case .stop: "stop.fill"
        case .voice: "waveform"
        }
    }

    private var label: LocalizedStringKey {
        switch model.primaryRole {
        case .send, .idle: "Send"
        case .stop: "Stop"
        case .voice: "Voice"
        }
    }

    private var identifier: String {
        switch model.primaryRole {
        case .send, .idle: "chat.send"
        case .stop: "chat.stop"
        case .voice: "chat.voice"
        }
    }
}
