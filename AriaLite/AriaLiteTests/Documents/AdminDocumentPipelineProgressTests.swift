//
//  AdminDocumentPipelineProgressTests.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 27/10/26.
//
//  L'avanzamento delle pipeline del documento: dallo stato grezzo al passo e alla frazione, l'affinamento
//  con i lotti della run attiva e la lettura delle fasi (StageResponse) che il server manda con `name`/`state`.
//

import Foundation
import Testing
@testable import AriaLite

struct AdminDocumentPipelineProgressTests {
    private func progress(_ pipeline: AdminDocumentPipeline, _ raw: String, run: AdminDocumentRun? = nil) -> AdminDocumentPipelineProgress {
        AdminDocumentPipelineProgress(pipeline: pipeline, rawState: raw, activeRun: run)
    }

    private func run(_ json: String) throws -> AdminDocumentRun {
        try JSONDecoder().decode(AdminDocumentRun.self, from: Data(json.utf8))
    }

    @Test func ingestionStepsAdvanceOneFifthAtATime() {
        let expected: [(String, Int)] = [("fetching", 1), ("parsing", 2), ("chunking", 3), ("embedding", 4), ("indexing", 5)]
        for (raw, step) in expected {
            let p = progress(.ingestion, raw)
            #expect(p.phase == .running)
            #expect(p.step == step)
            #expect(p.stepCount == 5)
            #expect(p.fraction == Double(step - 1) / 5)
            #expect(p.isActive)
        }
    }

    @Test func extractionHasSixSteps() {
        let p = progress(.extraction, "validating")
        #expect(p.step == 5)
        #expect(p.stepCount == 6)
        #expect(p.fraction == 4.0 / 6)
        #expect(progress(.extraction, "classifying").step == 3)
    }

    @Test func queuedIsZeroAndCompletedIsOne() {
        let queued = progress(.ingestion, "queued")
        #expect(queued.phase == .queued)
        #expect(queued.fraction == 0)
        #expect(queued.step == 0)
        #expect(queued.isActive)
        #expect(queued.label == AdminDocumentState.queued.label)

        let done = progress(.extraction, "completed")
        #expect(done.isFinished)
        #expect(done.fraction == 1)
        #expect(!done.isActive)
    }

    @Test func failedAndCanceledHaveNoFraction() {
        let failed = progress(.ingestion, "failed")
        #expect(failed.isFailed)
        #expect(failed.fraction == nil)
        #expect(!failed.isActive)

        let canceled = progress(.extraction, "canceled")
        #expect(canceled.isCanceled)
        #expect(canceled.fraction == nil)
    }

    @Test func unknownOrForeignStatesAreIndeterminate() {
        // Sconosciuto: etichetta dal valore grezzo.
        let unknown = progress(.ingestion, "new_state")
        #expect(unknown.phase == .other)
        #expect(unknown.fraction == nil)
        #expect(unknown.label == "New state")
        #expect(unknown.caption() == "New state")

        // Uno stato noto ma che non è un passo di quella pipeline.
        let foreign = progress(.ingestion, "classifying")
        #expect(foreign.fraction == nil)
        #expect(foreign.label == AdminDocumentState.classifying.label)

        #expect(progress(.ingestion, "paused").fraction == nil)
        #expect(progress(.ingestion, "pending_deletion").isActive == false)
    }

    @Test func captionShowsStepOfCountAndTheLabel() {
        let p = progress(.ingestion, "chunking")
        #expect(p.caption() == String(localized: "Step \(3) of \(5)") + " · " + AdminDocumentState.chunking.label)
        #expect(p.caption(showingPipeline: true).hasPrefix(AdminDocumentPipeline.ingestion.title + " · "))
        #expect(progress(.ingestion, "queued").caption() == AdminDocumentState.queued.label)
    }

    @Test func batchesOfTheActiveRunRefineTheCurrentStep() throws {
        let embedding = try run(#"""
        {"id":"r1","pipelineType":"ingestion","state":"running","stages":[
          {"name":"parsing","state":"completed"},
          {"name":"embedding","state":"running","metrics":{"batchesDone":3,"totalBatches":10}}]}
        """#)
        let p = progress(.ingestion, "embedding", run: embedding)
        // Tre passi fatti più tre decimi del quarto, su cinque.
        #expect(abs((p.fraction ?? -1) - (3.3 / 5)) < 1e-9)
        #expect(p.step == 4)
    }

    @Test func aRunOnAnotherStepOrWithoutBatchesDoesNotRefine() throws {
        let behind = try run(#"""
        {"id":"r1","pipelineType":"ingestion","state":"running","stages":[
          {"name":"embedding","state":"running","metrics":{"batchesDone":9,"totalBatches":10}}]}
        """#)
        #expect(progress(.ingestion, "chunking", run: behind).fraction == 2.0 / 5)

        let noBatches = try run(#"""
        {"id":"r2","pipelineType":"ingestion","state":"running","stages":[{"name":"embedding","state":"running","metrics":{"totalBatches":0}}]}
        """#)
        #expect(progress(.ingestion, "embedding", run: noBatches).fraction == 3.0 / 5)

        let finished = try run(#"""
        {"id":"r3","pipelineType":"ingestion","state":"completed","stages":[{"name":"embedding","state":"running","metrics":{"batchesDone":5,"totalBatches":10}}]}
        """#)
        #expect(progress(.ingestion, "embedding", run: finished).fraction == 3.0 / 5)
    }

    @Test func aRunStageDecodesNameStateAndBatches() throws {
        let json = #"{"name":"embedding","state":"running","metrics":{"batchesDone":3,"totalBatches":10}}"#
        let stage = try JSONDecoder().decode(AdminDocumentRunStage.self, from: Data(json.utf8))
        #expect(stage.stage == "embedding")
        #expect(stage.status == "running")
        #expect(stage.isRunning)
        #expect(!stage.isDone)
        #expect(!stage.isFailed)
        #expect(stage.batchesDone == 3)
        #expect(stage.totalBatches == 10)
        #expect(stage.label == AdminDocumentState.embedding.label)
    }

    @Test func stageStatesAreRecognised() throws {
        func stage(_ json: String) throws -> AdminDocumentRunStage {
            try JSONDecoder().decode(AdminDocumentRunStage.self, from: Data(json.utf8))
        }
        #expect(try stage(#"{"name":"parsing","state":"completed"}"#).isDone)
        #expect(try stage(#"{"name":"parsing","state":"skipped"}"#).isDone)
        #expect(try stage(#"{"name":"parsing","state":"failed"}"#).isFailed)
        #expect(try stage(#"{"name":"parsing","state":"running","error":{"code":"x","message":"Boom"}}"#).isFailed)
        #expect(try stage(#"{"name":"parsing","state":"in_progress"}"#).isRunning)
        // Chiavi vecchie come ripiego.
        #expect(try stage(#"{"stage":"parsing","status":"completed"}"#).isDone)
    }

    @Test func aRunKeepsItsStagesNow() throws {
        let failedRun = try run(#"{"id":"r1","pipelineType":"extraction","state":"failed","stages":[{"name":"parsing","state":"completed"},{"name":"extracting","state":"failed","error":{"code":"e","message":"Bad"}}]}"#)
        #expect(failedRun.stages.count == 2)
        #expect(failedRun.stages.first(where: \.isFailed)?.error == "Bad")
    }

    @Test func aDocumentShowsOnlyItsActivePipelines() throws {
        let json = #"{"id":"d1","status":{"ingestionState":"embedding","extractionState":"completed"}}"#
        let document = try JSONDecoder().decode(AdminDocument.self, from: Data(json.utf8))
        #expect(document.activeProgress.map(\.pipeline) == [.ingestion])
        #expect(document.progress(for: .extraction) == nil)

        let both = try JSONDecoder().decode(AdminDocument.self, from: Data(#"{"id":"d2","status":{"ingestionState":"queued","extractionState":"parsing"}}"#.utf8))
        #expect(both.activeProgress.map(\.pipeline) == [.ingestion, .extraction])
    }
}
