//
//  FormattedTextTests.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 16/10/26.
//
//  AriaFormattedText: descrizione e note di un ordine divise in titoli, elenchi, campi e paragrafi.
//

import Testing
@testable import AriaLite

struct FormattedTextTests {
    @Test func headingsListsAndFieldsBecomeBlocks() {
        let blocks = AriaFormattedText.parse("""
        Motor protection switch tripped twice.

        SYMPTOMS
        - Motor stops after 3 minutes
        • Burning smell

        Asset: Motor 10B
        Zone: Packaging line 2

        Actions:
        1) Isolate the circuit
        2. Check the overload setting
        """)

        #expect(blocks == [
            .paragraph("Motor protection switch tripped twice."),
            .heading("SYMPTOMS"),
            .bullets(["Motor stops after 3 minutes", "Burning smell"]),
            .fields([.init(label: "Asset", value: "Motor 10B"), .init(label: "Zone", value: "Packaging line 2")]),
            .heading("Actions"),
            .numbered(["Isolate the circuit", "Check the overload setting"]),
        ])
    }

    @Test func aSentenceWithAColonIsNotAField() {
        // Più di quattro parole prima dei due punti: è una frase, non un'etichetta.
        let blocks = AriaFormattedText.parse("The operator reported the following on the night shift: motor stopped.")
        #expect(blocks == [.paragraph("The operator reported the following on the night shift: motor stopped.")])
    }

    @Test func aTimeIsNotAField() {
        #expect(AriaFormattedText.parse("Tripped at 10:30 on Monday.") == [.paragraph("Tripped at 10:30 on Monday.")])
    }

    @Test func aWrappedBulletContinuesTheItem() {
        let blocks = AriaFormattedText.parse("- Check the cabinet\n  ventilation and filters\n- Reset the switch")
        #expect(blocks == [.bullets(["Check the cabinet ventilation and filters", "Reset the switch"])])
    }

    @Test func aVeryLongLineIsSplitIntoSentenceGroups() {
        let sentence = "The motor protection switch tripped during the night shift and was reset by the operator."
        let blocks = AriaFormattedText.parse(Array(repeating: sentence, count: 5).joined(separator: " "))

        #expect(blocks.count > 1)
        for case .paragraph(let text) in blocks { #expect(text.hasSuffix(".")) }
    }

    @Test func markdownHeadingsLoseTheirMarkers() {
        #expect(AriaFormattedText.parse("## Root cause\nWorn contacts.") == [.heading("Root cause"), .paragraph("Worn contacts.")])
    }
}
