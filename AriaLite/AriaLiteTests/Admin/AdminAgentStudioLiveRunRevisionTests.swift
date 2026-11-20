//
//  AdminAgentStudioLiveRunRevisionTests.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 20/11/26.
//
//  I contatori di versione dello stato di un run in streaming: servono al view model per pubblicare solo ciò
//  che è cambiato (testo e registro a parte, senza copiarli a ogni pubblicazione).
//

import Foundation
import Testing
@testable import AriaLite

struct AdminAgentStudioLiveRunRevisionTests {
    private func line(_ text: String) throws -> AriaJSON {
        try JSONDecoder().decode(AriaJSON.self, from: Data(text.utf8))
    }

    @Test func narrativeDeltasChangeOnlyTheNarrativeRevision() throws {
        var run = AdminAgentStudioLiveRun()
        run.apply(try line(#"{"type":"run-start","runId":"r1","seq":1}"#))
        let display = run.displayRevision
        let events = run.eventsRevision

        run.apply(try line(#"{"type":"narrative-delta","text":"Ciao","seq":2}"#))

        #expect(run.displayRevision == display)
        #expect(run.eventsRevision == events, "i delta di testo non entrano nel registro")
        #expect(run.narrativeRevision == 1)
        #expect(run.narrative == "Ciao")
        #expect(run.lastSeq == 2, "il seq di ripresa avanza comunque")
    }

    @Test func unknownTypesGoOnlyToTheLog() throws {
        var run = AdminAgentStudioLiveRun()
        let display = run.displayRevision

        run.apply(try line(#"{"type":"budget","seq":1}"#))

        #expect(run.displayRevision == display)
        #expect(run.eventsRevision == 1)
        #expect(run.events.count == 1)
    }

    @Test func phaseChangesBumpTheDisplayRevision() throws {
        var run = AdminAgentStudioLiveRun()
        run.apply(try line(#"{"type":"run-start","runId":"r1","seq":1}"#))
        let display = run.displayRevision

        run.apply(try line(#"{"type":"done","status":"completed","seq":2}"#))

        #expect(run.displayRevision > display)
        #expect(!run.isActive)

        var other = AdminAgentStudioLiveRun(runId: "r2")
        let before = other.displayRevision
        other.markFinished(status: "cancelled")
        #expect(other.displayRevision > before)
    }

    @Test func theSnapshotDropsLogAndNarrativeButKeepsTheRest() throws {
        var run = AdminAgentStudioLiveRun()
        run.apply(try line(#"{"type":"run-start","runId":"r1","mode":"run","seq":1}"#))
        run.apply(try line(#"{"type":"narrative-delta","text":"Ciao","seq":2}"#))

        let snapshot = run.displaySnapshot()

        #expect(snapshot.events.isEmpty)
        #expect(snapshot.narrative.isEmpty)
        #expect(snapshot.runId == "r1")
        #expect(snapshot.mode == .run)
        #expect(snapshot.displayRevision == run.displayRevision)
        #expect(run.events.count == 1, "l'originale tiene registro e testo")
        #expect(run.narrative == "Ciao")
    }

    @Test func replayResetNeverMovesTheRevisionsBack() throws {
        var run = AdminAgentStudioLiveRun()
        run.apply(try line(#"{"type":"run-start","runId":"r1","seq":1}"#))
        run.apply(try line(#"{"type":"narrative-delta","text":"Ciao","seq":2}"#))
        let (display, narrative, events) = (run.displayRevision, run.narrativeRevision, run.eventsRevision)

        run.resetForReplay()

        #expect(run.displayRevision > display)
        #expect(run.narrativeRevision > narrative)
        #expect(run.eventsRevision > events)
        #expect(run.narrative.isEmpty)
        #expect(run.runId == "r1")
    }
}
