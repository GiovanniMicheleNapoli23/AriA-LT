//
//  AriaChatComposerViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La logica del composer: bozza, invio, stop e voce dal pulsante principale, dettatura (chi
//  trascrive, testo che si aggiunge, "Scarta"), contesto aggiunto dal "+" e contatore della memoria.
//

import ImageIO
import Observation
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

@MainActor
@Observable
final class AriaChatComposerViewModel {
    let chat: AriaAgentChat
    let backend: AriaBackend
    let voice: AriaVoiceViewModel?
    let dictation = AriaDictation()
    /// I livelli di effort del menu sotto il campo (righe, stime, scelta): gli stessi del foglio "Effort".
    let effortPicker: AriaEffortPickerViewModel

    /// Cosa fa il pulsante tondo a destra del campo.
    enum PrimaryRole: Equatable {
        /// C'è testo: lo manda.
        case send
        /// Campo vuoto, nessuna voce dal vivo: spento.
        case idle
        /// Campo vuoto: apre la voce dal vivo.
        case voice
        /// Campo vuoto durante una risposta o la voce dal vivo: la ferma.
        case stop
    }

    /// Quanto è piena la memoria della conversazione.
    enum ContextLevel: Equatable {
        case normal
        /// Oltre la soglia della compattazione automatica.
        case high
        /// Quasi pieno.
        case full
    }

    // MARK: - State

    var draft = ""
    var showCamera = false
    var showPhotos = false
    var showFiles = false
    var showContext = false
    /// Il foglio "Effort" con i costi e "Try again" (la logica sta in AriaChatComposerViewModel+Effort).
    var showEffort = false
    /// Il popover dei connettori: finché è aperto la riga sotto il campo resta, anche se il campo perde il focus.
    var showConnectors = false
    /// Il campo ha la tastiera: sotto compaiono l'effort e l'icona dei connettori. Lo aggiorna la vista dal suo FocusState.
    var isInputFocused = false
    var photoItems: [PhotosPickerItem] = []
    /// Cresce a ogni stop o voce: l'haptic del pulsante. L'invio lo segnala la chat (AriaChatHaptics).
    private(set) var tapCount = 0
    /// Cosa fa la dettatura su questo server (chiesto una volta, all'apertura del composer).
    private(set) var dictationSupport = AriaDictationSupport.none
    /// L'ultimo testo scritto dalla dettatura: se nel frattempo l'operatore l'ha cambiato, Whisper non lo sovrascrive.
    private var dictatedDraft: String?
    /// Il campo prima della dettatura: "Scarta" lo rimette com'era.
    private var draftBeforeDictation: String?

    init(chat: AriaAgentChat, backend: AriaBackend, voice: AriaVoiceViewModel?) {
        self.chat = chat
        self.backend = backend
        self.voice = voice
        self.effortPicker = AriaEffortPickerViewModel(chat: chat, backend: backend)
    }

    /// Gli stessi formati del context dock della web (CONTEXT_FILE_ACCEPT).
    static let fileTypes: [UTType] = [
        .image, .pdf, .plainText, .commaSeparatedText,
        UTType(filenameExtension: "md"), UTType(filenameExtension: "doc"), UTType(filenameExtension: "docx"),
        UTType(filenameExtension: "xls"), UTType(filenameExtension: "xlsx"),
    ].compactMap { $0 }

    // MARK: - Derived

    var hasText: Bool { !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    /// Con una pausa aperta il backend non accetta nuovi turni: la barra lascia il posto all'avviso.
    var isLocked: Bool { chat.pendingInterrupt != nil }
    var isLotoPending: Bool { chat.pendingInterrupt?.kind == .loto }
    var hasTray: Bool { !chat.contextItems.isEmpty || chat.webSearch || chat.style != .auto || effortPillTitle != nil }
    var cameraAvailable: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }
    var contextItems: [AriaContextItem] { chat.contextItems }
    var contextUsage: AriaContextUsage? { chat.contextUsage }
    var isCompacting: Bool { chat.isCompacting }
    var isDictating: Bool { dictation.isListening || dictation.isTranscribing }

    var style: AriaChatStyle {
        get { chat.style }
        set { chat.style = newValue }
    }

    var webSearch: Bool {
        get { chat.webSearch }
        set { chat.webSearch = newValue }
    }

    var isVoiceLive: Bool { voice?.isConnecting == true || voice?.isConnected == true }

    var primaryRole: PrimaryRole {
        if hasText { return .send }
        if chat.isStreaming || voice?.isConnected == true { return .stop }
        return voice == nil ? .idle : .voice
    }

    /// La voce dal vivo si sta collegando: il pulsante mostra l'attesa.
    var isVoiceConnecting: Bool {
        guard let voice else { return false }
        return voice.isConnecting && !hasText && !chat.isStreaming
    }

    /// Con testo non si manda durante una risposta o senza stabilimento; vuoto serve una risposta da fermare o la voce.
    var isPrimaryDisabled: Bool {
        hasText ? (chat.isStreaming || backend.activePlantId == nil) : (!chat.isStreaming && voice == nil)
    }

    var isPrimaryDimmed: Bool {
        hasText && (chat.isStreaming || backend.activePlantId == nil)
    }

    var placeholder: String {
        if dictation.isListening { return String(localized: "Listening…") }
        if dictation.isTranscribing { return String(localized: "Writing it down…") }
        return String(localized: "Ask Aria")
    }

    /// La voce dal vivo usa lo stesso microfono: niente dettatura mentre è accesa o si avvia.
    var isMicDisabled: Bool {
        dictation.isTranscribing || dictation.isStarting || isVoiceLive
    }

    var micAccessibilityLabel: String {
        if dictation.isListening { return String(localized: "Stop dictation") }
        if dictation.isTranscribing { return String(localized: "Writing it down…") }
        return String(localized: "Dictate")
    }

    /// Chi scrive il testo: il server, il telefono ripulito dal server, o solo il telefono.
    var dictationSourceTitle: String {
        if dictationSupport.transcribes { return String(localized: "Aria transcribes when you stop") }
        if dictationSupport.polishes { return String(localized: "Written on this phone, tidied up by Aria") }
        return String(localized: "Written on this phone")
    }

    func dictationLanguageName(_ code: String) -> String {
        AriaDictation.languages.first { $0.code == code }?.label ?? String(localized: "Automatic")
    }

    func contextFraction(_ usage: AriaContextUsage) -> Double {
        min(max(usage.percentUsed / 100, 0), 1)
    }

    /// Grigio finché c'è spazio (un anello colorato sembrerebbe un caricamento); arancione oltre la soglia
    /// della compattazione automatica, rosso quasi pieno.
    func contextLevel(_ usage: AriaContextUsage) -> ContextLevel {
        if usage.percentUsed >= 95 { return .full }
        if usage.percentUsed >= (usage.autoCompactAt ?? 80) { return .high }
        return .normal
    }

    /// Quando richiedere capacità e vocabolario della dettatura: accesso e azienda.
    var dictationKey: DictationKey {
        DictationKey(ready: backend.isReady, companyId: backend.activeCompanyId)
    }

    /// Quando richiedere il contatore del contesto: cambio di conversazione o turno finito.
    /// Legge solo `messageCount` (non `messages`): il composer non si ridisegna a ogni pezzo in streaming.
    var contextRefreshKey: ContextRefresh {
        ContextRefresh(sessionId: chat.sessionId, messages: chat.messageCount, streaming: chat.isStreaming,
                       loading: chat.isLoadingHistory)
    }

    /// L'anello sparisce (contatore non più disponibile, barra bloccata).
    var isContextRingGone: Bool { chat.contextUsage == nil || isLocked }

    struct DictationKey: Equatable {
        let ready: Bool
        let companyId: String?
    }

    struct ContextRefresh: Equatable {
        let sessionId: String
        let messages: Int
        let streaming: Bool
        /// Storico in caricamento (ripristino): il contatore si chiede a caricamento finito, non a ogni passo.
        let loading: Bool
    }

    // MARK: - Pulsante principale

    /// Manda, ferma la risposta o accende la voce. `true` se è partito un messaggio.
    @discardableResult
    func primaryAction() -> Bool {
        if hasText {
            send()
            return true
        }
        if chat.isStreaming {
            chat.stop()
        } else {
            dictation.cancel()
            voice?.toggleConnection()
        }
        tapCount += 1
        return false
    }

    private func send() {
        // Il messaggio parte così com'è: il resto della dettatura non deve riempire di nuovo il campo.
        dictation.cancel()
        draftBeforeDictation = nil
        chat.send(draft)
        draft = ""
    }

    // MARK: - Dettatura

    func toggleDictation() {
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
        Task { [weak self] in
            guard let self else { return }
            await dictation.toggle(context: prefix, server: server) { [weak self] transcript, final in
                guard let self else { return }
                // Il testo di Whisper arriva dopo lo stop: se intanto il campo è stato modificato, vince l'operatore.
                if final, draft != dictatedDraft { return }
                draft = prefix.isEmpty ? transcript : prefix + " " + transcript
                dictatedDraft = draft
                // Testo finale arrivato: "Scarta" non si applica più a questa dettatura.
                if final { draftBeforeDictation = nil }
            }
        }
    }

    /// Ferma la dettatura e rimette il campo com'era prima.
    func discardDictation() {
        dictation.cancel()
        if let before = draftBeforeDictation { draft = before }
        draftBeforeDictation = nil
    }

    /// Il server è lento o non risponde: si tiene il testo già scritto e non si aspetta più.
    func keepDictatedText() {
        dictation.cancel()
    }

    /// Capacità e vocabolario della dettatura: una volta per sessione e azienda (AriaBackend li tiene).
    func loadDictationSupport() async {
        guard backend.isReady else { dictationSupport = .none; return }
        let support = await backend.dictation()
        guard !Task.isCancelled else { return }
        dictationSupport = support
    }

    /// Una pausa da decidere toglie la barra: una dettatura in corso si ferma (il testo sentito resta).
    func lockChanged(_ locked: Bool) {
        if locked, dictation.isListening { dictation.stop() }
    }

    /// La voce dal vivo usa lo stesso microfono: niente dettatura in parallelo.
    func voiceLiveChanged(_ live: Bool) {
        if live { dictation.cancel() }
    }

    /// Uscendo dalla chat il microfono si spegne.
    func disappear() {
        dictation.cancel()
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

    // MARK: - Contesto

    /// Il contatore del contesto si aggiorna a ogni turno finito e quando si cambia conversazione.
    func refreshContextUsage() async {
        guard !chat.isStreaming, !chat.isLoadingHistory else { return }
        await chat.loadContextUsage()
    }

    /// L'anello è sparito: il popover non deve riaprirsi da solo.
    func contextRingGoneChanged(_ gone: Bool) {
        if gone { showContext = false }
    }

    func compactContext() {
        Task { await chat.compactContext() }
    }

    func removeContextItem(_ id: AriaContextItem.ID) {
        chat.contextItems.removeAll { $0.id == id }
    }

    func clearStyle() {
        chat.style = .auto
    }

    func clearWebSearch() {
        chat.webSearch = false
    }

    // MARK: - Aggiunta

    /// La miniatura si prepara fuori dal main thread (foto da 12 MP): l'elemento compare a lavoro finito.
    func addImage(_ image: UIImage, name: String) async {
        let thumbnail = await AriaImageThumbnail.jpeg(from: image)
        chat.contextItems.append(AriaContextItem(kind: .image, name: name, thumbnail: thumbnail))
    }

    func addCameraPhoto(_ image: UIImage) {
        let name = String(localized: "Photo")
        Task { await addImage(image, name: name) }
    }

    /// Le foto scelte dalla galleria: la selezione si svuota subito, così la stessa foto si può riscegliere.
    func photosPicked(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        photoItems = []
        Task { await loadPhotos(items) }
    }

    private func loadPhotos(_ items: [PhotosPickerItem]) async {
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let thumbnail = await AriaImageThumbnail.jpeg(from: data) else { continue }
            chat.contextItems.append(AriaContextItem(kind: .image, name: String(localized: "Photo"), thumbnail: thumbnail))
        }
    }

    func filesPicked(_ result: Result<[URL], any Error>) {
        guard case .success(let urls) = result else { return }
        Task { await loadFiles(urls) }
    }

    /// Un file alla volta, nell'ordine scelto; lettura e miniatura fuori dal main thread.
    private func loadFiles(_ urls: [URL]) async {
        for url in urls {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let isImage = UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) == true
            if isImage, let thumbnail = await AriaImageThumbnail.jpeg(from: url) {
                chat.contextItems.append(AriaContextItem(kind: .image, name: url.lastPathComponent, thumbnail: thumbnail))
            } else {
                let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize
                chat.contextItems.append(AriaContextItem(kind: .document, name: url.lastPathComponent, size: size))
            }
        }
    }
}

/// Le miniature delle immagini aggiunte al contesto, calcolate fuori dal main thread.
private nonisolated enum AriaImageThumbnail {
    /// Lato massimo, in pixel, dell'anteprima (come prima: 168 × 168).
    static let maxPixelSize = 168
    static let quality: CGFloat = 0.8

    /// Da un'immagine già decodificata (foto della fotocamera).
    @concurrent
    static func jpeg(from image: UIImage) async -> Data? {
        let thumbnail = image.preparingThumbnail(of: CGSize(width: maxPixelSize, height: maxPixelSize)) ?? image
        return thumbnail.jpegData(compressionQuality: quality)
    }

    /// Dai byte di una foto della galleria: la miniatura si decodifica direttamente a 168 px, senza l'immagine intera.
    @concurrent
    static func jpeg(from data: Data) async -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return encode(source)
    }

    /// Da un file: si legge solo quanto serve a decodificare la miniatura.
    @concurrent
    static func jpeg(from url: URL) async -> Data? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return encode(source)
    }

    private static func encode(_ source: CGImageSource) -> Data? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: cgImage).jpegData(compressionQuality: quality)
    }
}

/// La registrazione si legge fuori dal main thread prima dell'invio.
private nonisolated enum AriaAudioFile {
    @concurrent
    static func read(_ url: URL) async throws -> Data { try Data(contentsOf: url) }
}
