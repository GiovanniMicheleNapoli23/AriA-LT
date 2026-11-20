//
//  AriaChatComposer.swift
//  AriaLite
//
//  Created by Giovanni Michele on 26/09/26.
//
//  Dove si scrive ad Aria, in stile ChatGPT: una sola barra con "+" a sinistra (foto,
//  galleria, file, connettori, stile di risposta, ricerca web), il campo al centro, il microfono
//  per dettare (tocco = detta, pressione lunga = lingua e opzioni) e un pulsante tondo
//  che cambia ruolo (assistente dal vivo → invia → stop). Il contesto aggiunto e gli
//  strumenti attivi stanno sopra il campo, dentro la barra; con la tastiera aperta, sotto
//  il campo, i pulsanti scendono in una riga: "+", effort, memoria, microfono e invio
//  (in orizzontale resta tutto su una riga, lo spazio è poco).
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
    /// I connettori (lista e Marketplace), se la shell offre il Marketplace.
    @Environment(\.chatConnectors) private var chatConnectors
    /// Come il lato dei cerchi (stessa base e stessa scala).
    @ScaledMetric(relativeTo: .body) private var rowHeight: CGFloat = 38

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
        .task(id: model.dictationKey) { await model.loadEffortConfig() }
        .task(id: model.effortEstimatesKey) { await model.loadEffortEstimates() }
        .onChange(of: inputFocused.wrappedValue, initial: true) { _, focused in model.isInputFocused = focused }
        .sheet(isPresented: $model.showEffort) {
            AriaEffortSheet(chat: model.chat, backend: model.backend)
        }
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

            // Il campo resta sempre nello stesso posto della gerarchia: se cambiasse contenitore verrebbe ricreato e
            // perderebbe il focus (e la tastiera) proprio quando la riga sotto compare. Si spostano solo i pulsanti.
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .bottom, spacing: 2) {
                    if !isExpanded {
                        plusMenu
                    }
                    field
                        .padding(.leading, isExpanded ? 8 : 0)
                    if !isExpanded, showsUsageRow {
                        // In orizzontale con la tastiera restano ~150 pt: niente riga in più, l'effort in linea.
                        AriaComposerUsageRow(model: model)
                            .fixedSize()
                            .frame(minHeight: rowHeight)
                            .transition(.opacity)
                    }
                    if !isExpanded {
                        // Su una sola riga la memoria sta tra il campo e il microfono.
                        contextRing
                        micAndPrimary
                    }
                }
                if isExpanded {
                    // Con la tastiera aperta i pulsanti scendono sotto il campo, tutti su una riga: "+" ed effort a
                    // sinistra, memoria, microfono e invio a destra. Sopra resta solo il testo.
                    HStack(alignment: .center, spacing: 2) {
                        plusMenu
                        if showsUsageRow {
                            AriaComposerUsageRow(model: model)
                                // Se la riga è stretta si accorcia l'etichetta dell'effort, non i cerchi.
                                .layoutPriority(-1)
                                .transition(.opacity)
                        }
                        Spacer(minLength: 0)
                        contextRing
                        micAndPrimary
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .animation(.snappy(duration: 0.22), value: showsUsageRow)
        .animation(.snappy(duration: 0.22), value: isExpanded)
        .animation(.snappy(duration: 0.2), value: model.dictation.error)
        .animation(.snappy(duration: 0.22), value: model.isDictating)
        .animation(.snappy(duration: 0.22), value: model.contextUsage == nil)
        .padding(6)
        // Liquid Glass (material prima di iOS 26): i messaggi scorrono sotto la barra.
        .ariaGlass(in: RoundedRectangle(cornerRadius: 26, style: .continuous), interactive: true)
    }

    private var showsUsageRow: Bool { model.showsUsageRow }

    /// Il "+" con il popover dei connettori, che si apre dalla sua voce e punta al "+".
    private var plusMenu: some View {
        AriaComposerPlusMenu(model: model, offersConnectors: chatConnectors != nil)
            .ariaConnectorsPopover(model: model, access: chatConnectors, onManage: dismissKeyboard)
    }

    /// Campo sopra e pulsanti sotto: con la riga dell'effort (in verticale) o col testo molto grande.
    private var isExpanded: Bool {
        dynamicTypeSize.isAccessibilitySize || (showsUsageRow && verticalSizeClass != .compact)
    }

    /// "Manage connectors" porta al Marketplace: la tastiera si chiude prima.
    private func dismissKeyboard() {
        inputFocused.wrappedValue = false
    }

    private var field: some View {
        TextField(model.placeholder, text: $model.draft, axis: .vertical)
            .font(.body)
            // In orizzontale con la tastiera restano ~150 pt: oltre due righe il campo scorre al suo interno.
            .lineLimit(verticalSizeClass == .compact ? 1...2 : 1...6)
            .focused(inputFocused)
            .padding(.vertical, 6)
            .padding(.leading, 2)
            // Alto quanto i cerchi: a riga singola il testo, il "+", il microfono e il pulsante hanno lo stesso centro.
            .frame(minHeight: rowHeight)
            .accessibilityIdentifier("chat.input")
    }

    @ViewBuilder
    private var contextRing: some View {
        if let usage = model.contextUsage, !model.dictation.isListening {
            AriaContextRing(model: model, usage: usage)
                .transition(.scale(scale: 0.6).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private var micAndPrimary: some View {
        AriaDictationMicButton(model: model)

        AriaComposerPrimaryButton(model: model) { inputFocused.wrappedValue = false }
            .padding(.leading, 2)
            // Il cerchio cresce col testo fino ad AX1, poi si ferma: i pulsanti devono stare in riga.
            .dynamicTypeSize(...AriaChatComposer.maxButtonTypeSize)
    }

    /// Oltre questa taglia i cerchi della barra (e le loro icone) smettono di crescere.
    static let maxButtonTypeSize = DynamicTypeSize.accessibility1
}

/// Il "+": foto, galleria, file, connettori, stile di risposta e ricerca web. L'effort ha il suo menu.
private struct AriaComposerPlusMenu: View {
    @Bindable var model: AriaChatComposerViewModel
    /// La voce "Connectors" c'è solo se la shell offre il Marketplace.
    let offersConnectors: Bool

    var body: some View {
        Menu {
            Section {
                Button("Camera", systemImage: "camera") { model.showCamera = true }
                    .disabled(!model.cameraAvailable)
                Button("Photos", systemImage: "photo.on.rectangle") { model.showPhotos = true }
                Button("Files", systemImage: "paperclip") { model.showFiles = true }
            }
            if offersConnectors {
                Section {
                    Button("Connectors", systemImage: "powerplug") { model.showConnectors = true }
                        .accessibilityIdentifier("chat.connectors")
                }
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
                // Nel menu resta la spunta di sistema, non l'interruttore verde dell'app.
                .toggleStyle(.automatic)
            }
        } label: {
            // Il limite sta sull'etichetta, non sul Menu: le voci del menu seguono il testo di sistema.
            AriaComposerPlusGlyph()
                .dynamicTypeSize(...AriaChatComposer.maxButtonTypeSize)
        }
        .accessibilityLabel("Add")
    }
}

/// Il "+" in un cerchio pieno e tenue, alto quanto gli altri cerchi della barra.
private struct AriaComposerPlusGlyph: View {
    @ScaledMetric(relativeTo: .body) private var side: CGFloat = 38

    var body: some View {
        Image(systemName: "plus")
            .font(.body.weight(.semibold))
            .foregroundStyle(.primary)
            .frame(width: side, height: side)
            .background(Color.primary.opacity(0.08), in: Circle())
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
                    ProgressView().tint(onTint)
                } else {
                    Image(systemName: symbol)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(onTint)
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

    /// L'icona sopra il cerchio: nera sull'accento chiaro della modalità scura.
    private var onTint: Color {
        switch model.primaryRole {
        case .send, .voice: .liteOnAccent
        case .stop, .idle: .white
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
