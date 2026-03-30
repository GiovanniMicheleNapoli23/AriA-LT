//
//  AriaRealtimeSession.swift
//  Aria_v1.0
//
//  Sessione vocale nativa con OpenAI Realtime API via WebSocket + AVAudioEngine.
//  Zero dipendenze esterne — usa solo URLSessionWebSocketTask e AVFoundation.
//
//  Flusso:
//    1. Token effimero dal server Aria Engine
//    2. WebSocket a wss://api.openai.com/v1/realtime
//    3. Mic → AVAudioEngine → PCM16 24 kHz base64 → input_audio_buffer.append
//    4. response.audio.delta → base64 PCM16 → AVAudioPlayerNode
//    5. Function calls (RAG) gestite automaticamente
//

import Foundation
import AVFoundation

// MARK: - Delegate Protocol

protocol AriaRealtimeSessionDelegate: AnyObject {
    func session(_ session: AriaRealtimeSession, didReceiveTranscript text: String, from speaker: AriaRealtimeSession.Speaker)
    func session(_ session: AriaRealtimeSession, didChangeState state: AriaRealtimeSession.SessionState)
    func session(_ session: AriaRealtimeSession, isSearchingDocuments: Bool)
}

// MARK: - AriaRealtimeSession

final class AriaRealtimeSession: NSObject {

    // MARK: Types

    enum SessionState: Sendable { case idle, connecting, connected, disconnected }
    enum Speaker: Sendable { case user, assistant }

    // MARK: Public

    weak var delegate: AriaRealtimeSessionDelegate?

    private(set) var state: SessionState = .idle {
        didSet {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.delegate?.session(self, didChangeState: self.state)
            }
        }
    }

    var isMuted = false

    /// True quando la sessione è in mix mode (es. Teams/Meet attivo) —
    /// il mic potrebbe avere AEC ridotto
    var isOutputOnly: Bool { isUsingMixMode }

    // ── Anti-echo: approccio ChatGPT-style ──
    // Mic NON invia audio al server durante playback AI.
    // Barge-in rilevato localmente tramite energia RMS del microfono.
    /// True finché l'AI sta parlando O il suo audio è ancora in riproduzione
    private var isAISpeaking = false
    /// Conta i buffer audio schedulati ma non ancora riprodotti
    private var pendingBufferCount = 0
    /// True quando il server ha finito di inviare tutti i delta audio
    private var responseAudioComplete = false
    /// Timer di cooldown dopo l'ultima riproduzione
    private var unmuteCooldownWork: DispatchWorkItem?
    /// Lock per thread-safety
    private let bufferLock = NSLock()
    /// Soglia RMS per rilevare barge-in locale (voce vera vs eco speaker)
    private let bargeInRMSThreshold: Float = 0.025
    /// Chunk consecutivi sopra soglia necessari per confermare barge-in
    private let bargeInFramesNeeded = 2
    /// Contatore chunk sopra soglia (accesso solo sotto bufferLock)
    private var bargeInFrameCount = 0
    /// Response ID corrente per poterlo cancellare
    private var currentResponseId: String?
    /// Coda seriale per operazioni di stato (barge-in, unmute, ecc.)
    private let stateQueue = DispatchQueue(label: "com.aria.realtime.state")

    // MARK: WebSocket

    private var webSocket: URLSessionWebSocketTask?
    private var wsURLSession: URLSession?
    private var connectionContinuation: CheckedContinuation<Void, Error>?
    /// Viene impostato a true se il WS si chiude subito dopo didOpen (es. errore server)
    private var earlyDisconnect = false

    // MARK: Audio Engine

    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var inputConverter: AVAudioConverter?

    /// OpenAI Realtime: PCM16 little-endian, 24 kHz, mono
    private let sampleRate: Double = 24_000

    private lazy var pcm16Format: AVAudioFormat = {
        AVAudioFormat(commonFormat: .pcmFormatInt16,
                      sampleRate: sampleRate,
                      channels: 1,
                      interleaved: true)!
    }()

    /// Float32 per AVAudioPlayerNode (stessa sample rate)
    private lazy var playbackFormat: AVAudioFormat = {
        AVAudioFormat(commonFormat: .pcmFormatFloat32,
                      sampleRate: sampleRate,
                      channels: 1,
                      interleaved: false)!
    }()

    // ═══════════════════════════════════════════════
    // MARK: - Public API
    // ═══════════════════════════════════════════════

    func start() async throws {
        state = .connecting
        print("[AriaRealtime] ▶ start() — requesting ephemeral token…")

        // Se c'è un engine residuo, smonta senza disattivare la session
        // così configureAudioSession non trova una session appena rilasciata
        if audioEngine.isRunning {
            tearDownAudio(skipDeactivation: true)
        }

        // 1 — Token effimero
        let ephemeralKey: String
        do {
            ephemeralKey = try await AriaEngineService.shared.getToken()
            print("[AriaRealtime] ✅ Token received (\(ephemeralKey.prefix(12))…)")
        } catch {
            print("[AriaRealtime] ❌ Token failed: \(error)")
            throw error
        }

        // 2 — Audio session
        do {
            try configureAudioSession()
            print("[AriaRealtime] ✅ AVAudioSession configured")
        } catch {
            print("[AriaRealtime] ❌ AVAudioSession error: \(error)")
            throw error
        }

        // 3 — WebSocket (attende connessione stabilita)
        do {
            try await openWebSocket(ephemeralKey: ephemeralKey)
            print("[AriaRealtime] ✅ WebSocket connected")
        } catch {
            print("[AriaRealtime] ❌ WebSocket error: \(error)")
            throw error
        }

        // 3b — Configura la sessione: audio bidirezionale + VAD + voice
        sendSessionUpdate()

        // 4 — Audio engine (mic capture + playback)
        do {
            try startAudioEngine()
            print("[AriaRealtime] ✅ Audio engine running (mic + playback)")
        } catch {
            print("[AriaRealtime] ❌ Audio engine error: \(error)")
            closeWebSocket()
            throw error
        }

        state = .connected
        print("[AriaRealtime] ✅ Session fully connected")
    }

    func stop() {
        tearDownAudio()
        closeWebSocket()
        state = .disconnected
    }

    deinit {
        tearDownAudio()
        closeWebSocket()
    }

    /// Invia un messaggio di testo (anziché audio) durante la sessione
    func sendTextMessage(_ text: String) {
        sendJSON([
            "type": "conversation.item.create",
            "item": [
                "type": "message",
                "role": "user",
                "content": [["type": "input_text", "text": text]]
            ] as [String: Any]
        ])
        sendJSON(["type": "response.create"])
    }

    // ═══════════════════════════════════════════════
    // MARK: - Audio Session
    // ═══════════════════════════════════════════════

    /// True se la sessione è stata attivata in modalità mix (coesistenza con Teams/Meet)
    private var isUsingMixMode = false

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()

        // ── Strategia a 2 livelli ──
        // 1° tentativo: .voiceChat esclusivo → AEC hardware pieno
        // 2° fallback : .mixWithOthers → coesiste con Teams/Meet/FaceTime
        //               (AEC software via anti-echo locale è comunque attivo)

        // Livello 1 — Modalità esclusiva (qualità ottimale)
        do {
            try session.setCategory(.playAndRecord,
                                    mode: .voiceChat,
                                    options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP])
            try session.setPreferredSampleRate(sampleRate)
            try session.setPreferredIOBufferDuration(0.02)

            // Retry con back-off per riacquisto sessione post-teardown
            var activated = false
            for attempt in 1...3 {
                do {
                    if attempt > 1 {
                        try? session.setActive(false, options: .notifyOthersOnDeactivation)
                        Thread.sleep(forTimeInterval: 0.15 * Double(attempt))
                    }
                    try session.setActive(true)
                    activated = true
                    break
                } catch {
                    print("[AriaRealtime] ⚠️ [exclusive] setActive attempt \(attempt)/3 failed: \(error)")
                }
            }

            if activated {
                isUsingMixMode = false
                print("[AriaRealtime] ✅ Audio session: modalità esclusiva (.voiceChat)")
            } else {
                // Tutti i tentativi esclusivi falliti → prova mix
                throw NSError(domain: "AriaRealtime", code: -1)
            }
        } catch {
            // Livello 2 — Modalità mista (coesistenza con altra app audio)
            print("[AriaRealtime] ⚡ Altra app audio attiva — passo a modalità mix")
            try session.setCategory(.playAndRecord,
                                    mode: .voiceChat,
                                    options: [.defaultToSpeaker, .allowBluetooth,
                                              .allowBluetoothA2DP, .mixWithOthers])
            try session.setPreferredSampleRate(sampleRate)
            try session.setPreferredIOBufferDuration(0.02)
            try session.setActive(true)
            isUsingMixMode = true
            print("[AriaRealtime] ✅ Audio session: modalità mix (.mixWithOthers)")
        }

        // Solo se NON ci sono cuffie/bluetooth collegati, forza lo speaker
        let hasHeadphones = session.currentRoute.outputs.contains {
            [.headphones, .bluetoothA2DP, .bluetoothHFP, .bluetoothLE]
                .contains($0.portType)
        }
        if !hasHeadphones {
            try session.overrideOutputAudioPort(.speaker)
        }
    }

    // ═══════════════════════════════════════════════
    // MARK: - Audio Engine (Mic → OpenAI)
    // ═══════════════════════════════════════════════

    private func startAudioEngine() throws {
        // Ferma un eventuale engine precedente (deinit parziale / reconnect)
        audioEngine.stop()

        // Player per riprodurre l'audio dell'AI
        audioEngine.attach(playerNode)
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: playbackFormat)

        // Formato hardware del microfono (es. 48 kHz Float32)
        let inputNode = audioEngine.inputNode
        let hwFormat = inputNode.outputFormat(forBus: 0)

        guard let converter = AVAudioConverter(from: hwFormat, to: pcm16Format) else {
            throw AriaEngineService.AriaEngineError.tokenFailed(status: 0, body: "Audio converter init failed")
        }
        self.inputConverter = converter

        // ⚠️ Rimuovi eventuali tap residui — previene il crash
        // "required condition is false: nullptr == Tap()"
        inputNode.removeTap(onBus: 0)

        // Tap: ~60 ms di audio per chunk (reattività migliore per VAD e barge-in)
        let framesPerChunk = AVAudioFrameCount(hwFormat.sampleRate * 0.06)

        inputNode.installTap(onBus: 0,
                             bufferSize: framesPerChunk,
                             format: hwFormat) { [weak self] buffer, _ in
            guard let self, !self.isMuted else { return }

            // Leggi isAISpeaking in modo thread-safe
            self.bufferLock.lock()
            let aiSpeaking = self.isAISpeaking
            self.bufferLock.unlock()

            if aiSpeaking {
                // Mentre l'AI parla: NON inviare audio al server
                // Ma controlla se l'utente sta parlando (barge-in locale)
                let rms = self.computeRMS(buffer: buffer)
                self.bufferLock.lock()
                if rms > self.bargeInRMSThreshold {
                    self.bargeInFrameCount += 1
                    let count = self.bargeInFrameCount
                    self.bufferLock.unlock()
                    if count >= self.bargeInFramesNeeded {
                        // Dispatch OFF audio thread—NEVER call playerNode/sendJSON from here
                        self.stateQueue.async { [weak self] in
                            self?.executeLocalBargeIn()
                        }
                    }
                } else {
                    self.bargeInFrameCount = 0
                    self.bufferLock.unlock()
                }
            } else {
                // AI non parla: invia audio normalmente
                self.convertAndSend(buffer: buffer, converter: converter)
            }
        }

        audioEngine.prepare()
        try audioEngine.start()
        playerNode.play()
    }

    /// skipDeactivation = true quando si sta per riconnettersi subito
    private func tearDownAudio(skipDeactivation: Bool = false) {
        if audioEngine.isRunning {
            audioEngine.inputNode.removeTap(onBus: 0)
            playerNode.stop()
            audioEngine.stop()
        }
        inputConverter = nil

        // Reset anti-echo state
        bufferLock.lock()
        isAISpeaking = false
        pendingBufferCount = 0
        responseAudioComplete = false
        bargeInFrameCount = 0
        bufferLock.unlock()
        unmuteCooldownWork?.cancel()

        if !skipDeactivation {
            try? AVAudioSession.sharedInstance().setActive(false,
                                                           options: .notifyOthersOnDeactivation)
        }
    }

    // ═══════════════════════════════════════════════
    // MARK: - Mic Capture → base64 PCM16 → WebSocket
    // ═══════════════════════════════════════════════

    private func convertAndSend(buffer: AVAudioPCMBuffer, converter: AVAudioConverter) {
        // Numero di frame in output basato sul rapporto tra sample rate
        let ratio = sampleRate / buffer.format.sampleRate
        let outFrames = AVAudioFrameCount(Double(buffer.frameLength) * ratio)
        guard outFrames > 0,
              let out = AVAudioPCMBuffer(pcmFormat: pcm16Format, frameCapacity: outFrames)
        else { return }

        var error: NSError?
        var consumed = false

        converter.convert(to: out, error: &error) { _, outStatus in
            if consumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            consumed = true
            outStatus.pointee = .haveData
            return buffer
        }

        guard error == nil, out.frameLength > 0 else { return }

        // Int16 raw → base64
        let byteCount = Int(out.frameLength) * MemoryLayout<Int16>.size
        let data = Data(bytes: out.int16ChannelData![0], count: byteCount)
        let base64 = data.base64EncodedString()

        sendJSON(["type": "input_audio_buffer.append", "audio": base64])
    }

    // ═══════════════════════════════════════════════
    // MARK: - WebSocket → base64 PCM16 → Speaker
    // ═══════════════════════════════════════════════

    private func playAudioDelta(_ base64: String) {
        guard let raw = Data(base64Encoded: base64), !raw.isEmpty else { return }

        let sampleCount = raw.count / MemoryLayout<Int16>.size
        guard let buf = AVAudioPCMBuffer(pcmFormat: playbackFormat,
                                         frameCapacity: AVAudioFrameCount(sampleCount))
        else { return }

        buf.frameLength = AVAudioFrameCount(sampleCount)
        let dst = buf.floatChannelData![0]

        raw.withUnsafeBytes { ptr in
            let src = ptr.bindMemory(to: Int16.self)
            for i in 0..<sampleCount {
                dst[i] = Float(src[i]) / 32_768.0
            }
        }

        // Traccia riproduzione effettiva del buffer
        bufferLock.lock()
        pendingBufferCount += 1
        bufferLock.unlock()

        playerNode.scheduleBuffer(buf, completionCallbackType: .dataPlayedBack) { [weak self] _ in
            self?.onBufferPlayedBack()
        }
    }

    /// Chiamato quando un buffer audio è stato effettivamente riprodotto dallo speaker
    private func onBufferPlayedBack() {
        bufferLock.lock()
        pendingBufferCount = max(0, pendingBufferCount - 1)
        let remaining = pendingBufferCount
        let done = responseAudioComplete
        bufferLock.unlock()

        if done && remaining <= 0 {
            stateQueue.async { [weak self] in
                self?.scheduleUnmuteCooldown()
            }
        }
    }

    /// Dopo che l'ultimo buffer è riprodotto, aspetta prima di accettare nuovo speech
    private func scheduleUnmuteCooldown() {
        // Deve girare su stateQueue (già garantito dai chiamanti)
        unmuteCooldownWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.bufferLock.lock()
            self.isAISpeaking = false
            self.bargeInFrameCount = 0
            self.bufferLock.unlock()
            // Svuota il buffer input: scarta qualsiasi eco residuo
            self.sendJSON(["type": "input_audio_buffer.clear"])
            print("[AriaRealtime] 🎤 Pronto per nuovo input (buffer svuotato post-playback)")
        }
        unmuteCooldownWork = work
        // 500ms di cooldown dopo l'ultimo buffer riprodotto
        self.stateQueue.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    // ═══════════════════════════════════════════════
    // MARK: - Local Barge-In Detection
    // ═══════════════════════════════════════════════

    /// Calcola il livello RMS (volume) di un buffer audio
    private func computeRMS(buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0 }
        let frames = Int(buffer.frameLength)
        guard frames > 0 else { return 0 }
        let samples = channelData[0]
        var sumSquares: Float = 0
        for i in 0..<frames {
            let s = samples[i]
            sumSquares += s * s
        }
        return sqrtf(sumSquares / Float(frames))
    }

    /// Barge-in rilevato localmente — eseguito su stateQueue, MAI dal thread audio
    private func executeLocalBargeIn() {
        print("[AriaRealtime] 🎤 Barge-in LOCALE rilevato — cancello risposta AI")

        unmuteCooldownWork?.cancel()

        bufferLock.lock()
        pendingBufferCount = 0
        responseAudioComplete = false
        isAISpeaking = false
        bargeInFrameCount = 0
        bufferLock.unlock()

        // Stop playback (safe perché siamo su stateQueue, non audio thread)
        interruptPlayback()

        // Cancella la risposta in corso sul server
        if let respId = currentResponseId {
            sendJSON(["type": "response.cancel", "response_id": respId])
        } else {
            sendJSON(["type": "response.cancel"])
        }

        // Svuota il buffer mic lato server
        sendJSON(["type": "input_audio_buffer.clear"])
    }

    /// Interrompe la riproduzione quando l'utente inizia a parlare (barge-in)
    private func interruptPlayback() {
        playerNode.stop()
        playerNode.play()          
    }

    // ═══════════════════════════════════════════════
    // MARK: - WebSocket Lifecycle
    // ═══════════════════════════════════════════════

    private func openWebSocket(ephemeralKey: String) async throws {
        let model = "gpt-realtime-1.5"
        guard let url = URL(string: "wss://api.openai.com/v1/realtime?model=\(model)") else {
            throw AriaEngineService.AriaEngineError.badURL
        }
        print("[AriaRealtime] WS → \(url.absoluteString)")

        var request = URLRequest(url: url)
        request.setValue("Bearer \(ephemeralKey)", forHTTPHeaderField: "Authorization")
        // GA tokens: NO OpenAI-Beta header (causa api_version_mismatch)

        earlyDisconnect = false

        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        self.wsURLSession = session

        let ws = session.webSocketTask(with: request)
        self.webSocket = ws
        ws.resume()

        // Attendi che il WebSocket sia effettivamente aperto (con timeout)
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                    self.connectionContinuation = cont
                }
            }
            group.addTask {
                try await Task.sleep(nanoseconds: 15_000_000_000) // 15s timeout
                throw AriaEngineService.AriaEngineError.tokenFailed(
                    status: 0, body: "WebSocket connection timed out after 15s"
                )
            }
            // Il primo che completa vince; cancella l'altro
            try await group.next()
            group.cancelAll()
        }

        // Inizia ad ascoltare — e attendi un breve intervallo per
        // verificare che il server non abbia chiuso subito la connessione
        receiveLoop()
        try await Task.sleep(nanoseconds: 500_000_000) // 500ms grace
        if earlyDisconnect {
            throw AriaEngineService.AriaEngineError.tokenFailed(
                status: 4000, body: "WebSocket closed immediately after open (server rejected session)"
            )
        }
    }

    private func closeWebSocket() {
        webSocket?.cancel(with: .normalClosure, reason: nil)
        webSocket = nil
        wsURLSession?.invalidateAndCancel()
        wsURLSession = nil
    }

    // MARK: Receive loop

    private func receiveLoop() {
        webSocket?.receive { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    if let data = text.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        self.handleEvent(json)
                    }
                case .data(let data):
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        self.handleEvent(json)
                    }
                @unknown default:
                    break
                }
                self.receiveLoop()   // continua ad ascoltare

            case .failure(let error):
                print("[AriaRealtime] ❌ WS receive error: \(error)")
                DispatchQueue.main.async { self.state = .disconnected }
            }
        }
    }

    // MARK: Send helper

    private func sendJSON(_ dict: [String: Any]) {
        guard let ws = webSocket else {
            print("[AriaRealtime] ⚠️ sendJSON called but webSocket is nil")
            return
        }
        var event = dict
        if event["event_id"] == nil { event["event_id"] = UUID().uuidString }
        guard let data = try? JSONSerialization.data(withJSONObject: event),
              let text = String(data: data, encoding: .utf8) else { return }
        ws.send(.string(text)) { error in
            if let error {
                print("[AriaRealtime] ⚠️ WS send error: \(error)")
            }
        }
    }

    // MARK: Session Configuration

    /// Invia session.update per configurare audio bidirezionale, VAD,
    /// voice e input transcription.
    private func sendSessionUpdate() {
        // GA Realtime API — formato flat (session.type richiesto)
        let update: [String: Any] = [
            "type": "session.update",
            "session": [
                "type": "realtime",
                "modalities": ["text", "audio"],
                "instructions": "Sei Aria, assistente vocale di Sinaura Group. Rispondi in modo conciso e professionale nella lingua in cui ti parla l'utente. Puoi cercare documenti nella knowledge base aziendale usando la funzione search_knowledge_base.",
                "voice": "alloy",
                "input_audio_format": "pcm16",
                "output_audio_format": "pcm16",
                "input_audio_transcription": [
                    "model": "gpt-4o-transcribe"
                ] as [String: Any],
                "turn_detection": [
                    "type": "server_vad",
                    "threshold": 0.45,
                    "prefix_padding_ms": 400,
                    "silence_duration_ms": 350,
                    "create_response": true
                ] as [String: Any],
                "tools": [
                    [
                        "type": "function",
                        "name": "search_knowledge_base",
                        "description": "Search the company knowledge base for relevant documents",
                        "parameters": [
                            "type": "object",
                            "properties": [
                                "query": [
                                    "type": "string",
                                    "description": "The search query"
                                ]
                            ],
                            "required": ["query"]
                        ] as [String: Any]
                    ] as [String: Any]
                ]
            ] as [String: Any]
        ]
        print("[AriaRealtime] → Sending session.update (GA flat format, voice: alloy, VAD: server)")
        sendJSON(update)
    }

    // ═══════════════════════════════════════════════
    // MARK: - Event Handling
    // ═══════════════════════════════════════════════

    private func handleEvent(_ json: [String: Any]) {
        guard let type = json["type"] as? String else { return }

        // Log tutti gli eventi per debug
        switch type {
        case "response.output_audio.delta":
            break   // troppo frequente, non loggare
        case "input_audio_buffer.speech_started",
             "input_audio_buffer.speech_stopped",
             "input_audio_buffer.committed":
            print("[AriaRealtime] ◀ \(type)")
        default:
            // Log compatto per tutti gli altri eventi
            let preview = String(describing: json).prefix(300)
            print("[AriaRealtime] ◀ \(type): \(preview)")
        }

        switch type {

        // ── Sessione creata/aggiornata ──────────────
        case "session.created":
            if let sess = json["session"] as? [String: Any],
               let mods = sess["modalities"] as? [String] {
                print("[AriaRealtime] ✅ session.created — modalities: \(mods)")
            }

        case "session.updated":
            if let sess = json["session"] as? [String: Any],
               let mods = sess["modalities"] as? [String] {
                print("[AriaRealtime] ✅ session.updated — modalities: \(mods)")
            }

        // ── Audio in arrivo dall'AI (GA API: response.output_audio.delta) ──
        case "response.output_audio.delta":
            if let delta = json["delta"] as? String {
                bufferLock.lock()
                let wasAlreadySpeaking = isAISpeaking
                if !wasAlreadySpeaking {
                    isAISpeaking = true
                    pendingBufferCount = 0
                    responseAudioComplete = false
                    bargeInFrameCount = 0
                }
                bufferLock.unlock()
                if !wasAlreadySpeaking {
                    unmuteCooldownWork?.cancel()
                    print("[AriaRealtime] 🔊 AI sta parlando (mic sospeso al server, barge-in locale attivo)")
                }
                playAudioDelta(delta)
            }

        // ── Inizio risposta (salva response_id per cancel) ──
        case "response.created":
            if let resp = json["response"] as? [String: Any],
               let rId = resp["id"] as? String {
                currentResponseId = rId
            }

        // ── L'utente ha iniziato a parlare (barge-in server-side) ──
        case "input_audio_buffer.speech_started":
            unmuteCooldownWork?.cancel()
            bufferLock.lock()
            isAISpeaking = false
            pendingBufferCount = 0
            responseAudioComplete = false
            bargeInFrameCount = 0
            bufferLock.unlock()
            interruptPlayback()
            print("[AriaRealtime] 🎤 Barge-in server-side")

        // ── Server ha finito di inviare audio delta ──
        case "response.done":
            bufferLock.lock()
            responseAudioComplete = true
            let remaining = pendingBufferCount
            bufferLock.unlock()
            // Se tutti i buffer sono già stati riprodotti, avvia cooldown
            if remaining <= 0 {
                scheduleUnmuteCooldown()
            }
            // altrimenti onBufferPlayedBack() attiverà il cooldown

        // ── Transcript AI (GA API: response.output_audio_transcript.done) ──
        case "response.output_audio_transcript.done":
            if let text = json["transcript"] as? String {
                delegate?.session(self, didReceiveTranscript: text, from: .assistant)
            }

        // ── Transcript utente ───────────────────────
        case "conversation.item.input_audio_transcription.completed":
            if let text = json["transcript"] as? String {
                delegate?.session(self, didReceiveTranscript: text, from: .user)
            }

        // ── Function call (RAG) ─────────────────────
        case "response.function_call_arguments.done":
            if let callId = json["call_id"] as? String,
               let name = json["name"] as? String,
               let args = json["arguments"] as? String {
                handleFunctionCall(callId: callId, name: name, arguments: args)
            }

        // ── Error ───────────────────────────────────
        case "error":
            if let err = json["error"] as? [String: Any],
               let msg = err["message"] as? String {
                let code = err["code"] as? String ?? "unknown"
                print("[AriaRealtime] ❌ Server error [\(code)]: \(msg)")
            } else {
                print("[AriaRealtime] ❌ Server error (raw): \(json)")
            }

        default:
            break
        }
    }

    // ═══════════════════════════════════════════════
    // MARK: - Function Calls (RAG)
    // ═══════════════════════════════════════════════

    private func handleFunctionCall(callId: String, name: String, arguments: String) {
        guard name == "search_knowledge_base" else {
            sendFunctionResult(callId: callId, output: "Unsupported function: \(name)")
            return
        }

        delegate?.session(self, isSearchingDocuments: true)

        Task {
            do {
                guard let argsData = arguments.data(using: .utf8),
                      let argsDict = try JSONSerialization.jsonObject(with: argsData) as? [String: Any],
                      let query = argsDict["query"] as? String else {
                    sendFunctionResult(callId: callId, output: "Invalid query.")
                    return
                }

                let svc = AriaEngineService.shared
                let results = try await svc.searchKnowledgeBase(query: query)
                let context = svc.formatRAGResults(results)
                sendFunctionResult(callId: callId, output: context)
            } catch {
                sendFunctionResult(callId: callId, output: "Error: \(error.localizedDescription)")
            }

            await MainActor.run {
                delegate?.session(self, isSearchingDocuments: false)
            }
        }
    }

    private func sendFunctionResult(callId: String, output: String) {
        sendJSON([
            "type": "conversation.item.create",
            "item": [
                "type": "function_call_output",
                "call_id": callId,
                "output": output
            ] as [String: Any]
        ])
        sendJSON(["type": "response.create"])
    }
}

// MARK: - URLSessionWebSocketDelegate

extension AriaRealtimeSession: URLSessionWebSocketDelegate {

    func urlSession(_ session: URLSession,
                    webSocketTask: URLSessionWebSocketTask,
                    didOpenWithProtocol proto: String?) {
        print("[AriaRealtime] WS delegate → didOpen (proto: \(proto ?? "nil"))")
        connectionContinuation?.resume()
        connectionContinuation = nil
    }

    func urlSession(_ session: URLSession,
                    webSocketTask: URLSessionWebSocketTask,
                    didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
                    reason: Data?) {
        let reasonStr = reason.flatMap { String(data: $0, encoding: .utf8) } ?? "none"
        print("[AriaRealtime] WS delegate → didClose code=\(closeCode.rawValue) reason=\(reasonStr)")
        earlyDisconnect = true
        DispatchQueue.main.async { self.state = .disconnected }
    }

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didCompleteWithError error: Error?) {
        if let error {
            print("[AriaRealtime] WS delegate → didCompleteWithError: \(error)")
            connectionContinuation?.resume(throwing: error)
            connectionContinuation = nil
            DispatchQueue.main.async { self.state = .disconnected }
        }
    }
}
