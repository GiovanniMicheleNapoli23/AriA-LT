//
//  StepTextTests.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 16/10/26.
//
//  AriaStepText: il testo di un passo diviso in etichetta, azione, elenco e indicazioni,
//  con i passi veri della procedura "10B Motor Protection Switch Fault".
//

import Testing
@testable import AriaLite

struct StepTextTests {
    @Test func aSafetyPrefixBecomesATagAndTheSecondSentenceANote() {
        let text = AriaStepText("SAFETY FIRST: Isolate and lock out / tag out (LOTO) the affected motor circuit at the main "
            + "disconnect and the motor control cabinet before beginning any work. Verify absence of voltage with a "
            + "calibrated multimeter on all three phases at the MPS output terminals.")

        #expect(text.tag == "SAFETY FIRST")
        #expect(text.isSafetyTag)
        #expect(text.headline.hasPrefix("Isolate and lock out"))
        #expect(text.headline.hasSuffix("before beginning any work."))
        #expect(text.items.isEmpty)
        #expect(text.notes == ["Verify absence of voltage with a calibrated multimeter on all three phases at the MPS output terminals."])
    }

    @Test func aListAfterTheColonBecomesBullets() {
        let text = AriaStepText("Inspect the motor control cabinet interior for signs of overheating: discolored wiring "
            + "insulation, melted plastic, burn marks, or a burning smell. Check ambient cabinet temperature and verify "
            + "that cabinet ventilation/cooling is functional.")

        #expect(text.tag == nil)
        #expect(text.headline == "Inspect the motor control cabinet interior for signs of overheating:")
        #expect(text.items == ["Discolored wiring insulation", "Melted plastic", "Burn marks", "A burning smell"])
        #expect(text.notes == ["Check ambient cabinet temperature and verify that cabinet ventilation/cooling is functional."])
    }

    @Test func italianListsWork() {
        // In italiano l'ultima voce è unita con "e" senza virgola: resta insieme alla penultima.
        let text = AriaStepText("Controlla i morsetti: serraggio, ossidazione, colore e temperatura.")
        #expect(text.headline == "Controlla i morsetti:")
        #expect(text.items == ["Serraggio", "Ossidazione", "Colore e temperatura"])
    }

    @Test func aColonWithoutARealListStaysOneSentence() {
        let text = AriaStepText("Set the selector to: manual, then wait.")
        #expect(text.items.isEmpty)
        #expect(text.headline == "Set the selector to: manual, then wait.")
    }

    @Test func abbreviationsDoNotSplitTheSentence() {
        let text = AriaStepText("Use a torque wrench, e.g. 25 Nm on the terminals.")
        #expect(text.notes.isEmpty)
        #expect(text.headline == "Use a torque wrench, e.g. 25 Nm on the terminals.")
    }

    @Test func aPlainStepIsJustTheHeadline() {
        let text = AriaStepText("Close the cabinet.")
        #expect(text == AriaStepText(headline: "Close the cabinet."))
    }
}
