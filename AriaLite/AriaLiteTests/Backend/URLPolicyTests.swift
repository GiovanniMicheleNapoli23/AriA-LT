//
//  URLPolicyTests.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 15/10/26.
//
//  Quali URL del modello o del server si aprono o si caricano (AriaURLPolicy) e il tetto
//  di un frame SSE senza confine (AriaSSEParser). Nessuna rete.
//

import Foundation
import Testing
@testable import AriaLite

struct URLPolicyTests {
    private func external(_ string: String) -> URL? {
        URL(string: string).flatMap { AriaURLPolicy.external($0) }
    }

    private func image(_ string: String) -> URL? {
        URL(string: string).flatMap { AriaURLPolicy.image($0) }
    }

    @Test(arguments: [
        "https://example.com/a", "http://example.com/a", "HTTPS://Example.com/A", "mailto:ops@example.com",
    ])
    func webAndMailLinksOpen(_ link: String) {
        #expect(external(link) != nil)
    }

    @Test(arguments: [
        "aria://sign-in#token=x", "tel:+390812345678", "sms:+390812345678", "facetime:ops@example.com",
        "javascript:alert(1)", "file:///etc/passwd", "otherapp://open?x=1", "http://", "https:///path",
        "/work-orders/12",
    ])
    func everythingElseIsBlocked(_ link: String) {
        #expect(external(link) == nil)
    }

    @Test func imagesLoadOnlyOverHTTPS() {
        #expect(image("https://cdn.example.com/p.jpg") != nil)
        #expect(image("HTTPS://cdn.example.com/p.jpg") != nil)
        #expect(image("http://cdn.example.com/p.jpg") == nil)
        #expect(image("https:///p.jpg") == nil)
        #expect(image("file:///tmp/p.jpg") == nil)
        #expect(image("data:image/png;base64,AAAA") == nil)
    }

    // MARK: SSE

    private func feed(_ parser: inout AriaSSEParser, _ text: String) -> [AriaSSEEvent] {
        text.utf8.compactMap { parser.consume($0) }
    }

    @Test func frameOverTheLimitIsDroppedAndTheNextOneParses() {
        var parser = AriaSSEParser()
        var events = feed(&parser, "data: " + String(repeating: "a", count: AriaSSEParser.maxFrameBytes + 10))
        #expect(events.isEmpty)
        events += feed(&parser, "\n\nevent: ok\ndata: next\n\n")
        #expect(events.map(\.event) == ["ok"])
        #expect(events.first?.data == "next")
        #expect(parser.finish() == nil)
    }

    @Test func discardingSurvivesLinesInsideTheOversizedFrame() {
        var parser = AriaSSEParser()
        let line = "data: " + String(repeating: "b", count: 1000) + "\n"
        var events = feed(&parser, String(repeating: line, count: 1100))
        events += feed(&parser, "\r\n\r\ndata: after\n\n")
        #expect(events.map(\.data) == ["after"])
    }

    @Test func frameUnderTheLimitIsUntouched() {
        var parser = AriaSSEParser()
        let events = feed(&parser, "data: " + String(repeating: "a", count: 100_000) + "\n\n")
        #expect(events.count == 1)
        #expect(events.first?.data.utf8.count == 100_000)
    }
}
