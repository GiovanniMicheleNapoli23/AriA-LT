//
//  AriaDictation.swift
//  AriaLite
//
//  Dettatura nel campo della chat (il microfono del composer): voce → testo con
//  SFSpeechRecognizer, disponibile fino a iOS 18. Non è la voce dal vivo di Aria
//  (AriaVoiceViewModel): qui si scrive soltanto, e si manda quando si vuole.
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

    private(set) var isListening = false
    /// Volume del microfono, 0…1, per l'anello attorno al pulsante.
    private(set) var level: Float = 0
    var error: String?

    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private var request: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var task: SFSpeechRecognitionTask?
    /// Riceve la trascrizione (parziale e poi finale) della dettatura in corso.
    @ObservationIgnored private var onText: ((String) -> Void)?

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

    func toggle(onText: @escaping (String) -> Void) async {
        if isListening { stop() } else { await start(onText: onText) }
    }

    func start(onText: @escaping (String) -> Void) async {
        guard !isListening else { return }
        error = nil
        task?.cancel()
        task = nil

        guard await Self.speechAuthorization() == .authorized else {
            error = String(localized: "Allow Speech Recognition for AriaLite in Settings to dictate.")
            return
        }
        guard await AVAudioApplication.requestRecordPermission() else {
            error = String(localized: "Allow the microphone for AriaLite in Settings to dictate.")
            return
        }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: speechTag)), recognizer.isAvailable else {
            error = String(localized: "Dictation isn't available for this language right now.")
            return
        }

        do {
            try await Self.activateAudioSession()
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            request.addsPunctuation = true

            let input = engine.inputNode
            input.removeTap(onBus: 0)
            input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0),
                             block: Self.tapBlock(request: request, owner: self))
            engine.prepare()
            try engine.start()

            self.request = request
            self.onText = onText
            task = recognizer.recognitionTask(with: request, resultHandler: Self.resultHandler(owner: self))
            isListening = true
        } catch {
            self.error = error.localizedDescription
            tearDownAudio()
        }
    }

    /// Ferma l'ascolto: l'ultimo pezzo di trascrizione arriva ancora nel campo.
    func stop() {
        guard isListening else { return }
        tearDownAudio()
        task?.finish()
    }

    /// Ferma e scarta: niente altro testo nel campo (es. il messaggio è appena partito).
    func cancel() {
        onText = nil
        tearDownAudio()
        task?.cancel()
        task = nil
    }

    private func tearDownAudio() {
        if engine.isRunning { engine.stop() }
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        request = nil
        isListening = false
        level = 0
        Self.deactivateAudioSession()
    }

    // MARK: - Fuori dal MainActor (thread audio / callback del riconoscitore)

    /// Il tap gira sul thread audio: manda i campioni al riconoscitore e il volume alla UI.
    nonisolated private static func tapBlock(request: SFSpeechAudioBufferRecognitionRequest,
                                             owner: AriaDictation) -> AVAudioNodeTapBlock {
        { [weak owner] buffer, _ in
            request.append(buffer)
            let level = min(1, rms(of: buffer) * 8)
            Task { @MainActor in owner?.level = level }
        }
    }

    nonisolated private static func resultHandler(owner: AriaDictation) -> (SFSpeechRecognitionResult?, Error?) -> Void {
        { [weak owner] result, error in
            let text = result?.bestTranscription.formattedString
            let done = (result?.isFinal ?? false) || error != nil
            Task { @MainActor in
                guard let owner else { return }
                if let text { owner.onText?(text) }
                if done { owner.stop() }
            }
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
