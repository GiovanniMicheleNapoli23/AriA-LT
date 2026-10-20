//
//  LiveBackendTests.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 15/10/26.
//
//  Il backend vero (app.ariaplt.com per l'accesso, api.ariaplt.com per i dati), non la rete finta.
//  Non girano mai da soli: servono variabili d'ambiente (nello schema, "Test" › Environment Variables,
//  oppure `TEST_RUNNER_NOME=… xcodebuild test`).
//
//      ARIA_LIVE=1                  prove pubbliche: nessuna credenziale, nessun dato toccato
//      ARIA_LIVE_SESSION=<token>    sessione di un operatore (il `set-auth-token` di POST /api/auth/mobile/verify):
//                                   abilita le letture. Non si manda mai /api/auth/sign-out: la sessione resta buona.
//      ARIA_LIVE_WRITE=1            abilita le scritture: disponibilità, risultati dei passi, foto
//      ARIA_LIVE_WORK_ORDER=<id>    ordine su cui scrivere. Deve essere aperto e avere un passo SENZA risultato:
//                                   i risultati già inseriti non si toccano. Il primo risultato porta l'ordine
//                                   in `in_progress` e il DELETE del passo non lo riporta indietro.
//      ARIA_LIVE_API / ARIA_LIVE_AUTH   host alternativi (staging)
//
//  Mai testato: POST …/complete, che chiude l'ordine e non si annulla; e /api/auth/sign-out.
//

import Foundation
import Testing
import UIKit
@testable import AriaLite

private nonisolated enum LiveEnv {
    static func value(_ key: String) -> String? {
        let raw = ProcessInfo.processInfo.environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines)
        return raw?.isEmpty == false ? raw : nil
    }

    static var session: String? { value("ARIA_LIVE_SESSION") }
    static var publicChecks: Bool { value("ARIA_LIVE") == "1" || session != nil }
    static var readChecks: Bool { session != nil }
    static var writeChecks: Bool { session != nil && value("ARIA_LIVE_WRITE") == "1" }
    static var workOrderChecks: Bool { writeChecks && value("ARIA_LIVE_WORK_ORDER") != nil }
    static var workOrderId: String? { value("ARIA_LIVE_WORK_ORDER") }

    static var config: AriaConfig {
        AriaConfig(apiBaseURL: value("ARIA_LIVE_API").flatMap(URL.init(string:)) ?? AriaConfig.productionAPI,
                   authBaseURL: value("ARIA_LIVE_AUTH").flatMap(URL.init(string:)) ?? AriaConfig.productionSignIn)
    }
}

private let sessionAccount = "aria.mobile_session"

/// Non segue i redirect: Apple scarica l'association file senza seguirli.
private final class NoRedirect: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

private struct LiveReply {
    let status: Int
    let data: Data
    let http: HTTPURLResponse

    var json: Any? { try? JSONSerialization.jsonObject(with: data) }
}

private func isHTTP(_ error: any Error, _ status: Int) -> Bool {
    if case AriaError.http(let found, _) = error { found == status } else { false }
}

/// 404 dal backend: o il codice dei passi, o l'errore HTTP.
private func isNotFound(_ error: any Error) -> Bool {
    if isHTTP(error, 404) { return true }
    if case AriaError.workOrder(let code, _) = error { return code == .stepNotFound }
    return false
}

/// GET /v1/me: il profilo operatore è in `operatorProfile`.
private func operatorProfile(_ client: AriaAPIClient) async throws -> AriaMobileProfile {
    let me = try await client.data("GET", "v1/me")
    let raw = try #require(AriaOperatorProfileJSON(inMe: me), "l'utente non è un operatore")
    return try JSONDecoder().decode(AriaMobileProfile.self, from: raw)
}

extension BackendTests {
    // MARK: - Configurazione di produzione (senza rete)

    @Suite("Production config")
    struct ProductionConfig {
        init() { TestEnv.reset() }

        @Test func hostsAreTheOfficialOnes() {
            #expect(AriaConfig.production.apiBaseURL == URL(string: "https://api.ariaplt.com"))
            #expect(AriaConfig.production.authBaseURL == URL(string: "https://app.ariaplt.com"))
            #expect(AriaConfig.production.webBaseURL == URL(string: "https://app.ariaplt.com"))
        }

        @Test func noTunnelIsLeftInTheSources() {
            for url in [AriaConfig.productionAPI, AriaConfig.productionSignIn, AriaConfig.productionWeb] {
                #expect(url.scheme == "https")
                #expect(url.host()?.contains("ngrok") == false)
            }
        }

        @Test func theEmailLinkOfTheOfficialHostIsRecognised() async {
            let auth = AriaAuth(config: .production)
            let link = auth.signInLink(from: URL(string: "https://app.ariaplt.com/m/sign-in#token=abc123")!)
            #expect(link == AriaSignInLink(token: "abc123"))
            #expect(auth.signInLink(from: URL(string: "https://benito-fumigatory-christinia.ngrok-free.dev/m/sign-in#token=abc")!) == nil)
            #expect(auth.signInLink(from: URL(string: "https://api.ariaplt.com/m/sign-in#token=abc")!) == nil,
                    "il link porta l'host di accesso, non quello dei dati")
        }

        #if DEBUG
        @Test func aSavedTunnelFromOlderVersionsIsDroppedNotUsed() {
            UserDefaults.standard.set("https://old.ngrok-free.dev", forKey: "aria.auth_base_url")
            UserDefaults.standard.set("https://old-api.ngrok-free.dev", forKey: "aria.api_base_url")

            let config = AriaConfig.current

            #expect(config.authBaseURL == AriaConfig.productionSignIn)
            #expect(config.apiBaseURL == AriaConfig.productionAPI)
            #expect(UserDefaults.standard.string(forKey: "aria.auth_base_url") == nil)
            #expect(UserDefaults.standard.string(forKey: "aria.api_base_url") == nil)
        }

        @Test func serversChosenInDebugAreHonoured() {
            AriaConfig.saveServers(api: URL(string: "https://api.staging.test"), auth: URL(string: "https://app.staging.test"))
            #expect(AriaConfig.current.apiBaseURL.host() == "api.staging.test")
            #expect(AriaConfig.current.authBaseURL.host() == "app.staging.test")
            AriaConfig.saveServers(api: nil, auth: nil)
            #expect(AriaConfig.current.apiBaseURL == AriaConfig.productionAPI)
        }
        #endif
    }

    // MARK: - Prove pubbliche (ARIA_LIVE=1)

    @Suite("Live backend · public")
    struct LivePublic {
        init() {
            AriaHTTP.extraProtocolClasses = []
            AriaKeychain.delete(sessionAccount)
        }

        private func call(_ method: String, _ url: URL, headers: [String: String] = [:],
                          body: Data? = nil, followRedirects: Bool = true) async throws -> LiveReply {
            var req = URLRequest(url: url, timeoutInterval: 30)
            req.httpMethod = method
            req.httpBody = body
            req.setValue(AriaConfig.production.userAgent, forHTTPHeaderField: "User-Agent")
            for (name, value) in headers { req.setValue(value, forHTTPHeaderField: name) }
            let configuration = URLSessionConfiguration.ephemeral
            configuration.httpShouldSetCookies = false
            configuration.httpCookieStorage = nil
            let session = URLSession(configuration: configuration, delegate: followRedirects ? nil : NoRedirect(),
                                     delegateQueue: nil)
            let (data, response) = try await session.data(for: req)
            let http = try #require(response as? HTTPURLResponse)
            return LiveReply(status: http.statusCode, data: data, http: http)
        }

        // MARK: Accesso

        @Test(.enabled(if: LiveEnv.publicChecks, "ARIA_LIVE=1"))
        func requestLinkAnswers202EvenForAnAddressThatIsNotAnOperator() async throws {
            let auth = AriaAuth(config: LiveEnv.config)
            // Non spedisce nulla: l'indirizzo non è di un operatore. Non deve poter dire chi lo è.
            try await auth.requestLink(email: "no-operator-\(UUID().uuidString.lowercased())@example.com")
        }

        @Test(.enabled(if: LiveEnv.publicChecks, "ARIA_LIVE=1"))
        func requestLinkRawIs202WithAnEmptyObject() async throws {
            let body = try JSONEncoder().encode(["email": "no-operator-\(UUID().uuidString.lowercased())@example.com"])
            let reply = try await call("POST", LiveEnv.config.authBaseURL.appending(path: "api/auth/mobile/request-link"),
                                       headers: ["Content-Type": "application/json"], body: body)
            #expect(reply.status == 202)
        }

        @Test(.enabled(if: LiveEnv.publicChecks, "ARIA_LIVE=1"))
        func verifyRefusesATokenThatDoesNotExist() async throws {
            let auth = AriaAuth(config: LiveEnv.config)
            await #expect {
                _ = try await auth.completeSignIn(with: AriaSignInLink(token: "not-a-real-token-\(UUID().uuidString)"))
            } throws: { error in
                if case AriaError.linkExpired = error { true } else { false }
            }
            #expect(!auth.hasStoredSession, "un link rifiutato non lascia nessuna sessione")
        }

        @Test(.enabled(if: LiveEnv.publicChecks, "ARIA_LIVE=1"))
        func sessionTokenEndpointRefusesWithoutAndWithABogusSession() async throws {
            let url = LiveEnv.config.authBaseURL.appending(path: "api/aria/token")
            let none = try await call("GET", url)
            let bogus = try await call("GET", url, headers: ["Authorization": "Bearer not-a-session"])
            #expect(none.status == 401)
            #expect(bogus.status == 401)
        }

        // MARK: Dati

        @Test(.enabled(if: LiveEnv.publicChecks, "ARIA_LIVE=1"),
              arguments: ["v1/companies", "v1/me", "v1/work-orders"])
        func dataRoutesRefuseARequestWithoutAJWT(path: String) async throws {
            let reply = try await call("GET", LiveEnv.config.apiBaseURL.appending(path: path))
            #expect(reply.status == 401)
        }

        @Test(.enabled(if: LiveEnv.publicChecks, "ARIA_LIVE=1"),
              arguments: ["v1/companies", "v1/me", "v1/work-orders"])
        func dataRoutesRefuseAJWTTheyDidNotSign(path: String) async throws {
            let reply = try await call("GET", LiveEnv.config.apiBaseURL.appending(path: path),
                                       headers: ["Authorization": "Bearer \(TestEnv.jwt())", "Company-Id": "c1"])
            #expect(reply.status == 401)
        }

        // MARK: Universal Link

        @Test(.enabled(if: LiveEnv.publicChecks, "ARIA_LIVE=1"))
        func associationFileClaimsTheSignInPathForThisApp() async throws {
            let url = LiveEnv.config.authBaseURL.appending(path: ".well-known/apple-app-site-association")
            let reply = try await call("GET", url, followRedirects: false)

            #expect(reply.status == 200, "Apple non segue i redirect: deve rispondere 200 direttamente")
            let applinks = ((reply.json as? [String: Any])?["applinks"] as? [String: Any])
            let details = try #require(applinks?["details"] as? [[String: Any]], "manca applinks.details")
            let appID = "4TP9VJ2S7B.\(Bundle.main.bundleIdentifier ?? "com.giovanniMichele.AriaLite")"
            let claims = details.contains { entry in
                let ids = (entry["appIDs"] as? [String]) ?? []
                let components = (entry["components"] as? [[String: Any]]) ?? []
                return ids.contains(appID) && components.contains { ($0["/"] as? String) == "/m/sign-in" }
            }
            #expect(claims, "aria-web non elenca \(appID) per /m/sign-in: va aggiunto a MOBILE_IOS_APP_IDS")
        }

        @Test(.enabled(if: LiveEnv.publicChecks, "ARIA_LIVE=1"))
        func signInPageIsReachableWithoutASession() async throws {
            let url = LiveEnv.config.authBaseURL.appending(path: "m/sign-in")
            let reply = try await call("GET", url, followRedirects: false)
            #expect(reply.status == 200, "/m/sign-in non deve passare dal login: Apple scarica senza cookie")
        }
    }

    // MARK: - Letture con una sessione vera (ARIA_LIVE_SESSION)

    @Suite("Live backend · operator")
    struct LiveOperator {
        init() {
            AriaHTTP.extraProtocolClasses = []
            AriaKeychain.delete(sessionAccount)
        }

        private struct Connection {
            let auth: AriaAuth
            let client: AriaAPIClient
            let companyId: String
        }

        /// La sessione nel Keychain come l'app la salva, poi tutto passa dal codice vero: JWT, Company-Id, chiamate.
        private func connect(_ body: (Connection) async throws -> Void) async throws {
            let session = try #require(LiveEnv.session)
            AriaKeychain.set(session, for: sessionAccount)
            defer { AriaKeychain.delete(sessionAccount) }

            let config = LiveEnv.config
            let auth = AriaAuth(config: config)
            let context = AriaContext()
            await context.setCompany(nil)
            await context.setPlant(nil)
            let client = AriaAPIClient(config: config, auth: auth, context: context)
            let companies: [AriaCompany] = try await client.get("v1/companies", companyScoped: false)
            let company = try #require(companies.first, "l'operatore non ha nessuna azienda")
            await context.setCompany(company.id)
            try await body(Connection(auth: auth, client: client, companyId: company.id))
        }

        private func openOrders(_ client: AriaAPIClient, limit: Int = 50) async throws -> [AriaWorkOrder] {
            try await client.workOrders(.open, pageSize: limit, maxPages: 1).map { try $0.decoded(as: AriaWorkOrder.self) }
        }

        // MARK: Sessione e azienda

        @Test(.enabled(if: LiveEnv.readChecks, "ARIA_LIVE_SESSION"))
        func theSessionMintsAJWTValidForAboutFifteenMinutes() async throws {
            try await connect { live in
                let jwt = try await live.auth.validAccessToken()
                let parts = jwt.split(separator: ".")
                #expect(parts.count == 3)
                var base64 = parts[1].replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
                base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
                let payload = try #require(Data(base64Encoded: base64))
                let object = try #require(try JSONSerialization.jsonObject(with: payload) as? [String: Any])
                let exp = try #require((object["exp"] as? NSNumber)?.doubleValue)
                let remaining = exp - Date.now.timeIntervalSince1970
                #expect(remaining > 0 && remaining <= 16 * 60, "scade fra \(Int(remaining))s")
            }
        }

        @Test(.enabled(if: LiveEnv.readChecks, "ARIA_LIVE_SESSION"))
        func anOperatorHasExactlyOneCompany() async throws {
            let session = try #require(LiveEnv.session)
            AriaKeychain.set(session, for: sessionAccount)
            defer { AriaKeychain.delete(sessionAccount) }
            let auth = AriaAuth(config: LiveEnv.config)
            let client = AriaAPIClient(config: LiveEnv.config, auth: auth, context: AriaContext())

            let companies: [AriaCompany] = try await client.get("v1/companies", companyScoped: false)

            #expect(companies.count == 1)
            #expect(companies.first?.id.isEmpty == false)
        }

        @Test(.enabled(if: LiveEnv.readChecks, "ARIA_LIVE_SESSION"))
        func theProfileDecodes() async throws {
            try await connect { live in
                let profile = try await operatorProfile(live.client)
                #expect(!profile.id.isEmpty)
                #expect(profile.email.contains("@"))
            }
        }

        @Test(.enabled(if: LiveEnv.readChecks, "ARIA_LIVE_SESSION"))
        func aCallWithoutCompanyIdIsA400() async throws {
            try await connect { live in
                let jwt = try await live.auth.validAccessToken()
                var req = URLRequest(url: LiveEnv.config.apiBaseURL.appending(path: "v1/me"))
                req.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
                let (_, response) = try await AriaHTTP.cookielessSession().data(for: req)
                #expect((response as? HTTPURLResponse)?.statusCode == 400)
            }
        }

        // MARK: Ordini

        @Test(.enabled(if: LiveEnv.readChecks, "ARIA_LIVE_SESSION"))
        func openClosedAndAllListsDecodeAndAgreeOnStatus() async throws {
            try await connect { live in
                func list(_ filter: AriaWorkOrderFilter, limit: Int) async throws -> [AriaWorkOrder] {
                    try await live.client.workOrders(filter, pageSize: limit, maxPages: 1)
                        .map { try $0.decoded(as: AriaWorkOrder.self) }
                }
                let open = try await list(.open, limit: 200)
                let closed = try await list(.closed, limit: 200)
                let all = try await list(.all, limit: 200)

                #expect(open.allSatisfy { !$0.isClosed }, "open elenca un ordine chiuso")
                #expect(closed.allSatisfy { $0.isClosed }, "closed elenca un ordine aperto")
                if all.count < 200 {
                    #expect(Set(open.map(\.id)).union(closed.map(\.id)).isSubset(of: Set(all.map(\.id))))
                    #expect(all.count == open.count + closed.count)
                }
                #expect(Set(open.map(\.id)).count == open.count, "id ripetuti")
            }
        }

        @Test(.enabled(if: LiveEnv.readChecks, "ARIA_LIVE_SESSION"))
        func theLimitIsRespected() async throws {
            try await connect { live in
                let one = try await live.client.workOrders(.all, pageSize: 1, maxPages: 1)
                #expect(one.count <= 1)
            }
        }

        @Test(.enabled(if: LiveEnv.readChecks, "ARIA_LIVE_SESSION"))
        func theDetailMatchesTheListAndHasACoherentProcedure() async throws {
            try await connect { live in
                guard let first = try await openOrders(live.client, limit: 1).first else {
                    print("LIVE: nessun ordine aperto, il dettaglio non si può provare")
                    return
                }
                let detail = try await live.client.workOrder(id: first.id)

                #expect(detail.id == first.id)
                #expect(detail.title == first.title)
                #expect(detail.status == first.status)
                guard let procedure = detail.procedure else { return }
                let steps = procedure.steps
                #expect(Set(steps.map(\.id)).count == steps.count, "id dei passi ripetuti")
                #expect(steps.map(\.number) == steps.map(\.number).sorted(), "passi non in ordine")
                #expect(steps.allSatisfy { $0.number > 0 })
                if let progress = procedure.progress {
                    #expect(progress.total == steps.count)
                    #expect(progress.done == steps.filter { $0.report?.isDone == true }.count)
                    #expect(progress.notDone == steps.filter { $0.report != nil && $0.report?.isDone == false }.count)
                }
            }
        }

        @Test(.enabled(if: LiveEnv.readChecks, "ARIA_LIVE_SESSION"))
        func anOrderThatIsNotTheOperatorsIs404() async throws {
            try await connect { live in
                await #expect { _ = try await live.client.workOrder(id: UUID().uuidString.lowercased()) } throws: { error in
                    isHTTP(error, 404)
                }
            }
        }

        @Test(.enabled(if: LiveEnv.readChecks, "ARIA_LIVE_SESSION"))
        func writingAStepOfAnOrderThatIsNotTheOperatorsIs404AndChangesNothing() async throws {
            try await connect { live in
                let order = UUID().uuidString.lowercased()
                let step = UUID().uuidString.lowercased()
                await #expect { _ = try await live.client.report(.done(note: nil), step: step, of: order) } throws: { error in
                    isNotFound(error)
                }
                await #expect { try await live.client.clearReport(step: step, of: order) } throws: { error in
                    isNotFound(error)
                }
            }
        }

        @Test(.enabled(if: LiveEnv.readChecks, "ARIA_LIVE_SESSION"))
        func anUnknownStepOfARealOrderIsRefusedWithoutWritingAnything() async throws {
            try await connect { live in
                guard let order = try await openOrders(live.client, limit: 1).first else {
                    print("LIVE: nessun ordine aperto, il passo inesistente non si può provare")
                    return
                }
                await #expect {
                    _ = try await live.client.report(.done(note: nil), step: UUID().uuidString.lowercased(), of: order.id)
                } throws: { error in
                    isNotFound(error)
                }
            }
        }
    }

    // MARK: - Scritture (ARIA_LIVE_WRITE=1)

    @Suite("Live backend · writes")
    struct LiveWrites {
        init() {
            AriaHTTP.extraProtocolClasses = []
            AriaKeychain.delete(sessionAccount)
        }

        private func connect(_ body: (AriaAPIClient) async throws -> Void) async throws {
            let session = try #require(LiveEnv.session)
            AriaKeychain.set(session, for: sessionAccount)
            defer { AriaKeychain.delete(sessionAccount) }

            let auth = AriaAuth(config: LiveEnv.config)
            let context = AriaContext()
            await context.setCompany(nil)
            await context.setPlant(nil)
            let client = AriaAPIClient(config: LiveEnv.config, auth: auth, context: context)
            let companies: [AriaCompany] = try await client.get("v1/companies", companyScoped: false)
            await context.setCompany(try #require(companies.first).id)
            try await body(client)
        }

        /// Un passo senza risultato dell'ordine indicato: gli altri non si toccano.
        private func freeStep(_ client: AriaAPIClient) async throws -> (order: String, step: String)? {
            let orderId = try #require(LiveEnv.workOrderId)
            let order = try await client.workOrder(id: orderId)
            #expect(!order.isClosed, "ARIA_LIVE_WORK_ORDER è chiuso: non si può scrivere")
            guard !order.isClosed, let step = order.procedure?.steps.first(where: { $0.report == nil }) else {
                print("LIVE: l'ordine \(orderId) non ha passi senza risultato")
                return nil
            }
            return (order.id, step.id)
        }

        private func sampleJPEG() -> Data {
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64))
            return renderer.jpegData(withCompressionQuality: 0.8) { context in
                UIColor.systemTeal.setFill()
                context.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
            }
        }

        @Test(.enabled(if: LiveEnv.writeChecks, "ARIA_LIVE_SESSION + ARIA_LIVE_WRITE=1"))
        func availabilityRoundTripsAndIsRestored() async throws {
            try await connect { client in
                let before = try await operatorProfile(client)
                let original = before.availability ?? .available
                let other: AriaAvailability = original == .busy ? .available : .busy

                let changed: AriaMobileProfile = try await client.send(
                    "PUT", "v1/me/availability", body: AriaAvailabilityBody(availability: other))
                #expect(changed.availability == other)
                #expect(changed.availabilityAt != nil)

                let reread = try await operatorProfile(client)
                #expect(reread.availability == other)

                let restored: AriaMobileProfile = try await client.send(
                    "PUT", "v1/me/availability", body: AriaAvailabilityBody(availability: original))
                #expect(restored.availability == original)
            }
        }

        @Test(.enabled(if: LiveEnv.workOrderChecks, "ARIA_LIVE_WRITE=1 + ARIA_LIVE_WORK_ORDER"))
        func aStepResultIsWrittenOverwrittenReadBackAndCleared() async throws {
            try await connect { client in
                guard let target = try await freeStep(client) else { return }
                func clear() async { try? await client.clearReport(step: target.step, of: target.order) }
                func reportOfStep() async throws -> AriaStepReport? {
                    try await client.workOrder(id: target.order).procedure?.steps.first { $0.id == target.step }?.report
                }

                let done = try await client.report(.done(note: "  test live  "), step: target.step, of: target.order)
                #expect(done.status == "done")
                #expect(done.note == "test live", "la nota si manda senza spazi ai bordi")

                // Idempotente: rimandarlo non cambia il risultato.
                let again = try await client.report(.done(note: "test live"), step: target.step, of: target.order)
                #expect(again.status == "done")
                #expect(again.reportedAt != nil)

                let notDone = try await client.report(.notDone(note: "non eseguito: prova live"), step: target.step,
                                                      of: target.order)
                #expect(notDone.status == "not_done")
                #expect(notDone.note == "non eseguito: prova live")

                let stored = try await reportOfStep()
                #expect(stored?.status == "not_done")

                try await client.clearReport(step: target.step, of: target.order)
                let afterClear = try await reportOfStep()
                #expect(afterClear == nil)
                await clear()
            }
        }

        @Test(.enabled(if: LiveEnv.workOrderChecks, "ARIA_LIVE_WRITE=1 + ARIA_LIVE_WORK_ORDER"))
        func aPhotoNeedsAResultFirstThenUploadsAndIsRemoved() async throws {
            try await connect { client in
                guard let target = try await freeStep(client) else { return }
                let jpeg = sampleJPEG()

                // Senza risultato il passo non accetta foto.
                await #expect { _ = try await client.addPhoto(jpeg: jpeg, step: target.step, of: target.order) } throws: { error in
                    if case AriaError.workOrder(.stepNotReported, _) = error { true } else { false }
                }

                _ = try await client.report(.done(note: nil), step: target.step, of: target.order)
                do {
                    let withPhoto = try await client.addPhoto(jpeg: jpeg, step: target.step, of: target.order)
                    let photo = try #require(withPhoto.report?.photos.first)
                    #expect(withPhoto.report?.photos.count == 1)
                    #expect(photo.mimeType == "image/jpeg")
                    #expect(photo.url != nil, "la foto confermata ha un indirizzo da cui scaricarla")

                    let removed = try await client.removePhoto(photo.id, step: target.step, of: target.order)
                    #expect(removed.report?.photos.isEmpty == true)
                    #expect(removed.report?.status == "done", "togliere la foto non toglie il risultato")
                } catch {
                    try? await client.clearReport(step: target.step, of: target.order)
                    throw error
                }
                try await client.clearReport(step: target.step, of: target.order)
            }
        }

        @Test(.enabled(if: LiveEnv.workOrderChecks, "ARIA_LIVE_WRITE=1 + ARIA_LIVE_WORK_ORDER"))
        func theServerRefusesAPhotoLimitBeyondThree() async throws {
            try await connect { client in
                guard let target = try await freeStep(client) else { return }
                let jpeg = sampleJPEG()
                _ = try await client.report(.done(note: nil), step: target.step, of: target.order)
                var thrown: (any Error)?
                do {
                    for _ in 0..<3 { _ = try await client.addPhoto(jpeg: jpeg, step: target.step, of: target.order) }
                    _ = try await client.addPhoto(jpeg: jpeg, step: target.step, of: target.order)
                } catch {
                    thrown = error
                }
                // Il DELETE del passo toglie anche le foto.
                try? await client.clearReport(step: target.step, of: target.order)

                if case AriaError.workOrder(.photoLimitReached, _)? = thrown { return }
                Issue.record("atteso photo_limit_reached alla quarta foto, trovato \(String(describing: thrown))")
            }
        }
    }
}
