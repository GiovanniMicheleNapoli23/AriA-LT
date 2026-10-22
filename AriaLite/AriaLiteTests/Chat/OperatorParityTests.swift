//
//  OperatorParityTests.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 21/10/26.
//
//  Le rotte che dal 20/10/2026 l'operatore condivide con un membro della web (guida "operator member
//  parity"): suggerimenti, contatore del contesto, dettatura, conferma e traduzione dei fatti, closeout,
//  report e .docx. Più la lista di controllo della guida: su un backend senza la rotta (403
//  `operation_forbidden`) la funzione si nasconde invece di riprovare, e la registrazione push non parte.
//

import Foundation
import Testing
@testable import AriaLite

private func sse(_ events: [(name: String, data: String)]) -> Reply {
    let text = events.map { "event: \($0.name)\ndata: \($0.data)\n\n" }.joined()
    var reply = Reply(status: 200, headers: ["Content-Type": "text/event-stream"], body: Data(text.utf8))
    reply.headers["X-Response-ID"] = "resp_r1"
    return reply
}

/// Il rifiuto di un backend che non ha ancora aperto la rotta all'operatore (resource_access.py).
private let forbidden = Reply.json(
    #"{"error":{"type":"http_error","message":"Operation is not permitted","code":403,"request_id":"x"},"detail":{"code":"operation_forbidden","message":"Operation is not permitted"}}"#,
    status: 403)

/// Un rifiuto in testo semplice: `error.message`, senza `detail` in cima.
private func plain(_ status: Int, _ message: String) -> Reply {
    .json(#"{"error":{"type":"http_error","message":"\#(message)","code":\#(status),"request_id":"x"}}"#, status: status)
}

private let usageJSON = #"{"usedTokens":61200,"limitTokens":200000,"messageTokens":48300,"overheadTokens":12900,"percentUsed":30.6,"autoCompactAt":80.0,"compactions":0,"compactedMessages":0,"compactableMessages":14,"canCompact":true,"model":"m"}"#

extension BackendTests {
    @Suite("Operator member parity")
    struct OperatorParity {
        private let server = StubServer.shared
        private let company = "/v1/companies/c1"

        init() {
            TestEnv.reset()
            AriaAgentChat.translationDebounce = .milliseconds(10)
        }

        private func signedIn() async throws -> AriaBackend {
            try await TestEnv.signedInStore().backend
        }

        private func chat(_ backend: AriaBackend, messages: String = "[]") async -> AriaAgentChat {
            let chat = AriaAgentChat(backend: backend, progressStore: AriaTaskProgressStore(inMemory: true))
            chat.makeRequestID = { "r1" }
            server.route("GET /v1/agent/sessions/S1/messages", .json(messages))
            await chat.open(sessionId: "S1")
            return chat
        }

        // MARK: Rotta che il backend non ha ancora

        @Test func operationForbiddenIsNotAvailableYetAndDoesNotSignOut() async throws {
            let backend = try await signedIn()
            server.route("GET /v1/chat/sessions/S1/context", forbidden)

            await #expect(throws: AriaError.self) { try await AriaChatAPI(api: backend.api).contextUsage(sessionId: "S1") }
            do {
                _ = try await AriaChatAPI(api: backend.api).contextUsage(sessionId: "S1")
            } catch AriaError.notOnPhone {
            } catch {
                Issue.record("atteso notOnPhone, arrivato \(error)")
            }
            #expect(backend.isSignedIn, "un 403 di una funzione non è un logout")
            #expect(backend.api.auth.hasStoredLogin)
        }

        @Test func aForbiddenFeatureHidesItselfAndIsNotAskedAgain() async throws {
            let backend = try await signedIn()
            server.route("GET /v1/chat/suggestions", forbidden)

            #expect(await backend.suggestions().isEmpty)
            #expect(await backend.suggestions().isEmpty)

            #expect(server.calls("GET /v1/chat/suggestions").count == 1, "non si riprova")
            #expect(!backend.isAvailable(.suggestions))
            #expect(backend.isAvailable(.closeout), "solo quella funzione")
            #expect(backend.lastError == nil)
        }

        // MARK: Suggerimenti

        @Test func suggestionsComeInTheAppLanguageWithoutAPlant() async throws {
            let backend = try await signedIn()
            server.route("GET /v1/chat/suggestions", .json(#"{"suggestions":["Reset the drive fault on line 2"," ",""]}"#))

            let suggestions = await backend.suggestions()

            #expect(suggestions == ["Reset the drive fault on line 2"])
            let call = try #require(server.calls("GET /v1/chat/suggestions").first)
            #expect(call.query == nil, "la lingua viaggia in Accept-Language, lo stabilimento non serve")
            #expect(call.header("accept-language") == backend.api.context.locale)
            #expect(call.header("company-id") == "c1")
        }

        @Test func anEmptySuggestionListIsNotAnError() async throws {
            let backend = try await signedIn()
            server.route("GET /v1/chat/suggestions", .json(#"{"suggestions":[]}"#))

            #expect(await backend.suggestions().isEmpty)
            #expect(backend.isAvailable(.suggestions))
            #expect(backend.lastError == nil)
        }

        // MARK: Contesto

        @Test func contextUsageReadsPercentagesAndCompactReturnsTheUsageAfter() async throws {
            let backend = try await signedIn()
            let api = AriaChatAPI(api: backend.api)
            server.route("GET /v1/chat/sessions/S1/context", .json(usageJSON))
            server.route("POST /v1/chat/sessions/S1/context/compact",
                         .json(usageJSON.replacingOccurrences(of: #""percentUsed":30.6"#, with: #""percentUsed":12.0"#)
                                        .replacingOccurrences(of: #""canCompact":true"#, with: #""canCompact":false"#)))

            let usage = try #require(try await api.contextUsage(sessionId: "S1"))
            let after = try #require(try await api.compactContext(sessionId: "S1"))

            #expect(usage.percentUsed == 30.6 && usage.autoCompactAt == 80 && usage.canCompact)
            #expect(after.percentUsed == 12 && !after.canCompact)
            #expect(server.calls("POST /v1/chat/sessions/S1/context/compact").first?.body.isEmpty == true, "nessun body")
        }

        @Test func aSessionThatIsNotTheOperatorsHasNoMeter() async throws {
            let backend = try await signedIn()
            server.route("GET /v1/chat/sessions/S9/context", plain(404, "No chat session 'S9'"))

            #expect(try await AriaChatAPI(api: backend.api).contextUsage(sessionId: "S9") == nil)
        }

        @Test func theMeterLoadsOnlyForAChatWithMessagesAndCompactsWhenAllowed() async throws {
            let backend = try await signedIn()
            server.route("GET /v1/chat/sessions/S1/context", .json(usageJSON))
            server.route("POST /v1/chat/sessions/S1/context/compact", .json(usageJSON))
            let empty = await chat(backend)
            await empty.loadContextUsage()
            #expect(server.calls("GET /v1/chat/sessions/S1/context").isEmpty, "una chat vuota non ha niente da contare")

            let chat = await chat(backend, messages: #"[{"id":"m1","role":"user","text":"Ciao"}]"#)
            await chat.loadContextUsage()
            #expect(chat.contextUsage?.percentUsed == 30.6)
            await chat.compactContext()
            #expect(server.calls("POST /v1/chat/sessions/S1/context/compact").count == 1)
            #expect(chat.notice != nil)
        }

        // MARK: Fatti imparati

        @Test func acceptSendsTheRewordingAndRejectSendsNoContent() async throws {
            let backend = try await signedIn()
            let api = AriaChatAPI(api: backend.api)
            let path = "POST \(company)/memory-facts/f1/confirm"
            server.route(path, .json(#"{"id":"f1","content":"The drive trips above 24 V","status":"pending"}"#))

            let fact = try await api.confirmMemory(companyId: "c1", factId: "f1", accept: true, content: "  The drive trips above 24 V ")
            try await api.confirmMemory(companyId: "c1", factId: "f1", accept: false, content: "ignored")
            try await api.confirmMemory(companyId: "c1", factId: "f1", accept: true, content: "   ")

            let bodies = server.calls(path).compactMap(\.json)
            #expect(fact.status == "pending")
            #expect(bodies[0]["decision"] as? String == "accept" && bodies[0]["content"] as? String == "The drive trips above 24 V")
            #expect(bodies[1]["decision"] as? String == "reject" && bodies[1]["content"] == nil)
            #expect(bodies[2]["content"] == nil, "un testo vuoto non è una riformulazione")
        }

        @Test func acceptingACardSaysSentForReviewNotSaved() async throws {
            let backend = try await signedIn()
            let chat = await chat(backend)
            server.route("POST /v1/responses", sse([
                ("response.output_text.delta", #"{"delta":"Ok"}"#),
                ("aria.memory_proposal", #"{"fact_id":"f1","content":"Pump 3 seal is EPDM","reason":"r"}"#),
                ("response.completed", #"{"status":"completed"}"#),
            ]))
            server.route("POST \(company)/memory-facts/f1/confirm", .json(#"{"id":"f1","content":"x","status":"pending"}"#))
            chat.send("a")
            #expect(await TestEnv.waitUntil { !chat.isStreaming && chat.messages.last?.memoryProposals.count == 1 })
            let message = try #require(chat.messages.last)
            let proposal = try #require(message.memoryProposals.first)

            chat.confirmMemory(proposal, in: message.id, accept: true)

            #expect(await TestEnv.waitUntil { chat.notice != nil })
            #expect(chat.notice == String(localized: "Sent for review — an admin will check it."))
            #expect(chat.messages.last?.memoryProposals.isEmpty == true)
        }

        /// "Notify" sotto il Real-time Learning usa la stessa rotta: su un backend senza la rotta per l'operatore
        /// la funzione sparisce (resta "Done"), non compare un errore che non si può risolvere riprovando.
        @Test func notifyOnABackendWithoutTheRouteHidesItInsteadOfFailing() async throws {
            let backend = try await signedIn()
            let chat = await chat(backend)
            server.route("POST \(company)/memory-facts/f1/confirm", forbidden)

            #expect(await chat.notifyLearning(["f1"]) == false)

            #expect(chat.lastError == nil)
            #expect(!chat.canConfirmMemory)
        }

        @Test func notifyShowsWhyTheServerRefusedIt() async throws {
            let backend = try await signedIn()
            let chat = await chat(backend)
            server.route("POST \(company)/memory-facts/f1/confirm", plain(409, "Memory fact is not open for this decision (status=approved)"))

            #expect(await chat.notifyLearning(["f1"]) == false)

            #expect(chat.lastError == "Memory fact is not open for this decision (status=approved)")
            #expect(chat.canConfirmMemory)
        }

        @Test func aFactThatIsGoneDropsTheCardAndAConflictShowsTheServerMessage() async throws {
            let backend = try await signedIn()
            let chat = await chat(backend)
            server.route("POST /v1/responses", sse([
                ("aria.memory_proposal", #"{"fact_id":"gone","content":"a"}"#),
                ("aria.memory_proposal", #"{"fact_id":"taken","content":"b"}"#),
                ("response.completed", #"{"status":"completed"}"#),
            ]))
            server.route("POST \(company)/memory-facts/gone/confirm", plain(404, "Memory fact not found"))
            server.route("POST \(company)/memory-facts/taken/confirm", plain(409, "Already decided"))
            chat.send("a")
            #expect(await TestEnv.waitUntil { !chat.isStreaming && chat.messages.last?.memoryProposals.count == 2 })
            let message = try #require(chat.messages.last)

            chat.confirmMemory(message.memoryProposals[0], in: message.id, accept: true)
            #expect(await TestEnv.waitUntil { !server.calls("POST \(company)/memory-facts/gone/confirm").isEmpty })
            chat.confirmMemory(message.memoryProposals[1], in: message.id, accept: false)
            #expect(await TestEnv.waitUntil { chat.lastError != nil })

            #expect(chat.lastError == "Already decided")
            #expect(chat.messages.last?.memoryProposals.isEmpty == true, "nessuna delle due card torna")
        }

        @Test func translationsGoInBatchesOfSixtyUnderTheBodyLimit() {
            let items = (1...61).map { AriaFactTranslationRequest.Item(id: "f\($0)", text: "Fact \($0)") }
            let long = AriaFactTranslationRequest.Item(id: "big", text: String(repeating: "x", count: 1990))

            let batches = AriaChatAPI.translationBatches(items, locale: "it", maxBytes: 8_000)
            let tight = AriaChatAPI.translationBatches(items + [long], locale: "it", maxBytes: 1_500)

            #expect(batches.map(\.count) == [60, 1])
            #expect(tight.flatMap { $0 }.count == 61, "un testo che da solo supera il limite resta in originale")
            for batch in tight {
                let size = (try? JSONEncoder().encode(AriaFactTranslationRequest(locale: "it", items: batch)).count) ?? .max
                #expect(size <= 1_500)
            }
        }

        @Test func translatedFactsReplaceTheOriginalAndAMissingKeyKeepsIt() async throws {
            let backend = try await signedIn()
            let chat = await chat(backend)
            server.route("POST \(company)/memory-facts/translations", .json(#"{"translations":{"f1":"L'azionamento va in blocco"}}"#))

            chat.requestTranslations([("f1", "The drive trips"), ("f2", "Line 2 stops")])
            chat.requestTranslations([("f1", "The drive trips")])

            #expect(await TestEnv.waitUntil { chat.translated("The drive trips", id: "f1") != "The drive trips" })
            #expect(chat.translated("The drive trips", id: "f1") == "L'azionamento va in blocco")
            #expect(chat.translated("Line 2 stops", id: "f2") == "Line 2 stops")
            let calls = server.calls("POST \(company)/memory-facts/translations")
            #expect(calls.count == 1, "le card si traducono insieme, una volta")
            let body = try #require(calls.first?.json)
            #expect(body["locale"] as? String == backend.api.context.locale)
            #expect((body["items"] as? [[String: Any]])?.count == 2)
        }

        // MARK: Closeout e report

        @Test func anOperatorNeverShiftsOthersOrAssignsAColleague() async throws {
            let backend = try await signedIn()
            let me = try #require(backend.mobileAccount?.id)
            let chat = await chat(backend)
            let path = "POST \(company)/sessions/S1/closeout"
            server.route(path, .json(#"{"confirmed":true,"workOrderId":"wo1","workOrderTitle":"Fix","workOrderStatus":"open"}"#))
            var request = AriaCloseoutRequest(workOrder: true, report: true)
            request.confirm = true
            request.conflictChoice = "shift"
            request.assigneeId = "colleague"

            _ = try await chat.closeout(request)
            request.assigneeId = me
            _ = try await chat.closeout(request)

            let bodies = server.calls(path).compactMap(\.json)
            #expect(bodies.allSatisfy { $0["conflictChoice"] == nil })
            #expect(bodies[0]["assigneeId"] == nil, "vuoto = la preselezione della proposta")
            #expect(bodies[1]["assigneeId"] as? String == me)
            #expect(bodies[0]["workOrder"] as? Bool == true && bodies[0]["report"] as? Bool == true)
        }

        @Test func aMaintainXFieldThatDoesNotExistComesBackWithTheValidValues() async throws {
            let backend = try await signedIn()
            let chat = await chat(backend)
            server.route("POST \(company)/sessions/S1/closeout", .json(
                #"{"error":{"type":"http_error","message":"x","code":422},"detail":{"code":"unresolved_category","field":"category","value":"Pumps","valid":["Electrical","Mechanical"],"message":"'Pumps' is not a MaintainX category"}}"#,
                status: 422))

            do {
                _ = try await chat.closeout(AriaCloseoutRequest(confirm: true, category: "Pumps"))
                Issue.record("doveva fallire")
            } catch AriaError.invalidChoice(let field, let valid, let message) {
                #expect(field == "category")
                #expect(valid == ["Electrical", "Mechanical"])
                #expect(message.contains("Pumps"))
            }
            #expect(chat.canCloseOut, "un campo sbagliato non toglie il closeout")
        }

        @Test func aChatWithNothingToCloseOutLosesTheAction() async throws {
            let backend = try await signedIn()
            let chat = await chat(backend)
            #expect(chat.canCloseOut, "l'operatore ora può chiudere l'intervento")
            server.route("POST \(company)/sessions/S1/closeout", plain(404, "No session record for 'S1'"))

            await #expect(throws: AriaError.self) { _ = try await chat.closeout(AriaCloseoutRequest()) }

            #expect(!chat.canCloseOut)
            #expect(backend.isAvailable(.closeout), "solo per questa chat")
            chat.newConversation()
            #expect(chat.canCloseOut)
        }

        @Test func theReportIsArchivedOnTheChatWithoutAWorkOrder() async throws {
            let backend = try await signedIn()
            let chat = await chat(backend)
            server.route("POST \(company)/sessions/S1/report", .json(
                #"{"attachmentId":"a1","filename":"report.docx","entityType":"chat_session","entityId":"S1","sizeBytes":48211,"downloadUrl":"https://s3.test/r"}"#,
                status: 201))

            let archive = try await chat.archiveReport()

            #expect(archive.entityType == "chat_session" && archive.sizeBytes == 48211)
            #expect(server.calls("POST \(company)/sessions/S1/report").first?.json?.isEmpty == true, "niente workOrderId")
        }

        @Test func theWordReportDownloadsInTheAppLanguage() async throws {
            let backend = try await signedIn()
            let chat = await chat(backend, messages: #"[{"id":"m1","role":"user","text":"Ciao"}]"#)
            let bytes = Data("PK\u{3}\u{4}docx".utf8)
            server.route("GET \(company)/sessions/S1/report.docx", Reply(
                status: 200,
                headers: ["Content-Type": AriaChatAPI.docxType,
                          "Content-Disposition": #"attachment; filename="Intervento pompa 3.docx""#],
                body: bytes))

            #expect(chat.canDownloadReport)
            let file = try await chat.reportDocument()
            defer { try? FileManager.default.removeItem(at: file.url.deletingLastPathComponent()) }

            #expect(file.filename == "Intervento pompa 3.docx")
            #expect(try Data(contentsOf: file.url) == bytes)
            let call = try #require(server.calls("GET \(company)/sessions/S1/report.docx").first)
            #expect(call.query == "locale=\(backend.api.context.locale)")
            #expect(call.header("accept") == AriaChatAPI.docxType)
        }

        @Test(arguments: [
            (#"attachment; filename="a.docx""#, "a.docx"),
            (#"attachment; filename="x.docx"; filename*=UTF-8''Rapporto%20%C3%A8.docx"#, "Rapporto è.docx"),
            (#"attachment; filename="../../etc/passwd""#, "passwd"),
            ("inline", nil),
        ] as [(String, String?)])
        func theFileNameComesFromContentDisposition(header: String, expected: String?) {
            #expect(AriaChatAPI.filename(fromContentDisposition: header) == expected)
        }

        // MARK: Dettatura

        @Test func capabilitiesNeedNoCompanyAndTheVocabularyBecomesHints() async throws {
            let backend = try await signedIn()
            server.route("GET /v1/audio/transcriptions/capabilities",
                         .json(#"{"available":true,"provider":"p","model":"m","language":null,"maxAudioMb":25,"polish":true}"#))
            server.route("GET /v1/audio/vocabulary", .json(
                #"{"terms":[{"token":"E-104","kind":"alarm","label":"Drive overtemperature"},{"token":"P-201","kind":"asset","label":null},{"token":"E-104","kind":"alarm"}]}"#))

            let support = await backend.dictation()
            _ = await backend.dictation()

            #expect(support.transcribes && support.polishes)
            #expect(support.maxAudioBytes == 25_000_000)
            #expect(support.vocabulary == ["E-104", "P-201"])
            let call = try #require(server.calls("GET /v1/audio/transcriptions/capabilities").first)
            #expect(call.header("company-id") == nil)
            #expect(call.header("authorization") != nil)
            #expect(server.calls("GET /v1/audio/transcriptions/capabilities").count == 1, "una volta per sessione")
        }

        @Test func withoutCapabilitiesTheServerIsNotUsedAndIsAskedAgainLater() async throws {
            let backend = try await signedIn()
            server.route("GET /v1/audio/transcriptions/capabilities", forbidden)

            #expect(await backend.dictation() == AriaDictationSupport.none)
            _ = await backend.dictation()

            #expect(server.calls("GET /v1/audio/transcriptions/capabilities").count == 2)
        }

        @Test func dictationSwitchedOffByTheServerIsNotAskedAgainButTheVocabularyStays() async throws {
            let backend = try await signedIn()
            server.route("GET /v1/audio/transcriptions/capabilities",
                         .json(#"{"available":false,"provider":"","model":"","maxAudioMb":null,"polish":false}"#))
            server.route("GET /v1/audio/vocabulary", .json(#"{"terms":[{"token":"E-104","kind":"alarm"}]}"#))

            let support = await backend.dictation()
            _ = await backend.dictation()

            #expect(!support.transcribes && !support.polishes)
            #expect(support.vocabulary == ["E-104"], "i termini aiutano anche il riconoscitore sul telefono")
            #expect(server.calls("GET /v1/audio/transcriptions/capabilities").count == 1, "la risposta del server vale")
        }

        @Test func makeRoomOnASessionThatIsGoneSaysNothingAndDropsTheMeter() async throws {
            let backend = try await signedIn()
            server.route("GET /v1/chat/sessions/S1/context", .json(usageJSON))
            server.route("POST /v1/chat/sessions/S1/context/compact", plain(404, "No chat session 'S1'"))
            let chat = await chat(backend, messages: #"[{"id":"m1","role":"user","text":"Ciao"}]"#)
            await chat.loadContextUsage()

            await chat.compactContext()

            #expect(chat.contextUsage == nil)
            #expect(chat.notice == nil, "niente è stato compattato")
            #expect(!chat.isCompacting)
        }

        @Test func anOperatorRecordingNowGoesToTheServer() async throws {
            let backend = try await signedIn()
            server.route("POST /v1/audio/transcriptions", .json(#"{"text":"Replace the breaker on line two","language":"en","durationS":4.2,"model":"m","provider":"p"}"#))

            let text = try await backend.api.transcribe(audio: Data(repeating: 1, count: 64), filename: "d.m4a",
                                                        mimeType: "audio/mp4", language: "en", prompt: nil)

            #expect(text == "Replace the breaker on line two")
            let call = try #require(server.calls("POST /v1/audio/transcriptions").first)
            #expect(call.header("content-type")?.hasPrefix("multipart/form-data; boundary=") == true)
            #expect(call.bodyText.contains(#"name="file"; filename="d.m4a""#))
            #expect(call.bodyText.contains(#"name="language""#))
        }

        @Test func aTranscriptionServiceThatIsNotConfiguredLeavesThePhoneText() async throws {
            let backend = try await signedIn()
            server.route("POST /v1/audio/transcriptions", plain(503, "Transcription not configured"))

            let text = try await backend.api.transcribe(audio: Data([1]), filename: "d.m4a", mimeType: "audio/mp4",
                                                        language: nil, prompt: nil)
            #expect(text == nil)
        }

        @Test func polishSendsTheTextAndLanguageAndKeepsTheOriginalWhenEmpty() async throws {
            let backend = try await signedIn()
            let audio = AriaAudioAPI(api: backend.api)
            server.route("POST /v1/audio/polish", .json(#"{"text":"Replace the breaker on line two.","changed":true}"#),
                         .json(#"{"text":"  ","changed":false}"#))

            #expect(try await audio.polish("replace the breaker on line two", language: "en") == "Replace the breaker on line two.")
            #expect(try await audio.polish("ciao", language: nil) == "ciao")
            let body = try #require(server.calls("POST /v1/audio/polish").first?.json)
            #expect(body["text"] as? String == "replace the breaker on line two" && body["language"] as? String == "en")
        }

        @Test(arguments: [(nil, 120_000), (25_000_000, 120_000), (1_000_000, 37_500)] as [(Int?, Int)])
        func recordingStopsBeforeTheServerLimit(maxBytes: Int?, expectedMilliseconds: Int) {
            #expect(AriaDictation.recordingLimit(maxAudioBytes: maxBytes) == .milliseconds(expectedMilliseconds))
        }

        // MARK: Push

        @Test func thePushTokenIsNotSentToAGuessedRoute() {
            AriaPushNotifications.shared.didRegister(Data([0xAB, 0x01]))

            #expect(AriaPushNotifications.shared.deviceToken == "ab01")
            #expect(server.calls.isEmpty, "nessuna rotta per i token: niente registrazione")
        }
    }
}
