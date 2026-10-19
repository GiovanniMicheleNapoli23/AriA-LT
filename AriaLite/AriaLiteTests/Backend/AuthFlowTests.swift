//
//  AuthFlowTests.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 15/10/26.
//
//  Il flusso di accesso contro la rete finta: request-link → verify → JWT, la vita della sessione
//  (rinnovo, un rinnovo alla volta, sessione finita, host giù) e l'uscita.
//

import Foundation
import Testing
@testable import AriaLite

extension BackendTests {
    @Suite("Auth flow")
    struct AuthFlow {
        private let server = StubServer.shared
        private let auth: AriaAuth

        init() {
            TestEnv.reset()
            auth = AriaAuth(config: TestEnv.config)
        }

        // MARK: request-link

        @Test func requestLinkPostsOnlyTheEmailToTheSignInHost() async throws {
            server.route("POST /api/auth/mobile/request-link", .json("{}", status: 202))
            HTTPCookieStorage.shared.setCookie(HTTPCookie(properties: [
                .domain: TestEnv.authHost, .path: "/", .name: "sid", .value: "1"])!)

            try await auth.requestLink(email: "mario@acme.test")

            let call = try #require(server.calls("POST /api/auth/mobile/request-link").first)
            #expect(call.host == TestEnv.authHost)
            #expect(call.json as? [String: String] == ["email": "mario@acme.test"])
            #expect(call.header("ngrok-skip-browser-warning") == nil)
            #expect(call.header("user-agent")?.hasPrefix("AriaPLT-Mobile/") == true)
            #expect(call.header("content-type") == "application/json")
            #expect(call.header("authorization") == nil, "ancora nessuna sessione")
            #expect(call.header("cookie") == nil, "mai cookie verso l'host")
        }

        @Test func requestLinkRateLimitTellsHowLongToWait() async {
            server.route("POST /api/auth/mobile/request-link",
                         .json(#"{"error":"rate"}"#, status: 429, headers: ["X-Retry-After": "42"]))
            await #expect { try await auth.requestLink(email: "a@b.c") } throws: { error in
                (error as? AriaError)?.localizedDescription.contains("42") == true
            }
        }

        @Test func requestLinkRateLimitWithoutHeaderStillExplains() async {
            server.route("POST /api/auth/mobile/request-link", .json("{}", status: 429))
            await #expect { try await auth.requestLink(email: "a@b.c") } throws: { error in
                (error as? AriaError)?.localizedDescription.isEmpty == false
            }
        }

        @Test func requestLinkWithHostDownIsOfflineNotWrongEmail() async {
            server.route("POST /api/auth/mobile/request-link", .hostDown())
            await #expect { try await auth.requestLink(email: "a@b.c") } throws: { error in
                if case AriaError.signInHostOffline = error { true } else { false }
            }
        }

        @Test func requestLinkOnTheWrongServerSaysSoInsteadOfDecodingGarbage() async {
            server.route("POST /api/auth/mobile/request-link", .json(#"{"error":"nf"}"#, status: 404))
            await #expect { try await auth.requestLink(email: "a@b.c") } throws: { error in
                if case AriaError.linkSignInUnavailable = error { true } else { false }
            }
        }

        @Test func requestLinkNetworkFailureIsReportedAsURLError() async {
            server.route("POST /api/auth/mobile/request-link", .failing(.notConnectedToInternet))
            await #expect { try await auth.requestLink(email: "a@b.c") } throws: { error in
                AriaHTTP.isOffline(error)
            }
        }

        // MARK: verify

        @Test func verifyStoresTheSessionAndMintsTheJWT() async throws {
            TestEnv.stubSignIn()
            let account = try await auth.completeSignIn(with: AriaSignInLink(token: "link-token"))

            #expect(account == AriaMobileAccount(id: "u1", name: "Mario Rossi", email: "mario@acme.test"))
            #expect(AriaKeychain.exists("aria.mobile_session"))
            if !AriaBiometrics.isAvailable { #expect(AriaKeychain.get("aria.mobile_session") == "SESSION") }
            #expect(auth.hasStoredLogin && auth.isMobileSession)

            let verify = try #require(server.calls("POST /api/auth/mobile/verify").first)
            #expect(verify.json as? [String: String] == ["token": "link-token"])
            #expect(verify.header("authorization") == nil)
            let mint = try #require(server.calls("GET /api/aria/token").first)
            #expect(mint.header("authorization") == "Bearer SESSION")
            #expect(mint.host == TestEnv.authHost)
        }

        @Test func verifyFallsBackToTheBodyTokenWhenTheHeaderIsMissing() async throws {
            TestEnv.stubSignIn()
            server.route("POST /api/auth/mobile/verify", .json(TestEnv.verifyBody))
            _ = try await auth.completeSignIn(with: AriaSignInLink(token: "t"))
            #expect(server.calls("GET /api/aria/token").first?.header("authorization") == "Bearer SESSION")
        }

        @Test func verifyWithoutAnySessionFails() async {
            TestEnv.stubSignIn()
            server.route("POST /api/auth/mobile/verify",
                         .json(#"{"user":{"id":"u1","name":"M","email":"m@a.b"}}"#))
            await #expect(throws: AriaError.self) { try await auth.completeSignIn(with: AriaSignInLink(token: "t")) }
            #expect(!auth.hasStoredLogin)
        }

        @Test func verifyWithMalformedBodyIsADecodingError() async {
            TestEnv.stubSignIn()
            server.route("POST /api/auth/mobile/verify", .json("[1,2]", headers: ["set-auth-token": "S"]))
            await #expect { try await auth.completeSignIn(with: AriaSignInLink(token: "t")) } throws: { error in
                if case AriaError.decoding = error { true } else { false }
            }
            #expect(!auth.hasStoredLogin, "senza profilo valido non si salva nessuna sessione")
        }

        @Test func usedOrExpiredLinkIsReportedAndKeepsNoSession() async {
            server.route("POST /api/auth/mobile/verify", .json(#"{"code":"INVALID_OR_EXPIRED_LINK"}"#, status: 401))
            await #expect { try await auth.completeSignIn(with: AriaSignInLink(token: "t")) } throws: { error in
                if case AriaError.linkExpired = error { true } else { false }
            }
            #expect(!auth.hasStoredLogin)
        }

        @Test func disabledAccountIsReported() async {
            server.route("POST /api/auth/mobile/verify", .json(#"{"code":"ACCOUNT_DISABLED"}"#, status: 403))
            await #expect { try await auth.completeSignIn(with: AriaSignInLink(token: "t")) } throws: { error in
                (error as? AriaError)?.localizedDescription
                    == String(localized: "This account is disabled. Contact your company administrator.")
            }
            #expect(!auth.hasStoredLogin)
        }

        @Test func verifyRateLimit() async {
            server.route("POST /api/auth/mobile/verify",
                         .json("{}", status: 429, headers: ["X-Retry-After": "7"]))
            await #expect { try await auth.completeSignIn(with: AriaSignInLink(token: "t")) } throws: { error in
                (error as? AriaError)?.localizedDescription.contains("7") == true
            }
        }

        @Test func networkDropDuringVerifyKeepsTheLinkRetryable() async {
            server.route("POST /api/auth/mobile/verify", .failing(.networkConnectionLost))
            await #expect { try await auth.completeSignIn(with: AriaSignInLink(token: "t")) } throws: { error in
                AriaHTTP.isOffline(error)
            }
            #expect(!auth.hasStoredLogin)
        }

        @Test func signingInAgainReplacesTheDeveloperToken() async throws {
            try await auth.useDeveloperToken(TestEnv.jwt())
            #expect(AriaKeychain.exists("aria.dev_access_token"))
            TestEnv.stubSignIn()
            _ = try await auth.completeSignIn(with: AriaSignInLink(token: "t"))
            #expect(!AriaKeychain.exists("aria.dev_access_token"))
        }

        // MARK: JWT

        @Test func jwtIsCachedBetweenCalls() async throws {
            let auth = try await TestEnv.signedInAuth()
            let first = try await auth.validAccessToken()
            let second = try await auth.validAccessToken()
            #expect(first == second)
            #expect(server.calls("GET /api/aria/token").count == 1, "il JWT del login basta: nessun rinnovo")
        }

        @Test func invalidateForcesANewJWT() async throws {
            let auth = try await TestEnv.signedInAuth()
            server.route("GET /api/aria/token", TestEnv.tokenReply(tag: "b"))
            await auth.invalidate()
            let fresh = try await auth.validAccessToken()
            #expect(server.calls("GET /api/aria/token").count == 2)
            #expect(TestEnv.jwtTag(fresh) == "b")
        }

        @Test func concurrentCallersShareASingleRenewal() async throws {
            let auth = try await TestEnv.signedInAuth()
            server.route("GET /api/aria/token", TestEnv.tokenReply(tag: "slow", delay: 0.25))
            await auth.invalidate()

            let tokens = try await withThrowingTaskGroup(of: String.self) { group in
                for _ in 0..<8 { group.addTask { try await auth.validAccessToken() } }
                var all: [String] = []
                for try await token in group { all.append(token) }
                return all
            }
            #expect(Set(tokens).count == 1, "tutti ricevono lo stesso JWT")
            #expect(server.calls("GET /api/aria/token").count == 2, "una sola richiesta di rinnovo, non otto")
        }

        @Test(arguments: [401, 403])
        func endedSessionClearsTheKeychainAndAsksForLogin(status: Int) async throws {
            let auth = try await TestEnv.signedInAuth()
            server.route("GET /api/aria/token", .json(#"{"error":"no"}"#, status: status))
            await auth.invalidate()
            await #expect { try await auth.validAccessToken() } throws: { error in
                if case AriaError.signedOut = error { true } else { false }
            }
            #expect(!auth.hasStoredLogin)
        }

        @Test func hostDownWhileRenewingDoesNotSignTheOperatorOut() async throws {
            let auth = try await TestEnv.signedInAuth()
            server.route("GET /api/aria/token", .hostDown())
            await auth.invalidate()
            await #expect { try await auth.validAccessToken() } throws: { error in
                if case AriaError.signInHostOffline = error { true } else { false }
            }
            #expect(auth.hasStoredLogin, "la sessione è ancora buona: l'host è solo giù")
        }

        @Test func networkFailureWhileRenewingKeepsTheSession() async throws {
            let auth = try await TestEnv.signedInAuth()
            server.route("GET /api/aria/token", .failing(.timedOut))
            await auth.invalidate()
            await #expect(throws: URLError.self) { try await auth.validAccessToken() }
            #expect(auth.hasStoredLogin)
        }

        @Test func reissuedSessionTokenReplacesTheOldOne() async throws {
            let auth = try await TestEnv.signedInAuth()
            server.route("GET /api/aria/token", TestEnv.tokenReply(headers: ["set-auth-token": "RENEWED"]))
            await auth.invalidate()
            _ = try await auth.validAccessToken()

            server.route("GET /api/aria/token", TestEnv.tokenReply(tag: "c"))
            await auth.invalidate()
            _ = try await auth.validAccessToken()
            #expect(server.calls("GET /api/aria/token").last?.header("authorization") == "Bearer RENEWED")
        }

        @Test func nonJWTResponseIsRejected() async throws {
            let auth = try await TestEnv.signedInAuth()
            server.route("GET /api/aria/token", .json(#"{"token":"not-a-jwt"}"#))
            await auth.invalidate()
            await #expect { try await auth.validAccessToken() } throws: { error in
                if case AriaError.decoding = error { true } else { false }
            }
        }

        @Test func withoutASessionTheOperatorMustLogIn() async {
            await #expect { try await auth.validAccessToken() } throws: { error in
                if case AriaError.signedOut = error { true } else { false }
            }
        }

        // MARK: Token di sviluppo

        @Test func developerTokenIsUsedWithoutAnyRequest() async throws {
            let jwt = TestEnv.jwt()
            try await auth.useDeveloperToken(jwt)
            let used = try await auth.validAccessToken()
            #expect(used == jwt)
            #expect(server.calls.isEmpty)
            #expect(auth.hasStoredSession && !auth.hasStoredLogin && !auth.isMobileSession)
        }

        @Test func expiredOrMalformedDeveloperTokenIsRefused() async {
            await #expect(throws: AriaError.self) { try await auth.useDeveloperToken(TestEnv.jwt(expiresIn: -60)) }
            await #expect(throws: AriaError.self) { try await auth.useDeveloperToken("abc") }
            #expect(!auth.hasStoredSession)
        }

        @Test func developerTokenCannotBeRenewedAfterA401() async throws {
            try await auth.useDeveloperToken(TestEnv.jwt())
            await auth.invalidate()
            #expect(!auth.hasStoredSession)
        }

        // MARK: Uscita

        @Test func signOutTellsTheServerAndForgetsTheSession() async throws {
            let auth = try await TestEnv.signedInAuth()
            server.route("POST /api/auth/sign-out", .json("{}"))
            await auth.signOut()
            let call = try #require(server.calls("POST /api/auth/sign-out").first)
            #expect(call.header("authorization") == "Bearer SESSION")
            #expect(call.host == TestEnv.authHost)
            #expect(!auth.hasStoredSession)
        }

        @Test func signOutStillClearsLocalStateWhenTheServerIsUnreachable() async throws {
            let auth = try await TestEnv.signedInAuth()
            server.route("POST /api/auth/sign-out", .failing(.notConnectedToInternet))
            await auth.signOut()
            #expect(!auth.hasStoredSession)
            await #expect(throws: AriaError.self) { try await auth.validAccessToken() }
        }

        @Test func discardSessionIsLocalOnly() async throws {
            let auth = try await TestEnv.signedInAuth()
            let before = server.calls.count
            await auth.discardSession()
            #expect(server.calls.count == before)
            #expect(!auth.hasStoredSession)
        }

        // MARK: Sessioni delle versioni precedenti

        @Test func legacySessionsAreRemovedAtStartup() {
            for key in ["aria.web_session", "aria.link_session", "aria.link_verifier"] {
                AriaKeychain.set("old", for: key)
            }
            _ = AriaAuth(config: TestEnv.config)
            for key in ["aria.web_session", "aria.link_session", "aria.link_verifier"] {
                #expect(!AriaKeychain.exists(key), "\(key) doveva sparire")
            }
        }

        @Test func forgetStoredSessionDropsOnlyTheSession() {
            AriaKeychain.set("S", for: "aria.mobile_session")
            auth.forgetStoredSession()
            #expect(!auth.hasStoredLogin)
        }
    }
}
