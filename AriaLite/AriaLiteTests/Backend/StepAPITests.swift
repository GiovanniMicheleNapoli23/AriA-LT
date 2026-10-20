//
//  StepAPITests.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 15/10/26.
//
//  Passi, foto e completamento (AriaWorkOrderAPI): percorsi, body, controlli locali che evitano un giro
//  a vuoto, upload multipart verso S3 e codici d'errore del server.
//

import Foundation
import Testing
@testable import AriaLite

extension BackendTests {
    @Suite("Steps, photos, completion")
    struct StepAPI {
        private let server = StubServer.shared
        private let stepPath = "/v1/work-orders/o1/steps/s1"

        init() { TestEnv.reset() }

        // MARK: Risultato di un passo

        @Test func doneWithoutANoteSendsOnlyTheStatus() async throws {
            let client = try await TestEnv.signedInClient()
            server.route("PUT \(stepPath)", .json(TestEnv.stepReportJSON()))

            let step = try await client.report(.done(note: nil), step: "s1", of: "o1")

            #expect(step.isDone, "il PUT risponde col risultato al livello più alto")
            let call = try #require(server.calls("PUT \(stepPath)").first)
            #expect(call.host == TestEnv.apiHost)
            #expect(call.json as? [String: String] == ["status": "done"], "la nota facoltativa non compare")
            #expect(call.header("company-id") == "c1")
        }

        @Test func noteIsTrimmedAndEmptyDoneNoteIsDropped() async throws {
            let client = try await TestEnv.signedInClient()
            server.route("PUT \(stepPath)", .json(TestEnv.stepReportJSON()))
            _ = try await client.report(.done(note: "  checked  "), step: "s1", of: "o1")
            _ = try await client.report(.done(note: "   "), step: "s1", of: "o1")
            let calls = server.calls("PUT \(stepPath)")
            #expect(calls[0].json as? [String: String] == ["status": "done", "note": "checked"])
            #expect(calls[1].json as? [String: String] == ["status": "done"])
        }

        @Test func notDoneSendsTheReason() async throws {
            let client = try await TestEnv.signedInClient()
            server.route("PUT \(stepPath)", .json(TestEnv.stepReportJSON(status: "not_done", note: "Seized bolt")))
            let step = try await client.report(.notDone(note: "Seized bolt"), step: "s1", of: "o1")
            #expect(step.status == "not_done" && step.note == "Seized bolt")
            #expect(server.calls("PUT \(stepPath)").first?.json as? [String: String] == ["status": "not_done", "note": "Seized bolt"])
        }

        @Test func notDoneWithoutAReasonNeverReachesTheServer() async throws {
            let client = try await TestEnv.signedInClient()
            let before = server.calls.count
            for blank in ["", "   ", "\n"] {
                await #expect { try await client.report(.notDone(note: blank), step: "s1", of: "o1") } throws: { error in
                    (error as? AriaError)?.serverCode == .noteRequired
                }
            }
            #expect(server.calls.count == before)
        }

        @Test func noteOverTheLimitNeverReachesTheServer() async throws {
            let client = try await TestEnv.signedInClient()
            let before = server.calls.count
            await #expect { try await client.report(.done(note: String(repeating: "a", count: 2001)), step: "s1", of: "o1") } throws: { error in
                (error as? AriaError)?.serverCode == .noteTooLong
            }
            #expect(server.calls.count == before)
            server.route("PUT \(stepPath)", .json(TestEnv.stepReportJSON()))
            _ = try await client.report(.done(note: String(repeating: "a", count: 2000)), step: "s1", of: "o1")
        }

        @Test func clearingAResultIsADeleteAnd204IsSuccess() async throws {
            let client = try await TestEnv.signedInClient()
            server.route("DELETE \(stepPath)", .noContent)
            try await client.clearReport(step: "s1", of: "o1")
            #expect(server.calls("DELETE \(stepPath)").count == 1)
        }

        @Test(arguments: [
            (409, "work_order_closed", AriaServerCode.workOrderClosed),
            (404, "step_not_found", .stepNotFound),
            (422, "note_required", .noteRequired),
            (422, "note_too_long", .noteTooLong),
        ])
        func serverCodesOnTheStepEndpointBecomeTypedErrors(status: Int, code: String, expected: AriaServerCode) async throws {
            let client = try await TestEnv.signedInClient()
            server.route("PUT \(stepPath)", .json(#"{"detail":{"code":"\#(code)","message":"m"}}"#, status: status))
            await #expect { try await client.report(.done(note: nil), step: "s1", of: "o1") } throws: { error in
                (error as? AriaError)?.serverCode == expected
            }
        }

        @Test func orderNotOwnedIsAPlain404() async throws {
            let client = try await TestEnv.signedInClient()
            server.route("PUT \(stepPath)", .json(#"{"detail":"Not found"}"#, status: 404))
            await #expect { try await client.report(.done(note: nil), step: "s1", of: "o1") } throws: { error in
                if case AriaError.http(404, _) = error { true } else { false }
            }
        }

        @Test func fetchingAnOrderUsesTheDetailEndpointWithTheProcedure() async throws {
            let client = try await TestEnv.signedInClient()
            server.route("GET /v1/work-orders/o1", .json(TestEnv.orderJSON(withProcedure: true, reported: 1)))
            let order = try await client.workOrder(id: "o1")
            #expect(order.procedure?.steps.count == 2)
            #expect(order.progress?.reported == 1)
            #expect(server.calls("GET /v1/work-orders/o1").first?.query == "include=procedure")
        }

        @Test func snakeCaseOnTheWireDecodesLikeCamelCase() async throws {
            let client = try await TestEnv.signedInClient()
            let wire = #"""
            {"id":"o1","title":"Fix","status":"assigned","priority":"high","asset_tag":"PUMP-1","plant_id":"p1",
             "due_date":"2026-10-30T10:00:00Z","step_progress":{"done":1,"not_done":1,"total":3},
             "procedure":{"steps":[{"id":"a1b2c3d4e5f6","number":1,"text":"Isolate","report":
                 {"status":"not_done","note":"Seized","photos":[{"photo_id":"ph1","url":"https://s3.test/p.jpg","mime_type":"image/jpeg"}],
                  "reported_at":"2026-10-09T09:12:00.5Z"}}],
              "safety_warnings":["LOTO"],"tools_needed":["Puller"],"parts_needed":[],"progress":{"done":0,"not_done":1,"total":1}}}
            """#
            server.route("GET /v1/work-orders/o1", .json(wire))

            let order = try await client.workOrder(id: "o1")

            #expect(order.assetTag == "PUMP-1" && order.plantId == "p1" && order.dueDate != nil)
            #expect(order.procedure?.safetyWarnings == ["LOTO"] && order.procedure?.toolsNeeded == ["Puller"])
            let report = try #require(order.procedure?.steps.first?.report)
            #expect(report.status == "not_done" && report.reportedAt != nil)
            #expect(report.photos.map(\.id) == ["ph1"] && report.photos.first?.mimeType == "image/jpeg")
        }

        @Test func theListCarriesStepProgressAndPagesUntilAShortPage() async throws {
            let client = try await TestEnv.signedInClient()
            func page(_ ids: [String]) -> Reply {
                .json("[" + ids.map { #"{"id":"\#($0)","title":"T","status":"assigned","step_progress":{"done":1,"not_done":0,"total":2}}"# }.joined(separator: ",") + "]")
            }
            server.route("GET /v1/work-orders?status_group=open&limit=2&offset=0", page(["a", "b"]))
            server.route("GET /v1/work-orders?status_group=open&limit=2&offset=2", page(["b", "c"]))
            server.route("GET /v1/work-orders?status_group=open&limit=2&offset=4", page(["d"]))

            let orders = try await client.workOrders(.open, pageSize: 2)

            #expect(orders.compactMap { $0["id"]?.stringValue } == ["a", "b", "c", "d"], "un ordine visto due volte resta uno")
            let decoded = try orders.map { try $0.decoded(as: AriaWorkOrder.self) }
            #expect(decoded.first?.progress == AriaProgress(done: 1, notDone: 0, total: 2), "step_progress della lista")
            #expect(server.calls("GET /v1/work-orders").count == 3)
        }

        @Test func closedOrdersAreOnePageOfTwoHundred() async throws {
            let client = try await TestEnv.signedInClient()
            server.route("GET /v1/work-orders?status_group=closed&limit=200&offset=0", .json("[]"))
            let orders = try await client.workOrders(.closed, pageSize: 200, maxPages: 1)
            #expect(orders.isEmpty)
            #expect(server.calls("GET /v1/work-orders").count == 1)
        }

        // MARK: Foto

        private let ticket = #"{"photo_id":"p1","upload":{"url":"https://s3.test/bucket","fields":{"key":"k/1.jpg","policy":"POL","x-amz-signature":"SIG","Content-Type":"image/jpeg"}},"expires_in":300}"#

        @Test func photoFlowRequestsUploadsThenConfirms() async throws {
            let client = try await TestEnv.signedInClient()
            let photosPath = "\(stepPath)/photos"
            server.route("POST \(photosPath)", .json(ticket, status: 201))
            server.route("POST /bucket", .noContent)
            server.route("POST \(photosPath)/p1/confirm", .json(TestEnv.stepJSON()))
            let jpeg = Data(repeating: 0xAB, count: 4321)

            _ = try await client.addPhoto(jpeg: jpeg, step: "s1", of: "o1")

            let request = try #require(server.calls("POST \(photosPath)").first)
            #expect(request.json?["mime_type"] as? String == "image/jpeg")
            #expect(request.json?["size_bytes"] as? Int == 4321)
            #expect(request.header("authorization") != nil)

            let upload = try #require(server.calls("POST /bucket").first)
            #expect(upload.host == "s3.test")
            #expect(upload.header("authorization") == nil, "S3 non è il nostro host: niente Authorization")
            #expect(upload.header("company-id") == nil)
            #expect(upload.header("content-type")?.hasPrefix("multipart/form-data; boundary=") == true)

            let confirm = try #require(server.calls("POST \(photosPath)/p1/confirm").first)
            #expect(confirm.header("authorization") != nil)
            #expect(confirm.host == TestEnv.apiHost)
            #expect(confirm.body.isEmpty, "la conferma non ha body")

            // Ordine delle chiamate: permesso, upload, conferma.
            let order = server.calls.map { "\($0.method) \($0.path)" }.filter { $0.contains("photos") || $0 == "POST /bucket" }
            #expect(order == ["POST \(photosPath)", "POST /bucket", "POST \(photosPath)/p1/confirm"])
        }

        @Test func multipartPutsEveryFieldFirstAndTheFileLast() async throws {
            let client = try await TestEnv.signedInClient()
            server.route("POST \(stepPath)/photos", .json(ticket, status: 201))
            server.route("POST /bucket", .noContent)
            server.route("POST \(stepPath)/photos/p1/confirm", .json(TestEnv.stepJSON()))

            _ = try await client.addPhoto(jpeg: Data(repeating: 0x41, count: 1000), step: "s1", of: "o1")

            let body = try #require(server.calls("POST /bucket").first).bodyText
            let fileRange = try #require(body.range(of: #"name="file""#))
            for field in ["key", "policy", "x-amz-signature", "Content-Type"] {
                let range = try #require(body.range(of: #"name="\#(field)""#), "manca il campo \(field)")
                #expect(range.lowerBound < fileRange.lowerBound, "\(field) deve venire prima del file")
            }
            #expect(body.contains("k/1.jpg") && body.contains("POL") && body.contains("SIG"))
            let afterFile = String(body[fileRange.lowerBound...])
            #expect(afterFile.contains("Content-Type: image/jpeg"), "il file dichiara lo stesso mimeType del permesso")
            #expect(body.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("--"), "il body è chiuso dal boundary finale")
        }

        @Test func failedUploadStopsBeforeConfirming() async throws {
            let client = try await TestEnv.signedInClient()
            server.route("POST \(stepPath)/photos", .json(ticket, status: 201))
            server.route("POST /bucket", Reply(status: 403, body: Data("<Error>SignatureDoesNotMatch</Error>".utf8)))
            await #expect { try await client.addPhoto(jpeg: Data(count: 10), step: "s1", of: "o1") } throws: { error in
                if case AriaError.http(403, _) = error { true } else { false }
            }
            #expect(server.calls("POST \(stepPath)/photos/p1/confirm").isEmpty)
        }

        @Test(arguments: [
            "http://s3.test/bucket", "ftp://s3.test/bucket", "file:///tmp/bucket",
        ])
        func uploadOverAnythingButHTTPSIsRefusedBeforeAnyRequest(_ url: String) async throws {
            let client = try await TestEnv.signedInClient()
            let insecure = ticket.replacingOccurrences(of: "https://s3.test/bucket", with: url)
            server.route("POST \(stepPath)/photos", .json(insecure, status: 201))
            server.route("POST /bucket", .noContent)
            server.route("POST \(stepPath)/photos/p1/confirm", .json(TestEnv.stepJSON()))
            await #expect { try await client.addPhoto(jpeg: Data(count: 10), step: "s1", of: "o1") } throws: { error in
                if case AriaError.decoding = error { true } else { false }
            }
            #expect(server.calls("POST /bucket").isEmpty, "niente richiesta all'URL non https")
            #expect(server.calls("POST \(stepPath)/photos/p1/confirm").isEmpty)
        }

        @Test func uploadFieldsThatBreakTheMultipartAreRefused() async throws {
            let client = try await TestEnv.signedInClient()
            let broken = [
                #"{"k\"ey":"v"}"#, #"{"k\r\ney":"v"}"#, #"{"key":"v\r\n--x"}"#, #"{"key":"v\nw"}"#,
            ]
            for fields in broken {
                let bad = ticket.replacingOccurrences(
                    of: #"{"key":"k/1.jpg","policy":"POL","x-amz-signature":"SIG","Content-Type":"image/jpeg"}"#, with: fields)
                server.route("POST \(stepPath)/photos", .json(bad, status: 201))
                server.route("POST /bucket", .noContent)
                await #expect { try await client.addPhoto(jpeg: Data(count: 10), step: "s1", of: "o1") } throws: { error in
                    if case AriaError.decoding = error { true } else { false }
                }
            }
            #expect(server.calls("POST /bucket").isEmpty)
            #expect(server.calls("POST \(stepPath)/photos/p1/confirm").isEmpty)
        }

        @Test func photoOverTheLimitNeverReachesTheServer() async throws {
            let client = try await TestEnv.signedInClient()
            let before = server.calls.count
            await #expect { try await client.addPhoto(jpeg: Data(count: 10 * 1024 * 1024 + 1), step: "s1", of: "o1") } throws: { error in
                (error as? AriaError)?.serverCode == .photoTooLarge
            }
            #expect(server.calls.count == before)
        }

        @Test(arguments: [
            (409, "step_not_reported", AriaServerCode.stepNotReported),
            (409, "photo_limit_reached", .photoLimitReached),
            (422, "unsupported_media_type", .unsupportedMediaType),
            (422, "photo_too_large", .photoTooLarge),
            (501, "storage_unavailable", .storageUnavailable),
        ])
        func photoRequestErrors(status: Int, code: String, expected: AriaServerCode) async throws {
            let client = try await TestEnv.signedInClient()
            server.route("POST \(stepPath)/photos", .json(#"{"detail":{"code":"\#(code)","message":"m"}}"#, status: status))
            await #expect { try await client.addPhoto(jpeg: Data(count: 10), step: "s1", of: "o1") } throws: { error in
                (error as? AriaError)?.serverCode == expected
            }
            #expect(server.calls("POST /bucket").isEmpty)
        }

        @Test func confirmingBeforeTheUploadIsReported() async throws {
            let client = try await TestEnv.signedInClient()
            server.route("POST \(stepPath)/photos", .json(ticket, status: 201))
            server.route("POST /bucket", .noContent)
            server.route("POST \(stepPath)/photos/p1/confirm",
                         .json(#"{"detail":{"code":"photo_not_uploaded","message":"m"}}"#, status: 409))
            await #expect { try await client.addPhoto(jpeg: Data(count: 10), step: "s1", of: "o1") } throws: { error in
                (error as? AriaError)?.serverCode == .photoNotUploaded
            }
        }

        @Test func removingAPhotoReturnsTheStep() async throws {
            let client = try await TestEnv.signedInClient()
            server.route("DELETE \(stepPath)/photos/p9", .json(TestEnv.stepJSON()))
            let step = try await client.removePhoto("p9", step: "s1", of: "o1")
            #expect(step.id == "s1")
        }

        // MARK: Completamento

        @Test func completingSendsTheResolutionNotesTrimmed() async throws {
            let client = try await TestEnv.signedInClient()
            server.route("POST /v1/work-orders/o1/complete", .json(TestEnv.orderJSON(status: "completed")))
            let order = try await client.complete(order: "o1", resolutionNotes: "  Replaced the breaker  ")
            #expect(order.status == "completed" && order.isClosed)
            let call = try #require(server.calls("POST /v1/work-orders/o1/complete").first)
            #expect(call.json as? [String: String] == ["resolution_notes": "Replaced the breaker"])
        }

        @Test func completingWithBlankNotesNeverReachesTheServer() async throws {
            let client = try await TestEnv.signedInClient()
            let before = server.calls.count
            await #expect { try await client.complete(order: "o1", resolutionNotes: " \n ") } throws: { error in
                (error as? AriaError)?.serverCode == .resolutionNotesRequired
            }
            #expect(server.calls.count == before)
        }

        @Test func incompleteStepsListWhichOnesAreMissing() async throws {
            let client = try await TestEnv.signedInClient()
            server.route("POST /v1/work-orders/o1/complete",
                         .json(#"{"detail":{"code":"steps_incomplete","message":"m","missing":["s2","s3"]}}"#, status: 409))
            await #expect { try await client.complete(order: "o1", resolutionNotes: "done") } throws: { error in
                if case AriaError.workOrder(.stepsIncomplete, let missing)? = error as? AriaError { missing == ["s2", "s3"] } else { false }
            }
        }

        @Test func closedOrderRejectsStepCalls() async throws {
            let client = try await TestEnv.signedInClient()
            server.route("DELETE \(stepPath)", .json(#"{"detail":{"code":"work_order_closed","message":"m"}}"#, status: 409))
            await #expect { try await client.clearReport(step: "s1", of: "o1") } throws: { error in
                (error as? AriaError)?.serverCode == .workOrderClosed
            }
        }
    }
}
