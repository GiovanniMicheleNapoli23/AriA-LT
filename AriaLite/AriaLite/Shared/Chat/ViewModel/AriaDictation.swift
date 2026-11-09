//
//  AriaDictation.swift
//  AriaLite
//
//  Created by Giovanni Michele on 26/09/26.
//
//  Dettatura nel campo della chat (il microfono del composer), ibrida come sulla web (use-dictation):
//  mentre si parla SFSpeechRecognizer scrive le parole dal vivo (aiutato dai codici e termini dell'azienda,
//  GET /v1/audio/vocabulary) e intanto la stessa voce si registra; allo stop la registrazione va al backend
//  (POST v1/audio/transcriptions) e il suo testo, più preciso sui termini di reparto, prende il posto di
//  quello dal vivo. Se il server non trascrive (servizio spento, firewall, rete) il testo dal vivo passa da
//  POST v1/audio/polish (punteggiatura, maiuscole); se anche quello manca resta com'è. Senza riconoscitore
//  sul telefono scrive solo il server.
//  Non è la voce dal vivo di Aria (AriaVoiceViewModel): qui si scrive soltanto, e si manda quando si vuole.
//
//  La lingua è quella della web (lib/chat/dictation-language): NON la lingua
//  dell'interfaccia, perché un reparto può parlare una lingua diversa da quella
//  dell'app. "Automatico" = la lingua del telefono se è in elenco, altrimenti
//  inglese: SFSpeechRecognizer, come il riconoscitore del browser, non la rileva da solo.
//

import AVFoundation
import Foundation
import Observation
import Speech

@MainActor
@Observable
final class AriaDictation {
    struct Language: Identifiable, Hashable {
        /// ISO 639-1, come sulla web.
        let code: String
        /// BCP-47, quello che vuole SFSpeechRecognizer.
        let speechTag: String
        /// Nome nella lingua stessa: un norvegese cerca "Norsk", non "Norvegese".
        let label: String
        var id: String { code }
    }

    static let automatic = "auto"

    /// Stesso elenco e stesso ordine della web: prima le lingue più probabili in reparto.
    static let languages: [Language] = [
        Language(code: "it", speechTag: "it-IT", label: "Italiano"),
        Language(code: "en", speechTag: "en-GB", label: "English"),
        Language(code: "de", speechTag: "de-DE", label: "Deutsch"),
        Language(code: "fr", speechTag: "fr-FR", label: "Français"),
        Language(code: "es", speechTag: "es-ES", label: "Español"),
        Language(code: "pt", speechTag: "pt-PT", label: "Português"),
        Language(code: "nl", speechTag: "nl-NL", label: "Nederlands"),
        Language(code: "pl", speechTag: "pl-PL", label: "Polski"),
        Language(code: "no", speechTag: "nb-NO", label: "Norsk"),
        Language(code: "sv", speechTag: "sv-SE", label: "Svenska"),
        Language(code: "da", speechTag: "da-DK", label: "Dansk"),
        Language(code: "fi", speechTag: "fi-FI", label: "Suomi"),
        Language(code: "cs", speechTag: "cs-CZ", label: "Čeština"),
        Language(code: "sk", speechTag: "sk-SK", label: "Slovenčina"),
        Language(code: "sl", speechTag: "sl-SI", label: "Slovenščina"),
        Language(code: "hu", speechTag: "hu-HU", label: "Magyar"),
        Language(code: "ro", speechTag: "ro-RO", label: "Română"),
        Language(code: "hr", speechTag: "hr-HR", label: "Hrvatski"),
        Language(code: "el", speechTag: "el-GR", label: "Ελληνικά"),
        Language(code: "tr", speechTag: "tr-TR", label: "Türkçe"),
        Language(code: "uk", speechTag: "uk-UA", label: "Українська"),
        Language(code: "ru", speechTag: "ru-RU", label: "Русский"),
    ]

    /// Trascrizione con Whisper: riceve il file registrato, la lingua (`nil` = automatica) e il testo già
    /// scritto come contesto; `nil` se il servizio non c'è.
    typealias Transcriber = @Sendable (_ audio: URL, _ language: String?, _ prompt: String?) async throws -> String?
    /// Da testo dettato a testo scritto (POST v1/audio/polish), per il testo del riconoscitore sul telefono.
    typealias Polisher = @Sendable (_ text: String, _ language: String?) async throws -> String

    /// Cosa offre il server per una dettatura.
    struct Server {
        var transcriber: Transcriber?
        var polisher: Polisher?
        /// Codici allarme, tag e termini dell'azienda: aiuti per il riconoscitore sul telefono.
        var vocabulary: [String] = []
        /// La registrazione più grande che il server accetta (`maxAudioMb`).
        var maxAudioBytes: Int?
    }

    private(set) var isListening = false
    /// Permessi e sessione audio in preparazione: un secondo tocco non avvia una seconda registrazione.
    private(set) var isStarting = false
    /// Registrazione finita, in attesa del testo di Whisper.
    private(set) var isTranscribing = false
    /// Volume del microfono, 0…1, per l'anello attorno al pulsante.
    private(set) var level: Float = 0
    /// Quando è partito l'ascolto (nil da fermi): la barra mostra da quanto si parla.
    private(set) var startedAt: Date?
    /// Dopo quanto l'ascolto si ferma da solo (2 minuti, o meno col limite del server).
    private(set) var recordingLimit: Duration = .seconds(120)
    var error: String?

    @ObservationIgnored private let engine = AVAudioEngine()
    /// La richiesta del riconoscitore che riceve l'audio: il tap la legge da qui, così si può sostituire
    /// quando il riconoscitore si ferma da solo (dopo circa un minuto) mentre si registra ancora.
    @ObservationIgnored private let sink = AriaRecognitionSink()
    @ObservationIgnored private var recognizer: SFSpeechRecognizer?
    @ObservationIgnored private var hints: [String] = []
    @ObservationIgnored private var task: SFSpeechRecognitionTask?
    /// Cresce a ogni richiesta nuova: i risultati di una richiesta vecchia si ignorano.
    @ObservationIgnored private var generation = 0
    /// Il testo delle richieste già chiuse in questa dettatura; quella in corso si aggiunge in fondo.
    @ObservationIgnored private var committedLive = ""
    /// La lingua scelta all'avvio (nil = automatica): riconoscitore, server e pulizia usano la stessa.
    @ObservationIgnored private var sessionLanguage: String?
    /// Riceve la trascrizione: dal vivo (`final` falso) e poi, se c'è, quella di Whisper (`final` vero).
    @ObservationIgnored private var onText: ((_ text: String, _ final: Bool) -> Void)?
    @ObservationIgnored private var capture: AriaAudioCapture?
    @ObservationIgnored private var transcriber: Transcriber?
    @ObservationIgnored private var polisher: Polisher?
    @ObservationIgnored private var maxAudioBytes: Int?
    @ObservationIgnored private var prompt: String?
    @ObservationIgnored private var heardLive = false
    /// L'ultimo testo dal vivo: si ripulisce con `polisher` se il server non trascrive.
    @ObservationIgnored private var liveText = ""
    @ObservationIgnored private var upload: Task<Void, Never>?
    @ObservationIgnored private var limit: Task<Void, Never>?

    /// Come la web: oltre i 2 minuti si ferma da sola, sotto i 350 ms non si manda niente.
    private static let maxDuration: Duration = .seconds(120)
    private static let minDuration: TimeInterval = 0.35
    /// Apple consiglia al massimo un centinaio di `contextualStrings`.
    private static let maxHints = 100
    /// Byte al secondo di un AAC di qualità media, per eccesso: serve a fermarsi prima di `maxAudioMb`.
    private static let audioBytesPerSecond = 24_000

    /// Quanto si può registrare: 2 minuti, o meno se il server accetta file più piccoli.
    static func recordingLimit(maxAudioBytes: Int?) -> Duration {
        guard let maxAudioBytes, maxAudioBytes > 0 else { return maxDuration }
        let seconds = Double(maxAudioBytes) * 0.9 / Double(audioBytesPerSecond)
        return min(maxDuration, .milliseconds(Int(seconds * 1000)))
    }

    /// Codice scelto (`automatic` o uno di `languages`), ricordato sul telefono. Si sceglie dal menu
    /// della chat (AriaChatOptionsSheet, con `@AppStorage` sulla stessa chiave) e si legge a ogni dettatura.
    static let languageKey = "aria.dictation.language"

    static var language: String {
        let stored = UserDefaults.standard.string(forKey: languageKey) ?? automatic
        return stored == automatic || languages.contains { $0.code == stored } ? stored : automatic
    }

    /// Il tag da dare al riconoscitore: mai "auto", non sa rilevare la lingua.
    private static func speechTag(for language: String?) -> String {
        let code = language ?? (Locale.current.language.languageCode?.identifier ?? "en")
        return languages.first { $0.code == code }?.speechTag ?? "en-GB"
    }

    // MARK: - Avvio / stop

    func toggle(context: String?, server: Server,
                onText: @escaping (_ text: String, _ final: Bool) -> Void) async {
        if isListening { stop() } else { await start(context: context, server: server, onText: onText) }
    }

    func start(context: String?, server: Server,
               onText: @escaping (_ text: String, _ final: Bool) -> Void) async {
        guard !isListening, !isTranscribing, !isStarting else { return }
        isStarting = true
        defer { isStarting = false }
        let transcriber = server.transcriber
        let language = Self.language == Self.automatic ? nil : Self.language
        error = nil
        task?.cancel()
        task = nil

        guard await AVAudioApplication.requestRecordPermission() else {
            error = String(localized: "Allow the microphone for AriaLite in Settings to dictate.")
            return
        }
        // Il riconoscitore sul telefono dà le parole dal vivo; se manca basta Whisper.
        let recognizer = await Self.speechAuthorization() == .authorized
            ? SFSpeechRecognizer(locale: Locale(identifier: Self.speechTag(for: language))).flatMap { $0.isAvailable ? $0 : nil }
            : nil
        guard recognizer != nil || transcriber != nil else {
            error = SFSpeechRecognizer.authorizationStatus() == .authorized
                ? String(localized: "Dictation isn't available for this language right now.")
                : String(localized: "Allow Speech Recognition for AriaLite in Settings to dictate.")
            return
        }

        do {
            try await Self.activateAudioSession()
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)

            let hints = Array(server.vocabulary.prefix(Self.maxHints))
            let request = recognizer.map { _ in Self.makeRequest(hints: hints) }
            sink.request = request
            let capture = transcriber == nil ? nil : try? AriaAudioCapture(format: format)

            input.removeTap(onBus: 0)
            input.installTap(onBus: 0, bufferSize: 1024, format: format,
                             block: Self.tapBlock(sink: sink, capture: capture, owner: self))
            engine.prepare()
            try engine.start()

            self.recognizer = recognizer
            self.hints = hints
            self.sessionLanguage = language
            self.capture = capture
            self.transcriber = capture == nil ? nil : transcriber
            self.polisher = server.polisher
            self.maxAudioBytes = server.maxAudioBytes
            self.prompt = context.map { String($0.suffix(300)) }
            self.onText = onText
            heardLive = false
            liveText = ""
            committedLive = ""
            generation += 1
            if let recognizer, let request {
                task = recognizer.recognitionTask(with: request,
                                                  resultHandler: Self.resultHandler(owner: self, generation: generation))
            }
            isListening = true
            let recordingLimit = Self.recordingLimit(maxAudioBytes: server.maxAudioBytes)
            self.recordingLimit = recordingLimit
            startedAt = .now
            limit = Task { [weak self] in
                try? await Task.sleep(for: recordingLimit)
                guard !Task.isCancelled else { return }
                self?.stop()
            }
        } catch {
            self.error = error.localizedDescription
            capture?.discard()
            capture = nil
            tearDownAudio()
        }
    }

    /// Ferma l'ascolto: l'ultimo pezzo dal vivo arriva ancora nel campo, poi (se c'è) il testo di Whisper.
    func stop() {
        guard isListening else { return }
        let capture = self.capture
        self.capture = nil
        tearDownAudio()
        task?.finish()
        let language = sessionLanguage
        let live = heardLive ? liveText : ""
        let polisher = self.polisher
        guard let capture, let transcriber else {
            if !heardLive { error = String(localized: "Nothing was heard") }
            else if let polisher { finish(polishing: live, with: polisher, language: language) }
            return
        }
        let duration = capture.finish()
        guard duration >= Self.minDuration else {
            capture.discard()
            if !heardLive { error = String(localized: "Too short — keep it on while you speak") }
            return
        }
        // Oltre il limite del server (413) la registrazione non parte: resta il testo dal vivo.
        let tooLarge = maxAudioBytes.map { limit in capture.byteCount > limit } ?? false

        let prompt = self.prompt
        isTranscribing = true
        upload = Task { [weak self] in
            defer { capture.discard() }
            var text: String?
            var failed = false
            if !tooLarge {
                do {
                    text = try await transcriber(capture.url, language, prompt)?
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                } catch {
                    failed = true
                }
            }
            guard let self, !Task.isCancelled else { return }
            if let text, !text.isEmpty {
                self.onText?(text, true)
            } else if !live.isEmpty, let polisher {
                // Il server non ha trascritto (spento, firewall, 413, 502): si ripulisce il testo dal vivo.
                let polished = await Self.polish(live, with: polisher, language: language)
                // Annullata nel frattempo (Scarta, messaggio partito, nuova dettatura): non tocca più niente.
                guard !Task.isCancelled else { return }
                if let polished { self.onText?(polished, true) }
            } else if !self.heardLive {
                self.error = text == nil || failed
                    ? String(localized: "Could not transcribe that")
                    : String(localized: "Nothing was heard")
            }
            self.isTranscribing = false
            self.onText = nil
        }
    }

    /// Solo il riconoscitore sul telefono: il suo testo passa da `polish` e prende il posto di quello dal vivo.
    private func finish(polishing text: String, with polisher: @escaping Polisher, language: String?) {
        isTranscribing = true
        upload = Task { [weak self] in
            let polished = await Self.polish(text, with: polisher, language: language)
            guard let self, !Task.isCancelled else { return }
            if let polished { self.onText?(polished, true) }
            self.isTranscribing = false
            self.onText = nil
        }
    }

    /// `nil` se la pulizia non riesce o non cambia niente: il testo dal vivo resta com'è.
    nonisolated private static func polish(_ text: String, with polisher: Polisher, language: String?) async -> String? {
        guard let polished = try? await polisher(text, language)
            .trimmingCharacters(in: .whitespacesAndNewlines), !polished.isEmpty, polished != text else { return nil }
        return polished
    }

    /// Ferma e scarta: niente altro testo nel campo (es. il messaggio è appena partito).
    func cancel() {
        onText = nil
        upload?.cancel()
        upload = nil
        isTranscribing = false
        capture?.discard()
        capture = nil
        tearDownAudio()
        task?.cancel()
        task = nil
    }

    private func tearDownAudio() {
        limit?.cancel()
        limit = nil
        if engine.isRunning { engine.stop() }
        engine.inputNode.removeTap(onBus: 0)
        sink.request?.endAudio()
        sink.request = nil
        recognizer = nil
        isListening = false
        startedAt = nil
        level = 0
        Self.deactivateAudioSession()
    }

    /// Testo dal vivo. Il riconoscitore si ferma da solo (silenzio, o circa un minuto di parlato): senza
    /// registrazione la dettatura finisce lì; mentre si registra per il server riparte con una richiesta nuova,
    /// e il suo testo si aggiunge a quello già sentito (se il server poi non trascrive, resta tutto).
    private func receive(_ text: String?, done: Bool, generation: Int) {
        guard generation == self.generation else { return }
        if let text, !text.isEmpty, isListening {
            heardLive = true
            liveText = committedLive.isEmpty ? text : committedLive + " " + text
            onText?(liveText, false)
        }
        guard done else { return }
        guard isListening, capture != nil, let recognizer else {
            if capture == nil { stop() } else { task = nil }
            return
        }
        committedLive = liveText
        let request = Self.makeRequest(hints: hints)
        sink.request?.endAudio()
        sink.request = request
        self.generation += 1
        task = recognizer.recognitionTask(with: request,
                                          resultHandler: Self.resultHandler(owner: self, generation: self.generation))
    }

    private static func makeRequest(hints: [String]) -> SFSpeechAudioBufferRecognitionRequest {
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        request.contextualStrings = hints
        return request
    }

    // MARK: - Fuori dal MainActor (thread audio / callback del riconoscitore)

    /// Il tap gira sul thread audio: manda i campioni al riconoscitore e al file, il volume alla UI.
    nonisolated private static func tapBlock(sink: AriaRecognitionSink,
                                             capture: AriaAudioCapture?,
                                             owner: AriaDictation) -> AVAudioNodeTapBlock {
        { [weak owner] buffer, _ in
            sink.append(buffer)
            capture?.write(buffer)
            let level = min(1, rms(of: buffer) * 8)
            Task { @MainActor [owner] in owner?.level = level }
        }
    }

    nonisolated private static func resultHandler(owner: AriaDictation,
                                                  generation: Int) -> (SFSpeechRecognitionResult?, Error?) -> Void {
        { [weak owner] result, error in
            let text = result?.bestTranscription.formattedString
            let done = (result?.isFinal ?? false) || error != nil
            Task { @MainActor [owner] in owner?.receive(text, done: done, generation: generation) }
        }
    }

    nonisolated private static func rms(of buffer: AVAudioPCMBuffer) -> Float {
        guard let samples = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return 0 }
        let count = Int(buffer.frameLength)
        var sum: Float = 0
        for i in 0..<count { sum += samples[i] * samples[i] }
        return sqrtf(sum / Float(count))
    }

    nonisolated private static func speechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        let current = SFSpeechRecognizer.authorizationStatus()
        guard current == .notDetermined else { return current }
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
    }

    /// `setActive` può bloccare: fuori dal main thread.
    nonisolated private static func activateAudioSession() async throws {
        try await Task.detached {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        }.value
    }

    nonisolated private static func deactivateAudioSession() {
        Task.detached {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }
}

// MARK: - Richiesta del riconoscitore

/// La richiesta del riconoscitore a cui il thread audio manda i campioni. Il MainActor la sostituisce quando
/// il riconoscitore si ferma da solo; il thread audio la legge a ogni buffer: gli accessi passano da un lock.
nonisolated final class AriaRecognitionSink: @unchecked Sendable {
    private let lock = NSLock()
    private var current: SFSpeechAudioBufferRecognitionRequest?

    var request: SFSpeechAudioBufferRecognitionRequest? {
        get { lock.withLock { current } }
        set { lock.withLock { current = newValue } }
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        lock.withLock { current }?.append(buffer)
    }
}

// MARK: - Registrazione per Whisper

/// La voce della dettatura in un file AAC (.m4a, che Whisper accetta come audio/mp4). Scritta dal thread
/// audio, chiusa e letta dal MainActor: gli accessi passano da un lock.
nonisolated final class AriaAudioCapture: @unchecked Sendable {
    let url: URL
    private var file: AVAudioFile?
    private var frames: AVAudioFramePosition = 0
    private let sampleRate: Double
    private let lock = NSLock()

    init(format: AVAudioFormat) throws {
        url = FileManager.default.temporaryDirectory.appending(path: "dictation-\(UUID().uuidString).m4a")
        sampleRate = format.sampleRate
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: format.sampleRate,
            AVNumberOfChannelsKey: format.channelCount,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
        ]
        file = try AVAudioFile(forWriting: url, settings: settings,
                               commonFormat: format.commonFormat, interleaved: format.isInterleaved)
    }

    func write(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        defer { lock.unlock() }
        guard let file, (try? file.write(from: buffer)) != nil else { return }
        frames += AVAudioFramePosition(buffer.frameLength)
    }

    /// Quanto pesa il file registrato (dopo `finish`).
    var byteCount: Int {
        (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
    }

    /// Chiude il file e dice quanti secondi di voce contiene.
    func finish() -> TimeInterval {
        lock.lock()
        defer { lock.unlock() }
        file?.close()
        file = nil
        return sampleRate > 0 ? Double(frames) / sampleRate : 0
    }

    func discard() {
        _ = finish()
        try? FileManager.default.removeItem(at: url)
    }
}
