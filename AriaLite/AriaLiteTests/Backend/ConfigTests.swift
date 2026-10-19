//
//  ConfigTests.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 15/10/26.
//
//  Gli host letti da Info.plist (xcconfig): solo https, solo host semplici, altrimenti nil
//  e quindi il valore di produzione. Nessuna rete.
//

import Foundation
import Testing
@testable import AriaLite

struct ConfigTests {
    @Test func validHostBecomesHTTPSURL() {
        #expect(AriaConfig.httpsURL(host: "api.ariaplt.com") == URL(string: "https://api.ariaplt.com"))
        #expect(AriaConfig.httpsURL(host: "localhost") == URL(string: "https://localhost"))
    }

    @Test(arguments: [
        nil, "", " ", "api.ariaplt.com ", "http://api.ariaplt.com", "https://api.ariaplt.com",
        "api.ariaplt.com/v1", "api.ariaplt.com?x=1", "api.ariaplt.com#x", "user@api.ariaplt.com",
        "api.ariaplt.com:8080", "api ariaplt.com", "$(ARIA_API_HOST)",
    ] as [String?])
    func invalidHostIsRejected(_ host: String?) {
        #expect(AriaConfig.httpsURL(host: host) == nil)
    }
}
