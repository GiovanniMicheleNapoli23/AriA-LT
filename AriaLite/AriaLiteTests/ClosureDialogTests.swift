//
//  ClosureDialogTests.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 16/10/26.
//
//  Conferma di fine procedura: il server la manda con `reason: closure_confirmation` e si aspetta
//  "<label>. Reason: <codice>. Details: <nota>" con l'etichetta canonica in testa (come composeClosureAnswer della web).
//

import Foundation
import Testing
@testable import AriaLite

struct ClosureDialogTests {
    @Test func theLabelLeadsThenTheReasonCodeThenTheOperatorsWords() {
        let answer = AriaElicitationPanel.closureAnswer(
            label: "Yes, end the procedure", reason: "missing_parts", details: "  Manca il cuscinetto 6205 ")
        #expect(answer == "Yes, end the procedure. Reason: missing_parts. Details: Manca il cuscinetto 6205")
    }

    @Test func detailsAreOptionalAndATrailingDotOfTheLabelIsNotDoubled() {
        #expect(AriaElicitationPanel.closureAnswer(label: "Yes, end the procedure.", reason: "shift_end", details: " ")
                == "Yes, end the procedure. Reason: shift_end")
        #expect(AriaElicitationPanel.closureAnswer(label: "Yes, end the procedure", reason: "", details: "")
                == "Yes, end the procedure")
    }

    @Test func everyReasonCodeIsOneOfTheSixteenTheServerKnows() {
        let server = ["cannot_proceed", "work_alone", "waiting_specialist", "vendor", "missing_parts", "missing_tools",
                      "unsafe", "false_alarm", "documentation", "wrong_answers", "ui_bug", "production_priority",
                      "reassigned", "shift_end", "personal_emergency", "other"]
        #expect(AriaClosureReason.allCases.map(\.rawValue) == server)
        #expect(AriaClosureReason.allCases.allSatisfy { !$0.label.isEmpty })
    }

    @Test func theClosurePanelIsRecognisedByItsReason() throws {
        let json = """
        {"id":"e1","question":"Vuoi davvero terminare?","mode":"single","allow_custom":false,
         "options":[{"id":"o1","label":"Yes, end the procedure","value":"end"},
                    {"id":"o2","label":"No, continue the procedure","value":"continue"}],
         "reason":"closure_confirmation","variant":"procedure","locale":"it"}
        """
        let panel = try JSONDecoder().decode(AriaElicitation.self, from: Data(json.utf8))
        #expect(panel.isClosureConfirmation)
        #expect(panel.options.first?.value == "end")

        let plain = try JSONDecoder().decode(
            AriaElicitation.self, from: Data(#"{"id":"e2","question":"q","options":[]}"#.utf8))
        #expect(!plain.isClosureConfirmation)
    }
}
