//
//  CompanyWebsiteTests.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Il sito dell'azienda all'iscrizione, porta delle regole della web: l'host letto da ciò che si scrive (accettati e
//  rifiutati), i provider di posta e i loro sottodomini, il dominio suggerito dall'email, il testo del campo e la
//  verifica con un resolver finto (mai DNS vero).
//

import Foundation
import Testing
@testable import AriaLite

/// Un resolver che risponde sempre uguale e conta le chiamate.
private nonisolated final class StubResolver: AriaDomainResolving, @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [String] = []
    private let answer: AriaDomainLookup

    init(_ answer: AriaDomainLookup) { self.answer = answer }

    var hosts: [String] { lock.withLock { recorded } }

    func lookup(_ host: String) async -> AriaDomainLookup {
        lock.withLock { recorded.append(host) }
        return answer
    }
}

@Suite("Company website")
struct CompanyWebsiteTests {
    @Test(arguments: [
        ("acme.it", "acme.it"),
        ("  https://www.Acme.IT/chi-siamo?x=1 ", "acme.it"),
        ("http://shop.acme.co.uk", "shop.acme.co.uk"),
        ("WWW.acme.com.", "acme.com"),
        ("xn--bcher-kva.de", "xn--bcher-kva.de"),
        ("bücher.de", "xn--bcher-kva.de"),
        ("https://acme.it:443/x", "acme.it"),
    ])
    func readsTheHost(input: String, host: String) {
        #expect(AriaCompanyWebsite.host(input) == host)
    }

    @Test(arguments: [
        "", "acme", "localhost", "127.0.0.1", "http://10.0.0.1", "acme.it:8080", "user:pass@acme.it", "ftp://acme.it",
        "acme .it", "-acme.it", "acme.123", "javascript:alert(1)",
        "   ", "acme.it:abc", "acme.it:99999", ".acme.it", "acme..it", "acme.it..", "https:///acme.it", "www.it",
        "a.b", "acme.c0m", "ac_me.it", "https://acme.it\tx",
    ])
    func turnsDownWhatIsNotADomain(input: String) {
        #expect(AriaCompanyWebsite.host(input) == nil)
    }

    @Test func limitsOfLabelsAndHost() {
        let label63 = String(repeating: "a", count: 63)
        #expect(AriaCompanyWebsite.host("\(label63).it") == "\(label63).it")
        #expect(AriaCompanyWebsite.host("\(label63)a.it") == nil)
        #expect(AriaCompanyWebsite.host("acme.\(label63)") == "acme.\(label63)")
        #expect(AriaCompanyWebsite.host("acme.\(label63)a") == nil)
        #expect(AriaCompanyWebsite.host("xn--bcher-kva.xn--p1ai") == "xn--bcher-kva.xn--p1ai")
        // 63 + 63 + 63 + 63 + 3 punti = 255 caratteri: oltre il tetto di 253.
        #expect(AriaCompanyWebsite.host([String](repeating: label63, count: 4).joined(separator: ".")) == nil)
    }

    @Test func theInputIsCutAtThreeHundredCharacters() {
        #expect(AriaCompanyWebsite.maxInputLength == 300)
        // L'host sta nei primi 300 caratteri: il resto (anche con spazi) non conta.
        #expect(AriaCompanyWebsite.host("acme.it/" + String(repeating: "x", count: 400)) == "acme.it")
        // Gli spazi oltre il taglio spariscono col taglio; quelli dentro i primi 300 no.
        #expect(AriaCompanyWebsite.host("acme.it/" + String(repeating: "x", count: 292) + " ciao") == "acme.it")
        #expect(AriaCompanyWebsite.host("acme.it/a b") == nil)
        // Un host che comincia oltre il trecentesimo carattere non si vede.
        #expect(AriaCompanyWebsite.host(String(repeating: "a", count: 300) + ".it") == nil)
        let padded = "https://" + String(repeating: "a", count: 62) + ".it/" + String(repeating: "y", count: 500)
        #expect(AriaCompanyWebsite.host(padded) == String(repeating: "a", count: 62) + ".it")
    }

    @Test func turnsDownAMailboxProviderAndItsSubdomains() {
        #expect(AriaCompanyWebsite.checkFormat("gmail.com") == .problem(.personal))
        #expect(AriaCompanyWebsite.checkFormat("https://www.libero.it") == .problem(.personal))
        #expect(AriaCompanyWebsite.isPersonalEmailHost("mail.yahoo.com"))
        #expect(AriaCompanyWebsite.checkFormat("192.168.1.1") == .problem(.invalid))
    }

    @Test func doesNotTakeANameThatOnlyEndsLikeAProvider() {
        #expect(!AriaCompanyWebsite.isPersonalEmailHost("notgmail.com"))
        #expect(AriaCompanyWebsite.checkFormat("sinauragroup.com") == .ok(host: "sinauragroup.com"))
    }

    @Test func theProviderListIsTheWebOne() {
        #expect(AriaCompanyWebsite.personalEmailDomains.count == 51)
        #expect(AriaCompanyWebsite.personalEmailDomains.contains("163.com"))
        #expect(AriaCompanyWebsite.personalEmailDomains.contains("legalmail.it"))
    }

    @Test func suggestsTheEmailsDomainUnlessItIsAMailboxProvider() {
        #expect(AriaCompanyWebsite.suggested(email: "ada@sinauragroup.com") == "sinauragroup.com")
        #expect(AriaCompanyWebsite.suggested(email: "ada@gmail.com") == "")
        #expect(AriaCompanyWebsite.suggested(email: nil) == "")
        #expect(AriaCompanyWebsite.suggested(email: "senza-chiocciola") == "")
        #expect(AriaCompanyWebsite.suggested(email: "ada@") == "")
        #expect(AriaCompanyWebsite.suggested(email: "ada@localhost") == "")
    }

    @Test func theFieldDropsAPastedScheme() {
        #expect(AriaCompanyWebsite.fieldText("https://acme.it") == "acme.it")
        #expect(AriaCompanyWebsite.fieldText("HTTP://Acme.it/chi") == "Acme.it/chi")
        #expect(AriaCompanyWebsite.fieldText("  http://acme.it") == "acme.it")
        #expect(AriaCompanyWebsite.fieldText("acme.it") == "acme.it")
        #expect(AriaCompanyWebsite.fieldText("ftp://acme.it") == "ftp://acme.it")
        #expect(AriaCompanyWebsite.fieldText("htt") == "htt")
    }

    @Test func onlyUnverifiedLeavesTheButtonFree() {
        for problem in AriaWebsiteProblem.allCases {
            #expect(problem.blocksSaving == (problem != .unverified))
        }
    }
}

@Suite("Company website verification")
struct CompanyWebsiteVerificationTests {
    @Test func acceptsADomainThatResolves() async {
        let resolver = StubResolver(.found)
        #expect(await AriaCompanyWebsite.verify("https://www.acme.it/x", resolver: resolver) == .ok(host: "acme.it"))
        #expect(resolver.hosts == ["acme.it"])
    }

    @Test func saysNotFoundWhenTheDomainHasNoAddress() async {
        let result = await AriaCompanyWebsite.verify("made-up-company.it", resolver: StubResolver(.notFound))
        #expect(result == .problem(.notFound))
    }

    @Test func saysUnverifiedWhenTheLookupItselfFailed() async {
        let result = await AriaCompanyWebsite.verify("acme.it", resolver: StubResolver(.failed))
        #expect(result == .problem(.unverified))
    }

    @Test func doesNotLookUpWhatIsNotACompanyDomain() async {
        let resolver = StubResolver(.found)
        #expect(await AriaCompanyWebsite.verify("gmail.com", resolver: resolver) == .problem(.personal))
        #expect(await AriaCompanyWebsite.verify("192.168.1.1", resolver: resolver) == .problem(.invalid))
        #expect(resolver.hosts.isEmpty)
    }

    @Test func aLocalHostIsNotFoundWithoutALookup() async {
        let resolver = StubResolver(.found)
        #expect(await AriaCompanyWebsite.verify("stampante.local", resolver: resolver) == .problem(.notFound))
        #expect(await AriaCompanyWebsite.verify("https://www.Nas.LOCAL/", resolver: resolver) == .problem(.notFound))
        #expect(resolver.hosts.isEmpty)
    }
}
