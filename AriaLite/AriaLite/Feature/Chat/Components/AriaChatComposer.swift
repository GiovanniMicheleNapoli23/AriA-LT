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
//

import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct AriaChatComposer: View {
    let chat: AriaAgentChat
    let backend: AriaBackend
    var voice: AriaVoiceViewModel?
    @Binding var draft: String
    var inputFocused: FocusState<Bool>.Binding
    /// Porta alla card che aspetta la decisione (approvazione di un tool).
    var onShowPending: () -> Void

    @State private var tapCount = 0
    @State private var showCamera = false
    @State private var showPhotos = false
    @State private var showFiles = false
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var dictation = AriaDictation()
    /// L'ultimo testo scritto dalla dettatura: se nel frattempo l'operatore l'ha cambiato, Whisper non lo sovrascrive.
    @State private var dictatedDraft: String?
    /// Cosa fa la dettatura su questo server (chiesto una volta, all'apertura del composer).
    @State private var dictationSupport = AriaDictationSupport.none
    /// Il campo prima della dettatura: "Scarta" lo rimette com'era.
    @State private var draftBeforeDictation: String?
    @State private var showContext = false
    @AppStorage(AriaDictation.languageKey) private var dictationLanguage = AriaDictation.automatic
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private var trimmed: String { draft.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var hasText: Bool { !trimmed.isEmpty }
    private var isLocked: Bool { chat.pendingInterrupt != nil }
    private var hasPlant: Bool { backend.activePlantId != nil }
    private var hasTray: Bool { !chat.contextItems.isEmpty || chat.webSearch || chat.style != .auto }
    private var cameraAvailable: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    /// Gli stessi formati del context dock della web (CONTEXT_FILE_ACCEPT).
    private static let fileTypes: [UTType] = [
        .image, .pdf, .plainText, .commaSeparatedText,
        UTType(filenameExtension: "md"), UTType(filenameExtension: "doc"), UTType(filenameExtension: "docx"),
        UTType(filenameExtension: "xls"), UTType(filenameExtension: "xlsx"),
    ].compactMap { $0 }

    var body: some View {
        Group {
            if isLocked {
                // Pannello di vetro fino al bordo dello schermo, come domanda e procedura: ha già i suoi margini.
                lockedBar
            } else {
                bar
                    .padding(.horizontal, 12)
                    .padding(.top, 6)
                    .padding(.bottom, 8)
            }
        }
        .animation(.snappy(duration: 0.22), value: isLocked)
        .animation(.snappy(duration: 0.22), value: hasTray)
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { addImage($0, name: String(localized: "Photo")) }
                .ignoresSafeArea()
        }
        .photosPicker(isPresented: $showPhotos, selection: $photoItems, maxSelectionCount: 10, matching: .images)
        .onChange(of: photoItems) { _, items in
            guard !items.isEmpty else { return }
            photoItems = []
            Task { await loadPhotos(items) }
        }
        .fileImporter(isPresented: $showFiles, allowedContentTypes: Self.fileTypes, allowsMultipleSelection: true) { result in
            if case .success(let urls) = result { addFiles(urls) }
        }
        // Capacità e vocabolario della dettatura: una volta per sessione e azienda (AriaBackend li tiene).
        .task(id: DictationKey(ready: backend.isReady, companyId: backend.activeCompanyId)) {
            guard backend.isReady else { dictationSupport = .none; return }
            let support = await backend.dictation()
            guard !Task.isCancelled else { return }
            dictationSupport = support
        }
        // Una pausa da decidere toglie la barra: una dettatura in corso si ferma (il testo sentito resta).
        .onChange(of: isLocked) { _, locked in
            if locked, dictation.isListening { dictation.stop() }
        }
        // L'anello sparisce (contatore non più disponibile, barra bloccata): il popover non deve riaprirsi da solo.
        .onChange(of: chat.contextUsage == nil || isLocked) { _, gone in
            if gone { showContext = false }
        }
        // Il contatore del contesto si aggiorna a ogni turno finito e quando si cambia conversazione.
        .task(id: ContextRefresh(sessionId: chat.sessionId, messages: chat.messages.count, streaming: chat.isStreaming)) {
            guard !chat.isStreaming else { return }
            await chat.loadContextUsage()
        }
        // Uscendo dalla chat il microfono si spegne.
        .onDisappear { dictation.cancel() }
        // La voce dal vivo usa lo stesso microfono: niente dettatura in parallelo.
        .onChange(of: voice?.isConnecting == true || voice?.isConnected == true) { _, live in
            if live { dictation.cancel() }
        }
    }

    // MARK: Barra

    private var bar: some View {
        VStack(alignment: .leading, spacing: 8) {
            if hasTray {
                tray
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            if dictation.isListening || dictation.isTranscribing {
                dictationStrip
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if let error = dictation.error {
                Label(error, systemImage: "mic.slash")
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 10)
                    .padding(.top, 6)
                    .transition(.opacity)
                    .accessibilityIdentifier("chat.dictation.error")
            }

            HStack(alignment: .bottom, spacing: 2) {
                plusMenu

                TextField(dictation.isListening ? "Listening…" : dictation.isTranscribing ? "Writing it down…" : "Ask Aria",
                          text: $draft, axis: .vertical)
                    .font(.system(size: 17))
                    // In orizzontale con la tastiera restano ~150 pt: oltre due righe il campo scorre al suo interno.
                    .lineLimit(verticalSizeClass == .compact ? 1...2 : 1...6)
                    .focused(inputFocused)
                    .padding(.vertical, 9)
                    .padding(.leading, 2)
                    .accessibilityIdentifier("chat.input")

                if let usage = chat.contextUsage, !dictation.isListening {
                    contextRing(usage)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                }

                micButton

                primaryButton
                    .padding(.leading, 2)
            }
        }
        .animation(.snappy(duration: 0.2), value: dictation.error)
        .animation(.snappy(duration: 0.22), value: dictation.isListening || dictation.isTranscribing)
        .animation(.snappy(duration: 0.22), value: chat.contextUsage == nil)
        .padding(6)
        // Liquid Glass (material prima di iOS 26): i messaggi scorrono sotto la barra.
        .ariaGlass(in: RoundedRectangle(cornerRadius: 26, style: .continuous), interactive: true)
    }

    // MARK: "+"

    private var plusMenu: some View {
        Menu {
            Section {
                Button("Camera", systemImage: "camera") { showCamera = true }
                    .disabled(!cameraAvailable)
                Button("Photos", systemImage: "photo.on.rectangle") { showPhotos = true }
                Button("Files", systemImage: "paperclip") { showFiles = true }
            }
            Section {
                Picker(selection: Binding(get: { chat.style }, set: { chat.style = $0 })) {
                    ForEach(AriaChatStyle.allCases, id: \.self) { style in
                        Label(style.title, systemImage: style.icon).tag(style)
                    }
                } label: {
                    Label("Response style", systemImage: chat.style.icon)
                }
                .pickerStyle(.menu)
                Toggle(isOn: Binding(get: { chat.webSearch }, set: { chat.webSearch = $0 })) {
                    Label("Web search", systemImage: "globe")
                }
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(.primary)
                .frame(width: 38, height: 38)
                .contentShape(Circle())
        }
        .accessibilityLabel("Add")
    }

    // MARK: Microfono (dettatura)

    /// Tocco = detta nel campo; tocco lungo = lingua di dettatura e chi trascrive (la lingua si sceglie anche
    /// dal menu "···" della chat).
    private var micButton: some View {
        Menu {
            Section {
                Picker(selection: $dictationLanguage) {
                    Text("Automatic").tag(AriaDictation.automatic)
                    ForEach(AriaDictation.languages) { language in
                        Text(verbatim: language.label).tag(language.code)
                    }
                } label: {
                    Label("Dictation language", systemImage: "globe")
                    Text(dictationLanguageName)
                }
                .pickerStyle(.menu)
                // La lingua vale per tutta la dettatura: si cambia da fermi.
                .disabled(dictation.isListening || dictation.isTranscribing)
            } header: {
                Text(dictationSourceTitle)
            }
        } label: {
            AriaMicGlyph(dictation: dictation)
        } primaryAction: {
            toggleDictation()
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .disabled(dictation.isTranscribing || dictation.isStarting || voice?.isConnected == true || voice?.isConnecting == true)
        .accessibilityLabel(dictation.isListening ? "Stop dictation" : dictation.isTranscribing ? "Writing it down…" : "Dictate")
        .accessibilityValue(Text(dictationLanguageName))
        .accessibilityHint("Touch and hold to choose the dictation language.")
        .accessibilityIdentifier("chat.mic")
    }

    private var dictationLanguageName: String {
        AriaDictation.languages.first { $0.code == dictationLanguage }?.label ?? String(localized: "Automatic")
    }

    /// Chi scrive il testo: il server, il telefono ripulito dal server, o solo il telefono.
    private var dictationSourceTitle: String {
        if dictationSupport.transcribes { return String(localized: "Aria transcribes when you stop") }
        if dictationSupport.polishes { return String(localized: "Written on this phone, tidied up by Aria") }
        return String(localized: "Written on this phone")
    }

    /// In ascolto: da quanto si parla e quanto resta, chi trascrive e "Scarta". Poi l'attesa del testo finale.
    private var dictationStrip: some View {
        HStack(spacing: 8) {
            if dictation.isListening, let startedAt = dictation.startedAt {
                Image(systemName: "circle.fill")
                    .font(.system(size: 7))
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
                .font(.system(size: 12, weight: .semibold))
                Text(dictationSourceTitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .accessibilityIdentifier("chat.dictation.source")
                Spacer(minLength: 4)
                stripButton(systemImage: "xmark", label: "Discard dictation", identifier: "chat.dictation.discard", action: discardDictation)
            } else {
                ProgressView().controlSize(.mini)
                Text("Writing it down…")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 4)
                // Il server è lento o non risponde: si tiene il testo già scritto e non si aspetta più.
                stripButton(systemImage: "checkmark", label: "Keep the text as it is", identifier: "chat.dictation.keep") { dictation.cancel() }
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
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: 26, height: 26)
                .background(Color(.tertiarySystemFill), in: Circle())
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }

    /// Ferma la dettatura e rimette il campo com'era prima.
    private func discardDictation() {
        dictation.cancel()
        if let before = draftBeforeDictation { draft = before }
        draftBeforeDictation = nil
    }

    // MARK: Contesto

    /// Quanto della memoria di Aria usa la conversazione: un anello che si riempie. Tocco = dettagli e "Fai spazio".
    private func contextRing(_ usage: AriaContextUsage) -> some View {
        let fraction = min(max(usage.percentUsed / 100, 0), 1)
        let tint = contextTint(usage)
        return Button { showContext = true } label: {
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
        .popover(isPresented: $showContext, arrowEdge: .bottom) {
            AriaContextPopover(usage: usage, tint: tint, isCompacting: chat.isCompacting) {
                Task { await chat.compactContext() }
            }
            .presentationCompactAdaptation(.popover)
        }
    }

    /// Grigio finché c'è spazio (un anello colorato sembrerebbe un caricamento); arancione oltre la soglia
    /// della compattazione automatica, rosso quasi pieno.
    private func contextTint(_ usage: AriaContextUsage) -> Color {
        if usage.percentUsed >= 95 { return .red }
        if usage.percentUsed >= (usage.autoCompactAt ?? 80) { return .orange }
        return .secondary
    }

    private func toggleDictation() {
        // Il testo dettato si aggiunge a quello già scritto, non lo sostituisce.
        let prefix = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        // Trascrizione sul backend (come la web) se il server la offre; altrimenti il riconoscimento sul telefono,
        // ripulito con `polish` quando c'è.
        let server = dictationServer()
        // Punto di partenza per capire se l'operatore tocca il campo mentre si trascrive.
        if !dictation.isListening {
            dictatedDraft = draft
            draftBeforeDictation = draft
        }
        Task {
            await dictation.toggle(context: prefix, server: server) { transcript, final in
                // Il testo di Whisper arriva dopo lo stop: se intanto il campo è stato modificato, vince l'operatore.
                if final, draft != dictatedDraft { return }
                draft = prefix.isEmpty ? transcript : prefix + " " + transcript
                dictatedDraft = draft
                // Testo finale arrivato: "Scarta" non si applica più a questa dettatura.
                if final { draftBeforeDictation = nil }
            }
        }
    }

    private func dictationServer() -> AriaDictation.Server {
        guard backend.isReady else { return AriaDictation.Server() }
        let api = backend.api
        let support = dictationSupport
        var server = AriaDictation.Server(vocabulary: support.vocabulary, maxAudioBytes: support.maxAudioBytes)
        if support.transcribes {
            server.transcriber = { @Sendable audio, language, prompt in
                let data = try await AriaAudioFile.read(audio)
                return try await api.transcribe(audio: data, filename: "dictation.m4a", mimeType: "audio/mp4",
                                                language: language, prompt: prompt)
            }
        }
        if support.polishes {
            let audio = AriaAudioAPI(api: api)
            server.polisher = { @Sendable text, language in try await audio.polish(text, language: language) }
        }
        return server
    }

    // MARK: Contesto e strumenti attivi

    private var tray: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .bottom, spacing: 8) {
                if chat.webSearch {
                    toolPill(String(localized: "Web search"), icon: "globe") { chat.webSearch = false }
                }
                if chat.style != .auto {
                    toolPill(chat.style.shortTitle, icon: chat.style.icon) { chat.style = .auto }
                }
                ForEach(chat.contextItems) { item in
                    contextTile(item)
                }
            }
            .padding(.horizontal, 6)
            .padding(.top, 6)
        }
        .scrollIndicators(.hidden)
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

    @ViewBuilder
    private func contextTile(_ item: AriaContextItem) -> some View {
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
            Button {
                withAnimation(.snappy) { chat.contextItems.removeAll { $0.id == item.id } }
            } label: {
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

    // MARK: Aggiunta

    private func addImage(_ image: UIImage, name: String) {
        let thumbnail = image.preparingThumbnail(of: CGSize(width: 168, height: 168)) ?? image
        let item = AriaContextItem(kind: .image, name: name, thumbnail: thumbnail.jpegData(compressionQuality: 0.8))
        withAnimation(.snappy) { chat.contextItems.append(item) }
    }

    private func loadPhotos(_ items: [PhotosPickerItem]) async {
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else { continue }
            addImage(image, name: String(localized: "Photo"))
        }
    }

    private func addFiles(_ urls: [URL]) {
        for url in urls {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let isImage = UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) == true
            if isImage, let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                addImage(image, name: url.lastPathComponent)
            } else {
                let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize
                let item = AriaContextItem(kind: .document, name: url.lastPathComponent, size: size)
                withAnimation(.snappy) { chat.contextItems.append(item) }
            }
        }
    }

    // MARK: Pulsante principale

    private var showsStop: Bool { !hasText && (chat.isStreaming || voice?.isConnected == true) }

    private var primaryButton: some View {
        Button(action: primaryAction) {
            ZStack {
                Circle()
                    .fill(buttonTint)
                    .frame(width: 38, height: 38)
                if let voice, voice.isConnecting, !hasText, !chat.isStreaming {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: symbol)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .contentTransition(.symbolEffect(.replace))
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(hasText ? (chat.isStreaming || !hasPlant) : (!chat.isStreaming && voice == nil))
        .opacity(hasText && (chat.isStreaming || !hasPlant) ? 0.4 : 1)
        .accessibilityLabel(showsStop ? "Stop" : (hasText || voice == nil ? "Send" : "Voice"))
        .accessibilityIdentifier(showsStop ? "chat.stop" : (hasText || voice == nil ? "chat.send" : "chat.voice"))
        // L'invio lo segnala la chat (AriaChatHaptics); qui solo stop e voce.
        .sensoryFeedback(.impact(weight: .medium), trigger: tapCount)
        .sensoryFeedback(.impact(weight: .light), trigger: chat.contextItems.count) { old, new in new > old }
    }

    private var buttonTint: Color {
        if showsStop { return .red }
        if !hasText && voice == nil { return Color.secondary.opacity(0.35) }
        return .accentColor
    }

    private var symbol: String {
        if hasText { return "arrow.up" }
        if showsStop { return "stop.fill" }
        return voice == nil ? "arrow.up" : "waveform"
    }

    private func primaryAction() {
        if hasText {
            send()
        } else if chat.isStreaming {
            chat.stop()
            tapCount += 1
        } else {
            dictation.cancel()
            voice?.toggleConnection()
            tapCount += 1
        }
    }

    private func send() {
        // Il messaggio parte così com'è: il resto della dettatura non deve riempire di nuovo il campo.
        dictation.cancel()
        draftBeforeDictation = nil
        chat.send(draft)
        draft = ""
        inputFocused.wrappedValue = false
    }

    // MARK: In attesa di una decisione

    /// Con una pausa aperta il backend non accetta nuovi turni: si dice perché e dove decidere.
    /// Vetro come gli altri pannelli in basso (il contenuto resta nell'area sicura, mai sotto l'indicatore home);
    /// i messaggi ci scorrono sotto ma la lista lascia lo spazio del pannello, quindi niente si sovrappone.
    private var lockedBar: some View {
        let isLoto = chat.pendingInterrupt?.kind == .loto
        return HStack(spacing: 12) {
            Image(systemName: isLoto ? "lock.shield.fill" : "hand.raised.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.orange)
                .frame(width: 34, height: 34)
                .background(Color.orange.opacity(0.16), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text("Aria is waiting for your decision")
                    .font(.system(size: 14, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Text("Approve or reject the action to continue.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onShowPending) {
                Text("Review")
                    .font(.system(size: 14, weight: .semibold))
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

// MARK: - Stile di risposta

extension AriaChatStyle {
    var title: String {
        switch self {
        case .auto: String(localized: "Auto")
        case .detailed: String(localized: "Detailed")
        case .compact: String(localized: "Compact (operator)")
        }
    }

    var shortTitle: String {
        switch self {
        case .auto: String(localized: "Auto")
        case .detailed: String(localized: "Detailed")
        case .compact: String(localized: "Compact")
        }
    }

    var icon: String {
        switch self {
        case .auto: "wand.and.sparkles"
        case .detailed: "text.alignleft"
        case .compact: "text.line.first.and.arrowtriangle.forward"
        }
    }
}

/// Quando richiedere capacità e vocabolario della dettatura: accesso e azienda.
private struct DictationKey: Equatable {
    let ready: Bool
    let companyId: String?
}

/// Il microfono della barra. Sta in una vista sua: il volume cambia decine di volte al secondo e ridisegna
/// solo questo cerchio, non tutta la barra.
private struct AriaMicGlyph: View {
    let dictation: AriaDictation

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
                    .font(.system(size: dictation.isListening ? 15 : 18, weight: .regular))
                    .foregroundStyle(dictation.isListening ? Color.accentColor : .primary)
                    .contentTransition(.symbolEffect(.replace))
            }
        }
        .frame(width: 38, height: 38)
        .contentShape(Circle())
    }
}

/// La registrazione si legge fuori dal main thread prima dell'invio.
private nonisolated enum AriaAudioFile {
    @concurrent
    static func read(_ url: URL) async throws -> Data { try Data(contentsOf: url) }
}

/// Quando richiedere il contatore del contesto: cambio di conversazione o turno finito.
private struct ContextRefresh: Equatable {
    let sessionId: String
    let messages: Int
    let streaming: Bool
}

/// I dettagli dell'anello: percentuale, dove è finito lo spazio e "Fai spazio" quando il server lo permette.
/// Compattare riassume i messaggi più vecchi per Aria; la conversazione salvata resta intera.
private struct AriaContextPopover: View {
    let usage: AriaContextUsage
    let tint: Color
    let isCompacting: Bool
    let compact: () -> Void

    private var fraction: Double { min(max(usage.percentUsed / 100, 0), 1) }

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
            if let overhead = usage.overheadTokens, usage.usedTokens > 0, Double(overhead) / Double(usage.usedTokens) >= 0.5 {
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
