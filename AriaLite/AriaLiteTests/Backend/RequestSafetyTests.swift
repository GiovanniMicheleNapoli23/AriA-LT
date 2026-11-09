//
//  RequestSafetyTests.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 24/10/26.
//
//  Le credenziali non escono dal nostro host: redirect filtrati (AriaRedirectGuard) e percorsi
//  senza segmenti `.`/`..` (AriaAPIClient.checkPath). Nessuna rete.
//

import Foundation
import Testing
@testable import AriaLite

struct RequestSafetyTests {
    private func request(_ string: String, authorized: Bool = true) -> URLRequest {
        var req = URLRequest(url: URL(string: string)!)
        if authorized {
            req.setValue("Bearer jwt", forHTTPHeaderField: "Authorization")
            req.setValue("company-1", forHTTPHeaderField: "Company-Id")
            req.setValue("session=x", forHTTPHeaderField: "Cookie")
        }
        return req
    }

    @Test func aRedirectOnTheSameHostKeepsTheCredentials() throws {
        let followed = try #require(AriaRedirectGuard.redirect(request("https://api.example.com/v1/b"),
                                                               from: request("https://API.example.com/v1/a")))
        #expect(followed.value(forHTTPHeaderField: "Authorization") == "Bearer jwt")
        #expect(followed.value(forHTTPHeaderField: "Company-Id") == "company-1")
    }

    @Test func aRedirectToAnotherHostDropsTheCredentials() throws {
        let followed = try #require(AriaRedirectGuard.redirect(request("https://attacker.example/steal"),
                                                               from: request("https://api.example.com/v1/a")))
        for header in AriaRedirectGuard.credentialHeaders {
            #expect(followed.value(forHTTPHeaderField: header) == nil)
        }
        #expect(followed.url?.host() == "attacker.example")
    }

    @Test(arguments: ["http://api.example.com/v1/b", "ftp://api.example.com/v1/b"])
    func aRedirectAwayFromHTTPSIsNotFollowed(_ target: String) {
        #expect(AriaRedirectGuard.redirect(request(target), from: request("https://api.example.com/v1/a")) == nil)
    }

    @Test(arguments: ["v1/assets/by-tag/P-101", "v1/work-orders/12/steps/a.b", "v1/x/..y", "v1/x/.hidden"])
    func ordinaryPathsAreAccepted(_ path: String) throws {
        try AriaAPIClient.checkPath(path)
    }

    @Test(arguments: ["v1/assets/by-tag/x/../../members", "v1/x/./y", "v1/x/..", "../v1/me"])
    func dotSegmentsAreRefused(_ path: String) {
        #expect(throws: AriaError.self) { try AriaAPIClient.checkPath(path) }
    }
}
