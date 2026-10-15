//
//  SignInLinkTests.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 15/10/26.
//
//  Riconoscimento del link di accesso: il token sta nel frammento dell'URL, solo il nostro host,
//  solo /m/sign-in. Nessuna rete.
//

import Foundation
import Testing
@testable import AriaLite

struct SignInLinkTests {
    private let host = TestEnv.authHost
    private var auth: AriaAuth { AriaAuth(config: TestEnv.config) }

    private func link(_ string: String) -> AriaSignInLink? {
        URL(string: string).flatMap { auth.signInLink(from: $0) }
    }

    @Test func tokenIsReadFromTheFragment() {
        #expect(link("https://\(host)/m/sign-in#token=abc123") == AriaSignInLink(token: "abc123"))
    }

    @Test func tokenKeepsUrlSafeCharactersAndDecodesEscapes() {
        #expect(link("https://\(host)/m/sign-in#token=aB_c-D.9~x")?.token == "aB_c-D.9~x")
        #expect(link("https://\(host)/m/sign-in#token=a%2Fb%3D")?.token == "a/b=")
    }

    @Test func fragmentWithOtherParametersStillFindsTheToken() {
        #expect(link("https://\(host)/m/sign-in#utm=1&token=zz&x=2")?.token == "zz")
    }

    @Test func queryTokenIsAcceptedForTolerance() {
        #expect(link("https://\(host)/m/sign-in?token=q")?.token == "q")
    }

    @Test func fragmentWinsOverQuery() {
        #expect(link("https://\(host)/m/sign-in?token=query#token=fragment")?.token == "fragment")
    }

    @Test func customSchemeLink() {
        #expect(link("aria://sign-in#token=zz")?.token == "zz")
        #expect(link("aria://other#token=zz") == nil)
    }

    @Test func rejectsWrongHostPathOrMissingToken() {
        #expect(link("https://evil.test/m/sign-in#token=abc") == nil)
        #expect(link("https://\(host)/other#token=abc") == nil)
        #expect(link("https://\(host)/m/sign-in") == nil)
        #expect(link("https://\(host)/m/sign-in#token=") == nil)
        #expect(link("https://\(host)/m/sign-in#other=1") == nil)
        #expect(link("https://app.ariaplt.com/api/auth/magic-link/verify?token=abc") == nil, "il link della web non vale più")
    }

    @Test func linkIsFoundInsidePastedText() {
        let text = "Hi Mario,\nSign in: https://\(host)/m/sign-in#token=abc123XYZ. Thanks!"
        #expect(auth.magicLink(in: text)?.token == "abc123XYZ")
    }

    @Test func firstValidLinkWinsAmongMany() {
        let text = "https://other.test/x https://\(host)/m/sign-in#token=first https://\(host)/m/sign-in#token=second"
        #expect(auth.magicLink(in: text)?.token == "first")
    }

    @Test func pastedTextWithoutALinkIsRejected() {
        #expect(auth.magicLink(in: "hello") == nil)
        #expect(auth.magicLink(in: "") == nil)
        #expect(auth.magicLink(in: "https://\(host)/m/sign-in") == nil)
    }
}
