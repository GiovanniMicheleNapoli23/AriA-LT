//
//  HTTPErrorTests.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 15/10/26.
//
//  Interpretazione delle risposte HTTP: codici del server, messaggi, gateway che non risponde,
//  rete assente. Nessuna rete: si costruiscono le risposte a mano.
//

import Foundation
import Testing
@testable import AriaLite

struct HTTPErrorTests {
    private func response(_ status: Int, _ headers: [String: String] = [:]) -> HTTPURLResponse {
        HTTPURLResponse(url: URL(string: "https://x.test/p")!, statusCode: status, httpVersion: nil, headerFields: headers)!
    }

    private func check(_ status: Int, _ body: String, headers: [String: String] = [:]) -> AriaError? {
        do {
            try AriaHTTP.check(response(status, headers), Data(body.utf8))
            return nil
        } catch {
            return error as? AriaError
        }
    }

    // MARK: check

    @Test(arguments: [200, 201, 202, 204, 299])
    func successDoesNotThrow(status: Int) {
        #expect(check(status, "") == nil)
    }

    @Test func plainErrorKeepsStatusAndDetail() throws {
        let error = try #require(check(500, #"{"detail":"boom"}"#))
        guard case .http(let status, let detail) = error else { Issue.record("atteso .http, trovato \(error)"); return }
        #expect(status == 500)
        #expect(detail == "boom")
    }

    @Test func notAMobileUserIsItsOwnError() throws {
        let error = try #require(check(403, #"{"code":"not_a_mobile_user"}"#))
        guard case .notMobileUser = error else { Issue.record("atteso .notMobileUser, trovato \(error)"); return }
    }

    @Test func cloudfrontForbiddenIsTheFirewall() throws {
        let error = try #require(check(403, "<html></html>", headers: ["Server": "CloudFront"]))
        guard case .wafBlocked = error else { Issue.record("atteso .wafBlocked, trovato \(error)"); return }
    }

    @Test(arguments: AriaServerCode.allCases)
    func everyServerCodeBecomesATypedError(code: AriaServerCode) throws {
        let error = try #require(check(409, #"{"detail":{"code":"\#(code.rawValue)","message":"x"}}"#))
        #expect(error.serverCode == code)
    }

    @Test func stepsIncompleteCarriesTheMissingStepIds() throws {
        let error = try #require(check(409, #"{"detail":{"code":"steps_incomplete","message":"m","missing":["a1","b2"]}}"#))
        guard case .workOrder(.stepsIncomplete, let missing) = error else { Issue.record("trovato \(error)"); return }
        #expect(missing == ["a1", "b2"])
    }

    @Test func unknownCodeFallsBackToPlainHTTPError() throws {
        let error = try #require(check(409, #"{"detail":{"code":"brand_new","message":"Something"}}"#))
        guard case .http(409, let detail) = error else { Issue.record("trovato \(error)"); return }
        #expect(detail == "Something")
    }

    @Test func everyServerCodeHasAUserFacingMessage() {
        for code in AriaServerCode.allCases {
            #expect(!code.localized.isEmpty, "\(code) senza messaggio")
        }
        #expect(AriaServerCode.allCases.count == 13)
    }

    // MARK: code / detail

    @Test(arguments: [
        (#"{"code":"a"}"#, "a"),
        (#"{"detail":{"code":"b"}}"#, "b"),
        (#"{"error":{"code":"c"}}"#, "c"),
    ])
    func codeIsFoundInEveryEnvelope(body: String, expected: String) {
        #expect(AriaHTTP.code(from: Data(body.utf8)) == expected)
    }

    @Test func codeIsNilForGarbage() {
        #expect(AriaHTTP.code(from: Data("not json".utf8)) == nil)
        #expect(AriaHTTP.code(from: Data("{}".utf8)) == nil)
    }

    @Test(arguments: [
        (#"{"detail":"plain"}"#, "plain"),
        (#"{"detail":[{"msg":"bad id"},{"msg":"bad status"}]}"#, "bad id; bad status"),
        (#"{"detail":{"code":"x","message":"from object"}}"#, "from object"),
        (#"{"detail":{"code":"only_code"}}"#, "only_code"),
        (#"{"message":"better-auth"}"#, "better-auth"),
        (#"{"error":{"message":"nested"}}"#, "nested"),
        (#"{"error":"flat"}"#, "flat"),
    ])
    func detailReadsEveryErrorShape(body: String, expected: String) {
        #expect(AriaHTTP.detail(from: Data(body.utf8)) == expected)
    }

    @Test func detailFallsBackToTheRawBodyTruncated() {
        #expect(AriaHTTP.detail(from: Data("upstream exploded".utf8)) == "upstream exploded")
        let long = String(repeating: "x", count: 900)
        #expect(AriaHTTP.detail(from: Data(long.utf8)).count == 500)
    }

    // MARK: Host giù e rete

    @Test(arguments: [502, 503, 504])
    func gatewayErrorsMeanTheHostIsDown(status: Int) {
        let r = response(status, ["Content-Type": "text/html; charset=utf-8"])
        guard case .signInHostOffline? = AriaHTTP.hostDownError(r) else { Issue.record("atteso signInHostOffline"); return }
        #expect(AriaHTTP.isHostDown(r))
    }

    @Test func otherResponsesAreNeverHostDown() {
        #expect(AriaHTTP.hostDownError(response(401, ["Content-Type": "application/json"])) == nil)
        #expect(AriaHTTP.hostDownError(response(200, ["Content-Type": "text/html"])) == nil)
        #expect(!AriaHTTP.isHostDown(response(403, ["Content-Type": "text/html"])), "l'HTML del firewall non è un host giù")
        #expect(!AriaHTTP.isHostDown(response(404, ["Content-Type": "text/html"])), "un 404 di Next non è un host giù")
    }

    @Test(arguments: [URLError.Code.notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost,
                      .cannotFindHost, .dnsLookupFailed, .timedOut, .internationalRoamingOff, .dataNotAllowed])
    func connectivityErrorsCountAsOffline(code: URLError.Code) {
        #expect(AriaHTTP.isOffline(URLError(code)))
    }

    @Test func otherErrorsAreNotOffline() {
        #expect(!AriaHTTP.isOffline(URLError(.badURL)))
        #expect(!AriaHTTP.isOffline(URLError(.cancelled)))
        #expect(!AriaHTTP.isOffline(AriaError.signedOut))
        #expect(AriaHTTP.isOffline(AriaError.serverOffline))
        #expect(AriaHTTP.isOffline(AriaError.signInHostOffline))
    }

    @Test func cookielessSessionNeverStoresOrSendsCookies() {
        let session = AriaHTTP.cookielessSession()
        #expect(session.configuration.httpShouldSetCookies == false)
        #expect(session.configuration.httpCookieAcceptPolicy == .never)
        #expect(session.configuration.httpCookieStorage == nil)
    }

    @Test func errorDescriptionsAreNeverEmpty() {
        let errors: [AriaError] = [.signedOut, .locked, .linkExpired, .linkSignInUnavailable, .signInHostOffline,
                                   .serverOffline, .notMobileUser, .http(status: 500, detail: "x"), .wafBlocked,
                                   .bodyTooLarge(bytes: 9000, limit: 8000), .missingCompany, .missingPlant,
                                   .notOnPhone, .invalidChoice(field: "category", valid: ["A"], message: "x"), .decoding("x"),
                                   .stream("msg"), .workOrder(.workOrderClosed)]
        for error in errors { #expect(!(error.errorDescription ?? "").isEmpty, "\(error)") }
    }
}
