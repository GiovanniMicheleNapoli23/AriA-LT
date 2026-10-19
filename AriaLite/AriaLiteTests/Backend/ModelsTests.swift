//
//  ModelsTests.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 15/10/26.
//
//  Decodifica dei modelli dei lavori: il formato del contratto, le varianti che il server può mandare
//  (decimali delle date, valori sconosciuti, voci come stringa o come oggetto) e i calcoli derivati.
//

import Foundation
import Testing
@testable import AriaLite

struct ModelsTests {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(T.self, from: Data(json.utf8))
    }

    // MARK: Ordini

    @Test func decodesTheContractOrderWithProcedure() throws {
        let json = """
        {"id":"w1","title":"Fix drive","description":"d","type":"reactive","category":"mech","priority":"high",
         "status":"in_progress","assetTag":"A1","plantId":"p1","zone":"Z","scheduledDate":"2026-10-09T08:00:00Z",
         "dueDate":"2026-10-10T08:00:00.5Z","estimatedDurationMin":90,"assignedAt":"2026-10-09T07:00:00.120000Z",
         "assignmentSource":"auto","notes":"n","createdAt":"2026-10-01T00:00:00Z","updatedAt":"2026-10-09T09:12:00.120000Z",
         "progress":{"done":1,"notDone":0,"total":2},
         "procedure":{"steps":[
           {"id":"a1b2c3d4e5f6","number":1,"text":"Isolate","report":{"status":"done","note":null,
             "photos":[{"id":"abc","url":"https://s3/x","mimeType":"image/jpeg"}],"reportedAt":"2026-10-09T09:12:00.120000Z"}},
           {"id":"0b1c2d3e4f50","number":2,"text":"Replace","report":null}],
          "safetyWarnings":["LOTO"],"toolsNeeded":[],"partsNeeded":[],"progress":{"done":1,"notDone":0,"total":2}}}
        """
        let order = try decode(AriaWorkOrder.self, json)
        #expect(order.priorityLevel == .high)
        #expect(order.statusLabel == String(localized: "In progress"))
        #expect(order.estimatedDurationMin == 90)
        #expect(order.progress == AriaProgress(done: 1, notDone: 0, total: 2))
        let procedure = try #require(order.procedure)
        #expect(procedure.steps.count == 2)
        #expect(procedure.steps[0].report?.photos.first?.mimeType == "image/jpeg")
        #expect(procedure.steps[0].report?.reportedAt != nil)
        #expect(procedure.steps[1].report == nil)
        #expect(procedure.safetyWarnings == ["LOTO"])
        #expect(!procedure.isFullyReported)
    }

    @Test func listOrderWithoutProcedureStillDecodes() throws {
        let order = try decode(AriaWorkOrder.self, #"{"id":"1","title":"t","status":"planned"}"#)
        #expect(order.procedure == nil)
        #expect(order.progress == nil)
        #expect(order.priorityLevel == nil)
    }

    @Test func detailTakesProgressFromProcedureWhenMissingAtTopLevel() throws {
        let json = #"{"id":"1","title":"t","status":"assigned","procedure":{"steps":[],"progress":{"done":2,"notDone":1,"total":5}}}"#
        let order = try decode(AriaWorkOrder.self, json)
        #expect(order.progress?.reported == 3)
    }

    @Test func unknownStatusAndTypeFallBackToReadableLabels() throws {
        let order = try decode(AriaWorkOrder.self, #"{"id":"1","title":"t","status":"on_hold","type":"inspection","assignmentSource":"robot"}"#)
        #expect(order.statusLabel == "On Hold")
        #expect(order.typeLabel == "Inspection")
        #expect(order.assignmentLabel == "Robot")
        #expect(!order.isClosed)
    }

    @Test(arguments: ["completed", "verified", "cancelled"])
    func closedStatuses(_ status: String) throws {
        let order = try decode(AriaWorkOrder.self, #"{"id":"1","title":"t","status":"\#(status)","dueDate":"2000-01-01T00:00:00Z"}"#)
        #expect(order.isClosed)
        #expect(!order.isOverdue, "un ordine chiuso non è mai in ritardo")
    }

    @Test func overdueOnlyWhenOpenAndPastDue() throws {
        let past = try decode(AriaWorkOrder.self, #"{"id":"1","title":"t","status":"assigned","dueDate":"2000-01-01T00:00:00Z"}"#)
        let future = try decode(AriaWorkOrder.self, #"{"id":"1","title":"t","status":"assigned","dueDate":"2999-01-01T00:00:00Z"}"#)
        let none = try decode(AriaWorkOrder.self, #"{"id":"1","title":"t","status":"assigned"}"#)
        #expect(past.isOverdue)
        #expect(!future.isOverdue)
        #expect(!none.isOverdue)
    }

    @Test func priorityLevelsAreExactLowercase() throws {
        for (raw, level) in [("high", AriaWorkOrderPriority.high), ("medium", .medium), ("low", .low)] {
            let order = try decode(AriaWorkOrder.self, #"{"id":"1","title":"t","status":"x","priority":"\#(raw)"}"#)
            #expect(order.priorityLevel == level)
        }
        #expect(AriaWorkOrderPriority.high > .medium && AriaWorkOrderPriority.medium > .low)
    }

    // MARK: Lista

    @Test func listAcceptsArrayOrWrappers() throws {
        let item = #"{"id":"1","title":"t","status":"planned"}"#
        #expect(try decode(AriaWorkOrderList.self, "[\(item),\(item)]").orders.count == 2)
        #expect(try decode(AriaWorkOrderList.self, #"{"items":[\#(item)]}"#).orders.count == 1)
        #expect(try decode(AriaWorkOrderList.self, #"{"workOrders":[\#(item)]}"#).orders.count == 1)
        #expect(try decode(AriaWorkOrderList.self, #"{"data":[\#(item)]}"#).orders.count == 1)
        #expect(try decode(AriaWorkOrderList.self, "[]").orders.isEmpty)
    }

    // MARK: Procedura

    @Test func toolsAndPartsAcceptStringsAndObjects() throws {
        let json = #"{"steps":[],"toolsNeeded":["Multimeter",{"name":"Wrench"}],"partsNeeded":[{"text":"Fuse"},{"title":"Breaker"},{"x":1}]}"#
        let procedure = try decode(AriaProcedure.self, json)
        #expect(procedure.toolsNeeded == ["Multimeter", "Wrench"])
        #expect(procedure.partsNeeded == ["Fuse", "Breaker"])
    }

    @Test func plannerTickedStepHasNoNotePhotosOrDate() throws {
        let step = try decode(AriaProcedureStep.self,
                              #"{"id":"a1b2c3d4e5f6","number":1,"text":"x","report":{"status":"done","note":null,"photos":[],"reportedAt":null}}"#)
        let report = try #require(step.report)
        #expect(report.isDone)
        #expect(report.note == nil && report.photos.isEmpty && report.reportedAt == nil)
    }

    @Test func reportWithoutPhotosFieldDefaultsToEmpty() throws {
        let report = try decode(AriaStepReport.self, #"{"status":"not_done","note":"Seized bolt"}"#)
        #expect(!report.isDone)
        #expect(report.photos.isEmpty)
    }

    @Test func fullyReportedNeedsEveryStep() throws {
        let done = #"{"id":"a","number":1,"text":"x","report":{"status":"done","photos":[]}}"#
        let open = #"{"id":"b","number":2,"text":"y","report":null}"#
        #expect(try decode(AriaProcedure.self, #"{"steps":[\#(done)]}"#).isFullyReported)
        #expect(try !decode(AriaProcedure.self, #"{"steps":[\#(done),\#(open)]}"#).isFullyReported)
    }

    @Test(arguments: [
        ("Step 3: Physical Inspection", "Physical Inspection"),
        ("step 12 - Clear jam", "Clear jam"),
        ("Step 1. Isolate", "Isolate"),
        ("  STEP 7) Restart", "Restart"),
        ("Step 2 — Safety Isolation", "Safety Isolation"),
        ("Replace the breaker", "Replace the breaker"),
        ("Stepper motor check", "Stepper motor check"),
        ("Step 4:", "Step 4:"),
    ])
    func displayTextDropsTheStepPrefix(raw: String, shown: String) throws {
        let step = try decode(AriaProcedureStep.self, #"{"id":"a","number":1,"text":"\#(raw)","report":null}"#)
        #expect(step.displayText == shown)
    }

    // MARK: Avanzamento

    @Test func progressFraction() {
        #expect(AriaProgress(done: 1, notDone: 1, total: 4).fraction == 0.5)
        #expect(AriaProgress(done: 0, notDone: 0, total: 0).fraction == 0, "senza passi non si divide per zero")
        #expect(AriaProgress(done: 3, notDone: 2, total: 4).fraction == 1, "non supera mai 1")
        #expect(AriaProgress(done: 2, notDone: 1, total: 5).reported == 3)
    }

    // MARK: Profilo e disponibilità

    @Test func profileDecodesWithEmailAndTolerantAvailability() throws {
        let me = try decode(AriaMobileProfile.self,
                            #"{"id":"1","name":"A","email":"a@b.c","specialties":["electrical"],"availability":"off_duty","availabilityAt":"2026-10-09T07:00:00.1Z"}"#)
        #expect(me.email == "a@b.c")
        #expect(me.availability == .offDuty)
        #expect(me.availabilityAt != nil)
        let unknown = try decode(AriaMobileProfile.self, #"{"id":"1","name":"A","email":"a@b.c","availability":"vacation"}"#)
        #expect(unknown.availability == nil, "un valore nuovo del server non fa fallire il profilo")
        #expect(unknown.specialties.isEmpty)
    }

    @Test func availabilityRawValuesMatchTheContract() {
        #expect(AriaAvailability.allCases.map(\.rawValue) == ["available", "busy", "off_duty"])
    }

    @Test func availabilityBodyHasOnlyTheAvailabilityField() throws {
        let data = try JSONEncoder().encode(AriaAvailabilityBody(availability: .offDuty))
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: String])
        #expect(json == ["availability": "off_duty"])
    }

    // MARK: Date

    @Test(arguments: [
        "2026-10-09T09:12:00Z",
        "2026-10-09T09:12:00.1Z",
        "2026-10-09T09:12:00.120000Z",
        "2026-10-09T09:12:00.123456789Z",
        "2026-10-09T11:12:00+02:00",
        "2026-10-09T11:12:00.120000+02:00",
    ])
    func wireDateAcceptsAnyFractionDigits(raw: String) throws {
        let date = try #require(AriaWireDate.parse(raw))
        #expect(date == AriaWireDate.parse("2026-10-09T09:12:00Z"))
    }

    @Test func wireDateAcceptsDateOnlyAndRejectsGarbage() {
        #expect(AriaWireDate.parse("2026-10-07") != nil)
        #expect(AriaWireDate.parse("not a date") == nil)
        #expect(AriaWireDate.parse("") == nil)
    }
}
