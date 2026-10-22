//
//  WorkOrderOverlayTests.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 19/10/26.
//
//  AriaWorkOrderOverlay: come le modifiche in coda si vedono sull'ordine salvato, come si fondono
//  (meno chiamate, stesso risultato) e come si uniscono lista e dettaglio dello stesso ordine.
//

import Foundation
import Testing
@testable import AriaLite

struct WorkOrderOverlayTests {
    private let at = Date(timeIntervalSince1970: 1_790_000_000)

    private func order(reported: Int = 0, status: String = "assigned", photos: Bool = false) throws -> AriaJSON {
        var json = TestEnv.orderJSON(status: status, withProcedure: true, reported: reported)
        if photos {
            json = json.replacingOccurrences(of: #""photos":[]"#, with: #""photos":[{"id":"p1","url":null,"mimeType":"image/jpeg"}]"#)
        }
        return try JSONDecoder().decode(AriaJSON.self, from: Data(json.utf8))
    }

    private func decode(_ json: AriaJSON) throws -> AriaWorkOrder {
        try json.decoded(as: AriaWorkOrder.self)
    }

    private func queued(_ change: AriaPendingChange) -> AriaQueuedChange {
        AriaQueuedChange(id: UUID(), orderId: "o1", change: change)
    }

    // MARK: Applicazione

    @Test func aResultShowsOnTheStepUpdatesProgressAndStartsTheOrder() throws {
        let result = try decode(AriaWorkOrderOverlay.apply(
            [.report(stepId: "s1", status: "done", note: "ok", at: at)], to: try order()))
        let step = try #require(result.procedure?.steps.first)
        #expect(step.report?.isDone == true)
        #expect(step.report?.note == "ok")
        #expect(step.report?.reportedAt == at)
        #expect(result.progress == result.procedure?.progress)
        #expect(result.progress?.done == 1 && result.progress?.total == 2)
        #expect(result.status == "in_progress", "il primo risultato porta l'ordine in corso, come sul server")
    }

    @Test func changingTheResultKeepsThePhotosAlreadyUploaded() throws {
        let result = try decode(AriaWorkOrderOverlay.apply(
            [.report(stepId: "s1", status: "not_done", note: "rotto", at: at)], to: try order(reported: 1, photos: true)))
        let report = try #require(result.procedure?.steps.first?.report)
        #expect(report.status == "not_done")
        #expect(report.photos.map(\.id) == ["p1"])
        #expect(result.progress?.notDone == 1 && result.progress?.done == 0)
    }

    @Test func clearingRemovesTheResultAndRemovingAPhotoRemovesOnlyThatPhoto() throws {
        let cleared = try decode(AriaWorkOrderOverlay.apply([.clearReport(stepId: "s1")], to: try order(reported: 1)))
        #expect(cleared.procedure?.steps.first?.report == nil)
        #expect(cleared.progress?.reported == 0)

        let withoutPhoto = try decode(AriaWorkOrderOverlay.apply([.removePhoto(stepId: "s1", photoId: "p1")],
                                                                 to: try order(reported: 1, photos: true)))
        #expect(withoutPhoto.procedure?.steps.first?.report?.photos.isEmpty == true)
        #expect(withoutPhoto.procedure?.steps.first?.report?.isDone == true)
    }

    @Test func completingClosesTheOrder() throws {
        let result = try decode(AriaWorkOrderOverlay.apply([.complete(notes: "Sostituito", at: at)], to: try order(reported: 2)))
        #expect(result.isClosed)
        #expect(result.status == "completed")
        #expect(result.updatedAt == at)
    }

    @Test func changesApplyInOrder() throws {
        let result = try decode(AriaWorkOrderOverlay.apply([
            .report(stepId: "s1", status: "done", note: nil, at: at),
            .clearReport(stepId: "s1"),
            .report(stepId: "s2", status: "done", note: nil, at: at),
        ], to: try order()))
        #expect(result.procedure?.steps.map { $0.report != nil } == [false, true])
    }

    @Test func anOrderWithoutProcedureOnlyChangesItsStatus() throws {
        let list = try JSONDecoder().decode(AriaJSON.self, from: Data(TestEnv.orderJSON().utf8))
        let result = try decode(AriaWorkOrderOverlay.apply([.complete(notes: "x", at: at)], to: list))
        #expect(result.isClosed && result.procedure == nil)
        #expect(result.progress?.total == 2, "senza passi l'avanzamento resta quello del server")
    }

    // MARK: Fusione della coda

    @Test func aSecondResultForTheSameStepReplacesTheFirst() {
        let first = queued(.report(stepId: "s1", status: "done", note: nil, at: at))
        let plan = AriaWorkOrderOverlay.plan(.report(stepId: "s1", status: "not_done", note: "x", at: at),
                                             queue: [first], serverHasReport: { _ in false })
        #expect(plan == .init(drop: [], replace: first.id, enqueue: true))
    }

    @Test func aResultAfterAClearIsNotMergedIntoIt() {
        // DELETE toglie anche le foto, il PUT no: non sono la stessa cosa.
        let clear = queued(.clearReport(stepId: "s1"))
        let plan = AriaWorkOrderOverlay.plan(.report(stepId: "s1", status: "done", note: nil, at: at),
                                             queue: [clear], serverHasReport: { _ in true })
        #expect(plan.replace == nil && plan.enqueue)
    }

    @Test func clearingWhatNeverLeftCancelsEverythingForThatStep() {
        let report = queued(.report(stepId: "s1", status: "done", note: nil, at: at))
        let photo = queued(.addPhoto(stepId: "s1", localId: "local-a"))
        let other = queued(.report(stepId: "s2", status: "done", note: nil, at: at))
        let plan = AriaWorkOrderOverlay.plan(.clearReport(stepId: "s1"), queue: [report, photo, other],
                                             serverHasReport: { _ in false })
        #expect(Set(plan.drop) == [report.id, photo.id])
        #expect(!plan.enqueue, "sul server non c'è niente da togliere: nessuna chiamata")
    }

    @Test func clearingAResultThatIsOnTheServerStillSendsTheDelete() {
        let report = queued(.report(stepId: "s1", status: "done", note: nil, at: at))
        let plan = AriaWorkOrderOverlay.plan(.clearReport(stepId: "s1"), queue: [report], serverHasReport: { $0 == "s1" })
        #expect(plan.drop == [report.id])
        #expect(plan.enqueue)
    }

    @Test func removingAPhotoThatNeverLeftJustDropsIt() {
        let photo = queued(.addPhoto(stepId: "s1", localId: "local-a"))
        let plan = AriaWorkOrderOverlay.plan(.removePhoto(stepId: "s1", photoId: "local-a"), queue: [photo],
                                             serverHasReport: { _ in true })
        #expect(plan == .init(drop: [photo.id], replace: nil, enqueue: false))
    }

    @Test func removingAServerPhotoIsQueued() {
        let plan = AriaWorkOrderOverlay.plan(.removePhoto(stepId: "s1", photoId: "p1"), queue: [], serverHasReport: { _ in true })
        #expect(plan == .init())
    }

    // MARK: Lista + dettaglio

    @Test func theMoreRecentlyUpdatedCopyWinsButTheProcedureStays() throws {
        let list = try JSONDecoder().decode(AriaJSON.self, from: Data(
            TestEnv.orderJSON(status: "in_progress", title: "Nuovo", updatedAt: "2026-10-19T10:00:00Z").utf8))
        let detail = try JSONDecoder().decode(AriaJSON.self, from: Data(
            TestEnv.orderJSON(title: "Vecchio", withProcedure: true, updatedAt: "2026-10-18T10:00:00Z").utf8))
        let merged = try decode(try #require(AriaWorkOrderOverlay.merge(
            list: list, listFetchedAt: .now, detail: detail, detailFetchedAt: .distantPast)))
        #expect(merged.title == "Nuovo" && merged.status == "in_progress")
        #expect(merged.procedure?.steps.count == 2, "offline meglio passi un po' vecchi che niente")
    }

    @Test func withoutDatesTheLastDownloadedWins() throws {
        let list = try JSONDecoder().decode(AriaJSON.self, from: Data(TestEnv.orderJSON(title: "Lista").utf8))
        let detail = try JSONDecoder().decode(AriaJSON.self, from: Data(TestEnv.orderJSON(title: "Dettaglio", withProcedure: true).utf8))
        let merged = try decode(try #require(AriaWorkOrderOverlay.merge(
            list: list, listFetchedAt: Date(timeIntervalSince1970: 1), detail: detail, detailFetchedAt: Date(timeIntervalSince1970: 2))))
        #expect(merged.title == "Dettaglio")
    }

    @Test func listResponsesAreReadInEveryShape() {
        let item = TestEnv.orderJSON()
        for body in ["[\(item)]", #"{"items":[\#(item)]}"#, #"{"workOrders":[\#(item)]}"#, #"{"data":[\#(item)]}"#] {
            #expect(AriaWorkOrderOverlay.orders(inList: Data(body.utf8))?.count == 1, "\(body)")
        }
    }
}
