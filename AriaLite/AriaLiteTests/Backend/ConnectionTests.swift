//
//  ConnectionTests.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 15/10/26.
//
//  Aria è collegata al server dopo l'accesso? Dal link verificato fino alla chat:
//  azienda e stabilimento, storico, suggerimenti e lo stream di POST /v1/mobile/responses con il contesto
//  dell'operatore (JWT, Company-Id, plant_id). Le prove a rete finta girano sempre; quelle contro
//  il server vero solo con ARIA_LIVE_SESSION (e ARIA_LIVE_CHAT=1 per scrivere un messaggio nella chat).
//

import Foundation
import Testing
@testable import AriaLite

private nonisolated enum ConnEnv {
    static func env(_ key: String) -> String? {
        let raw = ProcessInfo.processInfo.environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines)
        return raw?.isEmpty == false ? raw : nil
    }

    static var session: String? { env("ARIA_LIVE_SESSION") }
    static var chatEnabled: Bool { session != nil && env("ARIA_LIVE_CHAT") == "1" }
}

private extension AriaStreamEvent {
    /// Il tipo dell'evento, per confrontare le sequenze senza i payload.
    var kind: String {
        switch self {
        case .created: "created"
        case .textDelta: "textDelta"
        case .textDone: "textDone"
        case .completed: "completed"
        case .failed: "failed"
        default: "other"
        }
    }
}

private func collect(_ stream: AsyncThrowingStream<AriaStreamEvent, any Error>) async throws -> [AriaStreamEvent] {
    var events: [AriaStreamEvent] = []
    for try await event in stream { events.append(event) }
    return events
}

private func sse(_ events: [(name: String, data: String)]) -> Reply {
    let text = events.map { "event: \($0.name)\ndata: \($0.data)\n\n" }.joined()
    return Reply(status: 200, headers: ["Content-Type": "text/event-stream"], body: Data(text.utf8))
}

private let greeting = sse([
    ("response.created", #"{"id":"resp_1"}"#),
    ("response.output_text.delta", #"{"delta":"Ciao"}"#),
    ("response.output_text.done", #"{"text":"Ciao"}"#),
    ("response.completed", #"{"status":"completed"}"#),
])

extension BackendTests {
    // MARK: - Dopo l'accesso (rete finta)

    @Suite("Aria connection")
    struct AriaConnection {
        private let server = StubServer.shared

        init() { TestEnv.reset() }

        /// Backend con l'accesso fatto, la rete finta ripulita dalle chiamate di accesso.
        private func signedInBackend(plants: Reply = .json(#"[{"id":"p1","name":"Plant 1","code":"P1"}]"#))
            async throws -> AriaBackend {
            TestEnv.stubSignIn(plants: plants)
            let backend = AriaBackend()
            try await TestEnv.requestLink(backend)
            try await backend.completeSignIn(with: AriaSignInLink(token: "t"))
            return backend
        }

        private func request(_ backend: AriaBackend, input: String = "Ciao") -> AriaResponsesRequest {
            AriaResponsesRequest(input: input, plantId: backend.activePlantId ?? "", sessionId: "s-1",
                                 companyId: backend.activeCompanyId)
        }

        // MARK: Pronta

        @Test func afterSignInAriaIsReadyWithCompanyAndPlant() async throws {
            let backend = try await signedInBackend()

            #expect(backend.isSignedIn)
            #expect(backend.isReady, "la chat parla col backend solo con una sessione e uno stabilimento")
            #expect(backend.activeCompanyId == "c1")
            #expect(backend.activePlantId == "p1")
            #expect(backend.lastError == nil)

            // L'ordine del collegamento: email → link → sessione → JWT → azienda → stabilimenti.
            let order = server.calls.map { "\($0.method) \($0.path)" }
            #expect(order == ["POST /api/auth/mobile/request-link", "POST /api/auth/mobile/verify",
                              "GET /api/aria/token", "GET /v1/companies", "GET /v1/mobile/plants"])
            let plants = try #require(server.calls("GET /v1/mobile/plants").first)
            #expect(plants.header("company-id") == "c1", "dopo l'azienda ogni chiamata porta il Company-Id")
            #expect(plants.header("authorization")?.hasPrefix("Bearer ") == true)
        }

        @Test func anOperatorWithoutPlantsIsSignedInButTheChatStaysLocal() async throws {
            let backend = try await signedInBackend(plants: .json(#"{"detail":"Not found"}"#, status: 404))

            #expect(backend.isSignedIn)
            #expect(backend.activeCompanyId == "c1")
            #expect(backend.activePlantId == nil)
            #expect(!backend.isReady, "senza stabilimento `plant_id` manca e il backend risponde 422")
        }

        @Test func aSignedOutBackendIsNotReady() {
            let backend = AriaBackend()
            #expect(!backend.isSignedIn)
            #expect(!backend.isReady)
        }

        // MARK: Stream della chat

        @Test func theChatStreamGoesToTheAPIHostWithTheOperatorContext() async throws {
            let backend = try await signedInBackend()
            server.route("POST /v1/mobile/responses", greeting)

            let events = try await collect(backend.api.stream(request(backend)))

            #expect(events.map(\.kind) == ["created", "textDelta", "textDone", "completed"])
            if case .textDelta(let text) = events[1] { #expect(text == "Ciao") } else { Issue.record("atteso textDelta") }

            let call = try #require(server.calls("POST /v1/mobile/responses").first)
            #expect(call.host == backend.api.config.apiBaseURL.host())
            #expect(call.header("authorization")?.hasPrefix("Bearer ") == true)
            #expect(call.header("company-id") == "c1")
            #expect(call.header("accept") == "text/event-stream")
            #expect(call.header("content-type") == "application/json")
            #expect(call.header("x-aria-client")?.hasPrefix("aria-ios/") == true)
            #expect(call.header("cookie") == nil)

            let body = try #require(call.json)
            #expect(body["input"] as? String == "Ciao")
            #expect(body["plant_id"] as? String == "p1")
            #expect(body["session_id"] as? String == "s-1")
            #expect(body["company_id"] as? String == "c1")
            #expect(body["stream"] as? Bool == true)
            #expect(body["include_metadata_events"] as? Bool == true, "senza, niente tool call né artifact")
        }

        @Test func aServerErrorEventEndsTheStreamAsFailed() async throws {
            let backend = try await signedInBackend()
            server.route("POST /v1/mobile/responses", sse([
                ("response.created", #"{"id":"resp_1"}"#),
                ("error", #"{"message":"model unavailable"}"#),
            ]))

            let events = try await collect(backend.api.stream(request(backend)))

            #expect(events.map(\.kind) == ["created", "failed"])
            if case .failed(let message) = events[1] { #expect(message == "model unavailable") }
        }

        @Test func aRejectedJWTIsRenewedOnceAndTheStreamGoesThrough() async throws {
            let backend = try await signedInBackend()
            server.route("GET /api/aria/token", TestEnv.tokenReply(tag: "b"))
            server.route("POST /v1/mobile/responses", .json(#"{"detail":"expired"}"#, status: 401), greeting)

            let events = try await collect(backend.api.stream(request(backend)))

            #expect(events.last?.kind == "completed")
            let sent = server.calls("POST /v1/mobile/responses")
            #expect(sent.count == 2, "un solo tentativo in più")
            #expect(sent[0].header("authorization") != sent[1].header("authorization"), "il secondo porta un JWT nuovo")
            #expect(server.calls("GET /api/aria/token").count == 2, "uno all'accesso, uno dopo il 401")
        }

        @Test func aSecond401IsNotRetriedAgain() async throws {
            let backend = try await signedInBackend()
            server.route("POST /v1/mobile/responses", .json(#"{"detail":"expired"}"#, status: 401))

            await #expect { _ = try await collect(backend.api.stream(request(backend))) } throws: { error in
                if case AriaError.http(401, _) = error { true } else { false }
            }
            #expect(server.calls("POST /v1/mobile/responses").count == 2)
        }

        @Test func anOperatorRemovedFromTheCompanyIsSignedOutByTheStream() async throws {
            let backend = try await signedInBackend()
            server.route("POST /v1/mobile/responses", .json(#"{"detail":"Not a member of this company"}"#, status: 403))

            await #expect { _ = try await collect(backend.api.stream(request(backend))) } throws: { error in
                if case AriaError.signedOut = error { true } else { false }
            }
            #expect(!backend.api.auth.hasStoredLogin, "la sessione non vale più: via dal Keychain")
        }

        @Test func aGatewayErrorOnTheStreamIsOfflineNotAnAPIError() async throws {
            let backend = try await signedInBackend()
            server.route("POST /v1/mobile/responses", .hostDown())

            await #expect { _ = try await collect(backend.api.stream(request(backend))) } throws: { error in
                if case AriaError.serverOffline = error { true } else { false }
            }
            #expect(backend.isSignedIn, "il server è giù, la sessione è buona")
        }

        @Test func aMessageOverTheWAFLimitNeverLeavesThePhone() async throws {
            let backend = try await signedInBackend()
            server.route("POST /v1/mobile/responses", greeting)

            let long = String(repeating: "x", count: 9_000)
            await #expect { _ = try await collect(backend.api.stream(request(backend, input: long))) } throws: { error in
                if case AriaError.bodyTooLarge = error { true } else { false }
            }
            #expect(server.calls("POST /v1/mobile/responses").isEmpty)
        }

        @Test func aDroppedConnectionPropagatesAsAnOfflineError() async throws {
            let backend = try await signedInBackend()
            server.route("POST /v1/mobile/responses", .failing(.notConnectedToInternet))

            await #expect { _ = try await collect(backend.api.stream(request(backend))) } throws: { error in
                AriaHTTP.isOffline(error)
            }
        }

        // MARK: Storico e suggerimenti

        @Test func historyListsTheSessionsOfTheConnectedOperator() async throws {
            let backend = try await signedInBackend()
            server.route("GET /v1/mobile/chat/sessions", .json("""
            [{"session_id":"s-1","title":"Pompa 3","status":"active","created_at":"2026-10-14T08:00:00Z",
              "last_activity_at":"2026-10-14T09:30:00Z"},
             {"session_id":"s-2","title":null,"status":"closed","created_at":"2026-10-13T08:00:00Z"}]
            """))

            let sessions = try await AriaChatAPI(api: backend.api).sessions()

            #expect(sessions.map(\.sessionId) == ["s-1", "s-2"])
            #expect(sessions.first?.title == "Pompa 3")
            #expect(sessions.first?.lastActivity != nil)
            let call = try #require(server.calls("GET /v1/mobile/chat/sessions").first)
            #expect(call.query == "limit=60&offset=0")
            #expect(call.header("company-id") == "c1")
        }

        @Test func anOperatorHasNoSuggestionsEndpointSoNothingIsCalled() async throws {
            let backend = try await signedInBackend()
            server.route("GET /v1/chat/suggestions", .json(#"{"suggestions":["Stato della pompa 3?"]}"#, status: 403))

            let suggestions = await backend.suggestions()

            #expect(suggestions.isEmpty)
            #expect(server.calls("GET /v1/chat/suggestions").isEmpty, "fuori da /v1/mobile risponderebbe 403")
            #expect(backend.isSignedIn)
            #expect(backend.lastError == nil)
        }

        @Test func historyReadsTheMessagesAndThePendingApprovalFromTheMobileRoutes() async throws {
            let backend = try await signedInBackend()
            server.route("GET /v1/mobile/chat/sessions/s-1/messages", .json(#"[{"id":"m1","role":"user","text":"Ciao"}]"#))
            server.route("GET /v1/mobile/chat/sessions/s-1/pending-interrupt", .json(#"{"interrupt":null}"#))
            let chat = AriaChatAPI(api: backend.api)

            let messages = try await chat.messages(sessionId: "s-1")
            let pending = await chat.pendingInterrupt(sessionId: "s-1")

            #expect(messages.map(\.role) == ["user"] && messages.first?.text == "Ciao")
            #expect(pending == nil)
            #expect(server.calls("GET /v1/mobile/chat/sessions/s-1/messages").first?.header("company-id") == "c1")
        }

        @Test func webOnlyActionsAreRefusedForAnOperatorWithoutCallingTheServer() async throws {
            let backend = try await signedInBackend()
            let chat = AriaChatAPI(api: backend.api)
            let before = server.calls.count

            await #expect(throws: AriaError.self) { try await chat.rename(sessionId: "s-1", title: "x") }
            await #expect(throws: AriaError.self) { try await chat.delete(sessionId: "s-1") }
            await chat.learning(sessionId: "s-1", answers: [])

            #expect(server.calls.count == before)
        }
    }

    // MARK: - Contro il server vero (ARIA_LIVE_SESSION)

    @Suite("Live backend · Aria connection")
    struct LiveAriaConnection {
        init() {
            AriaHTTP.extraProtocolClasses = []
            AriaKeychain.delete("aria.mobile_session")
        }

        /// Sessione nel Keychain come l'app la salva; azienda e (se c'è) stabilimento come `bootstrap`.
        private func connect(_ body: (AriaAPIClient, _ plantId: String?) async throws -> Void) async throws {
            let session = try #require(ConnEnv.session)
            AriaKeychain.set(session, for: "aria.mobile_session")
            defer { AriaKeychain.delete("aria.mobile_session") }

            let config = AriaConfig(
                apiBaseURL: ConnEnv.env("ARIA_LIVE_API").flatMap(URL.init(string:)) ?? AriaConfig.productionAPI,
                authBaseURL: ConnEnv.env("ARIA_LIVE_AUTH").flatMap(URL.init(string:)) ?? AriaConfig.productionSignIn)
            let context = AriaContext()
            await context.setCompany(nil)
            await context.setPlant(nil)
            let client = AriaAPIClient(config: config, auth: AriaAuth(config: config), context: context)

            let companies: [AriaCompany] = try await client.get("v1/companies", companyScoped: false)
            let company = try #require(companies.first, "nessuna azienda: l'accesso non è completo")
            await context.setCompany(company.id)

            let plants: [AriaPlant]? = try? await client.get("v1/mobile/plants")
            let plant = ConnEnv.env("ARIA_LIVE_PLANT") ?? plants?.first?.id
            if let plant { await context.setPlant(plant) }
            try await body(client, plant)
        }

        @Test(.enabled(if: ConnEnv.session != nil, "ARIA_LIVE_SESSION"))
        func afterSignInTheServerAnswersWithCompanyAndHistory() async throws {
            try await connect { client, _ in
                // Se l'azienda risponde e lo storico si decodifica, sessione, JWT e Company-Id sono accettati
                // anche dalle rotte della chat, non solo da /v1/mobile.
                let sessions = try await AriaChatAPI(api: client).sessions(limit: 5)
                #expect(sessions.count <= 5)
                #expect(sessions.allSatisfy { !$0.sessionId.isEmpty })
            }
        }

        @Test(.enabled(if: ConnEnv.session != nil, "ARIA_LIVE_SESSION"))
        func suggestionsAnswerWhenThereIsAPlant() async throws {
            try await connect { client, plant in
                guard let plant else {
                    print("LIVE: nessuno stabilimento (ARIA_LIVE_PLANT): suggerimenti non provati")
                    return
                }
                let suggestions = await AriaChatAPI(api: client).suggestions(plantId: plant, locale: "it")
                #expect(suggestions.allSatisfy { !$0.isEmpty })
            }
        }

        /// Scrive un messaggio vero: costa una risposta del modello e lascia una sessione, che poi si cancella.
        @Test(.enabled(if: ConnEnv.chatEnabled, "ARIA_LIVE_SESSION + ARIA_LIVE_CHAT=1"))
        func theChatStreamOpensAndCompletes() async throws {
            try await connect { client, plant in
                let plantId = try #require(plant, "serve uno stabilimento: ARIA_LIVE_PLANT")
                let sessionId = "ios-live-\(UUID().uuidString.lowercased())"
                let request = AriaResponsesRequest(input: "Rispondi solo con la parola: ok", plantId: plantId,
                                                   sessionId: sessionId, companyId: nil)
                let stream = client.stream(request)

                let collector = Task { () -> [AriaStreamEvent] in
                    var events: [AriaStreamEvent] = []
                    for try await event in stream {
                        events.append(event)
                        if event.kind == "completed" || event.kind == "failed" { break }
                    }
                    return events
                }
                let timeout = Task {
                    try await Task.sleep(for: .seconds(90))
                    collector.cancel()
                }
                defer { timeout.cancel() }

                let events: [AriaStreamEvent]
                do { events = try await collector.value }
                catch {
                    try? await AriaChatAPI(api: client).delete(sessionId: sessionId)
                    throw error
                }
                try? await AriaChatAPI(api: client).delete(sessionId: sessionId)

                #expect(events.first?.kind == "created", "il server non ha aperto la risposta")
                #expect(events.contains { $0.kind == "textDelta" || $0.kind == "textDone" }, "nessun testo")
                #expect(events.last?.kind == "completed", "terminata in \(events.last?.kind ?? "nulla")")
            }
        }
    }
}
