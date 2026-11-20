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

    @Test func aRedirectToAnotherPortDropsTheCredentials() throws {
        let followed = try #require(AriaRedirectGuard.redirect(request("https://api.example.com:8443/v1/b"),
                                                               from: request("https://api.example.com/v1/a")))
        for header in AriaRedirectGuard.credentialHeaders {
            #expect(followed.value(forHTTPHeaderField: header) == nil)
        }
        // La porta di default scritta per esteso è lo stesso host.
        let same = try #require(AriaRedirectGuard.redirect(request("https://api.example.com:443/v1/b"),
                                                           from: request("https://api.example.com/v1/a")))
        #expect(same.value(forHTTPHeaderField: "Authorization") == "Bearer jwt")
    }

    @Test func theEngineKeyAndTheCaptchaDoNotFollowARedirectToAnotherHost() throws {
        var original = request("https://engine.example.com/token", authorized: false)
        original.setValue("secret", forHTTPHeaderField: "x-aria-password")
        original.setValue("captcha", forHTTPHeaderField: "x-captcha-response")
        var new = original
        new.url = URL(string: "https://attacker.example/token")
        let followed = try #require(AriaRedirectGuard.redirect(new, from: original))
        #expect(followed.value(forHTTPHeaderField: "x-aria-password") == nil)
        #expect(followed.value(forHTTPHeaderField: "x-captcha-response") == nil)
    }

    /// Un 307/308 rimanda anche il corpo: il token del link di accesso o un file non vanno a un altro host.
    @Test(arguments: ["POST", "PUT", "PATCH", "DELETE"])
    func aWriteIsNotRedirectedToAnotherHost(_ method: String) throws {
        var new = request("https://attacker.example/steal", authorized: false)
        new.httpMethod = method
        var original = request("https://app.example.com/api/auth/mobile/verify", authorized: false)
        original.httpMethod = method
        #expect(AriaRedirectGuard.redirect(new, from: original) == nil)
        // Sullo stesso host resta com'è.
        var sameHost = request("https://app.example.com/api/auth/mobile/verify2", authorized: false)
        sameHost.httpMethod = method
        #expect(AriaRedirectGuard.redirect(sameHost, from: original) != nil)
    }

    @Test func anUploadToSignedStorageFollowsItsRegionRedirectWithoutCredentials() throws {
        var new = request("https://bucket.s3.eu-south-1.amazonaws.com/")
        new.httpMethod = "POST"
        var original = request("https://bucket.s3.amazonaws.com/", authorized: false)
        original.httpMethod = "POST"
        let followed = try #require(AriaRedirectGuard.redirect(new, from: original, followsUploadsAcrossHosts: true))
        #expect(followed.httpMethod == "POST")
        for header in AriaRedirectGuard.credentialHeaders {
            #expect(followed.value(forHTTPHeaderField: header) == nil)
        }
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
