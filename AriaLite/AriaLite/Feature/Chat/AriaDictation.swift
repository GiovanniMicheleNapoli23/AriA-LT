//
//  AriaDictation.swift
//  AriaLite
//
//  Dettatura nel campo della chat (il microfono del composer), ibrida come sulla web (use-dictation):
//  mentre si parla SFSpeechRecognizer scrive le parole dal vivo e intanto la stessa voce si registra;
//  allo stop la registrazione va a Whisper sul backend (POST v1/audio/transcriptions) e il suo testo,
//  più preciso sui termini di reparto, prende il posto di quello dal vivo. Senza Whisper (servizio
//  spento, rete) resta il testo dal vivo; senza riconoscitore sul telefono scrive solo Whisper.
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

    private(set) var isListening = false
    /// Registrazione finita, in attesa del testo di Whisper.
    private(set) var isTranscribing = false
    /// Volume del microfono, 0…1, per l'anello attorno al pulsante.
    private(set) var level: Float = 0
    var error: String?

    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private var request: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var task: SFSpeechRecognitionTask?
    /// Riceve la trascrizione: dal vivo (`final` falso) e poi, se c'è, quella di Whisper (`final` vero).
    @ObservationIgnored private var onText: ((_ text: String, _ final: Bool) -> Void)?
    @ObservationIgnored private var capture: AriaAudioCapture?
    @ObservationIgnored private var transcriber: Transcriber?
    @ObservationIgnored private var prompt: String?
    @ObservationIgnored private var heardLive = false
    @ObservationIgnored private var upload: Task<Void, Never>?
    @ObservationIgnored private var limit: Task<Void, Never>?

    /// Come la web: oltre i 2 minuti si ferma da sola, sotto i 350 ms non si manda niente.
    private static let maxDuration: Duration = .seconds(120)
    private static let minDuration: TimeInterval = 0.35

    /// Codice scelto (`automatic` o uno di `languages`), ricordato sul telefono. Si sceglie dal menu
    /// della chat (AriaChatOptionsSheet, con `@AppStorage` sulla stessa chiave) e si legge a ogni dettatura.
    static let languageKey = "aria.dictation.language"

    static var language: String {
        let stored = UserDefaults.standard.string(forKey: languageKey) ?? automatic
        return stored == automatic || languages.contains { $0.code == stored } ? stored : automatic
    }

    /// Il tag da dare al riconoscitore: mai "auto", non sa rilevare la lingua.
    private var speechTag: String {
        let language = Self.language
        let code = language == Self.automatic
            ? (Locale.current.language.languageCode?.identifier ?? "en")
            : language
        return Self.languages.first { $0.code == code }?.speechTag ?? "en-GB"
    }

    // MARK: - Avvio / stop

    func toggle(context: String?, transcriber: Transcriber?,
                onText: @escaping (_ text: String, _ final: Bool) -> Void) async {
        if isListening { stop() } else { await start(context: context, transcriber: transcriber, onText: onText) }
    }

    func start(context: String?, transcriber: Transcriber?,
               onText: @escaping (_ text: String, _ final: Bool) -> Void) async {
        guard !isListening, !isTranscribing else { return }
        error = nil
        task?.cancel()
        task = nil

        guard await AVAudioApplication.requestRecordPermission() else {
            error = String(localized: "Allow the microphone for AriaLite in Settings to dictate.")
            return
        }
        // Il riconoscitore sul telefono dà le parole dal vivo; se manca basta Whisper.
        let recognizer = await Self.speechAuthorization() == .authorized
            ? SFSpeechRecognizer(locale: Locale(identifier: speechTag)).flatMap { $0.isAvailable ? $0 : nil }
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

            var request: SFSpeechAudioBufferRecognitionRequest?
            if recognizer != nil {
                let live = SFSpeechAudioBufferRecognitionRequest()
                live.shouldReportPartialResults = true
                live.addsPunctuation = true
                request = live
            }
            let capture = transcriber == nil ? nil : try? AriaAudioCapture(format: format)

            input.removeTap(onBus: 0)
            input.installTap(onBus: 0, bufferSize: 1024, format: format,
                             block: Self.tapBlock(request: request, capture: capture, owner: self))
            engine.prepare()
            try engine.start()

            self.request = request
            self.capture = capture
            self.transcriber = capture == nil ? nil : transcriber
            self.prompt = context.map { String($0.suffix(300)) }
            self.onText = onText
            heardLive = false
            if let recognizer, let request {
                task = recognizer.recognitionTask(with: request, resultHandler: Self.resultHandler(owner: self))
            }
            isListening = true
            limit = Task { [weak self] in
                try? await Task.sleep(for: Self.maxDuration)
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
        guard let capture, let transcriber else {
            if !heardLive { error = String(localized: "Nothing was heard") }
            return
        }
        let duration = capture.finish()
        guard duration >= Self.minDuration else {
            capture.discard()
            if !heardLive { error = String(localized: "Too short — keep it on while you speak") }
            return
        }

        let language = Self.language == Self.automatic ? nil : Self.language
        let prompt = self.prompt
        isTranscribing = true
        upload = Task { [weak self] in
            defer { capture.discard() }
            do {
                let text = try await transcriber(capture.url, language, prompt)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard let self, !Task.isCancelled else { return }
                if let text, !text.isEmpty {
                    self.onText?(text, true)
                } else if !self.heardLive {
                    self.error = text == nil
                        ? String(localized: "Could not transcribe that")
                        : String(localized: "Nothing was heard")
                }
            } catch {
                // Whisper non c'è o non risponde: il testo dal vivo resta com'è.
                guard let self, !Task.isCancelled else { return }
                if !self.heardLive { self.error = String(localized: "Could not transcribe that") }
            }
            self?.isTranscribing = false
            self?.onText = nil
        }
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
        request?.endAudio()
        request = nil
        isListening = false
        level = 0
        Self.deactivateAudioSession()
    }

    /// Testo dal vivo. Se il riconoscitore si ferma (errore, silenzio) e si sta registrando per Whisper,
    /// si continua ad ascoltare: la trascrizione vera arriva allo stop.
    private func receive(_ text: String?, done: Bool) {
        if let text, !text.isEmpty, isListening {
            heardLive = true
            onText?(text, false)
        }
        guard done else { return }
        if capture == nil { stop() } else { task = nil }
    }

    // MARK: - Fuori dal MainActor (thread audio / callback del riconoscitore)

    /// Il tap gira sul thread audio: manda i campioni al riconoscitore e al file, il volume alla UI.
    nonisolated private static func tapBlock(request: SFSpeechAudioBufferRecognitionRequest?,
                                             capture: AriaAudioCapture?,
                                             owner: AriaDictation) -> AVAudioNodeTapBlock {
        { [weak owner] buffer, _ in
            request?.append(buffer)
            capture?.write(buffer)
            let level = min(1, rms(of: buffer) * 8)
            Task { @MainActor in owner?.level = level }
        }
    }

    nonisolated private static func resultHandler(owner: AriaDictation) -> (SFSpeechRecognitionResult?, Error?) -> Void {
        { [weak owner] result, error in
            let text = result?.bestTranscription.formattedString
            let done = (result?.isFinal ?? false) || error != nil
            Task { @MainActor in owner?.receive(text, done: done) }
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
