//
//  MarkdownTests.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 19/10/26.
//
//  AriaMarkdown: i blocchi e il testo in linea delle risposte della chat. I risultati si ricordano
//  (le viste rileggono lo stesso testo a ogni pezzo in streaming): la memoria non deve cambiarli.
//

import Foundation
import Testing
@testable import AriaLite

struct MarkdownTests {
    private static let sample = """
    ## Check the switch

    Tighten the **terminals** to the `torque` spec.

    - first
    - second

    1. one
    2. two

    | Step | Tool |
    |---|---|
    | 1 | Wrench |

    > careful

    ```
    code line
    ```
    ---
    """

    private func shape(_ blocks: [AriaMarkdown.Block]) -> [String] {
        blocks.map { block in
            switch block {
            case .heading(let level, let text): "heading \(level) \(text)"
            case .paragraph(let text): "paragraph \(text)"
            case .list(let items): "list " + items.map { "\($0.marker)|\($0.text)|\($0.depth)" }.joined(separator: ";")
            case .quote(let text): "quote \(text)"
            case .code(let text): "code \(text)"
            case .table(let header, let rows): "table \(header) \(rows)"
            case .rule: "rule"
            }
        }
    }

    @Test func splitsAnAnswerIntoItsBlocks() {
        let kinds = shape(AriaMarkdown.blocks(Self.sample)).map { $0.split(separator: " ").first.map(String.init) ?? "" }
        #expect(kinds == ["heading", "paragraph", "list", "list", "table", "quote", "code", "rule"])
    }

    @Test func theRememberedResultIsTheSameAsTheFirst() {
        let text = Self.sample + "\n\nunique \(UUID().uuidString)"
        let first = shape(AriaMarkdown.blocks(text))
        let second = shape(AriaMarkdown.blocks(text))
        #expect(first == second)
        #expect(!first.isEmpty)
    }

    @Test func differentTextsDoNotShareAnEntry() {
        #expect(shape(AriaMarkdown.blocks("alpha")) == ["paragraph alpha"])
        #expect(shape(AriaMarkdown.blocks("beta")) == ["paragraph beta"])
        #expect(shape(AriaMarkdown.blocks("alpha")) == ["paragraph alpha"])
    }

    @Test func inlineKeepsBoldAndCodeAndIsStableAcrossCalls() {
        let text = "Use **bold** and `code` here \(UUID().uuidString)"
        let first = AriaMarkdown.inline(text)
        let second = AriaMarkdown.inline(text)
        #expect(first == second)
        #expect(String(first.characters).hasPrefix("Use bold and code here"))
        #expect(first.runs.count > 1, "grassetto e codice sono run a parte")
    }

    @Test func brokenMarkdownFallsBackToThePlainText() {
        let text = "**unclosed `code and _italic"
        #expect(!String(AriaMarkdown.inline(text).characters).isEmpty)
    }
}
