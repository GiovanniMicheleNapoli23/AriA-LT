//
//  ResponsivenessTests.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 15/10/26.
//
//  Reattività: l'interfaccia non resta bloccata mentre la rete lavora, le risposte superate non
//  sovrascrivono quelle nuove, annullare non è un errore, e le funzioni pesanti restano veloci.
//  Le soglie di tempo sono larghe apposta: cercano blocchi veri, non millisecondi.
//

import Foundation
import Testing
import UIKit
@testable import AriaLite

extension BackendTests {
    @Suite("Responsiveness")
    struct Responsiveness {
        private let server = StubServer.shared
        private let openKey = "GET /v1/mobile/work-orders?status=open&limit=50"
        private let closedKey = "GET /v1/mobile/work-orders?status=closed&limit=200"

        init() { TestEnv.reset() }

        private func me() -> String {
            #"{"id":"u1","name":"M","email":"m@a.b","specialties":[],"availability":"available","availabilityAt":null}"#
        }

        private func stubHome(listDelay: TimeInterval = 0) {
            server.route("PUT /v1/mobile/me/availability", .json(me()))
            server.route("GET /v1/mobile/me", .json(me()))
            server.route(openKey, .json("[\(TestEnv.orderJSON())]", delay: listDelay))
            server.route(closedKey, .json("[]"))
        }

        // MARK: Concorrenza

        @Test func mainActorKeepsRunningWhileTheNetworkIsSlow() async throws {
            let (_, store) = try await TestEnv.signedInStore()
            stubHome(listDelay: 0.5)
            let refresh = Task { await store.refresh() }

            var worstGap = Duration.zero
            let clock = ContinuousClock()
            for _ in 0..<8 {
                let start = clock.now
                try await Task.sleep(for: .milliseconds(40))
                worstGap = max(worstGap, clock.now - start - .milliseconds(40))
            }
            #expect(worstGap < .milliseconds(300), "un'attesa di rete non deve fermare l'interfaccia")
            await refresh.value
        }

        @Test func loadingFlagIsRaisedWhileInFlightAndLoweredAfter() async throws {
            let (_, store) = try await TestEnv.signedInStore()
            stubHome(listDelay: 0.4)
            let refresh = Task { await store.refresh() }
            try await Task.sleep(for: .milliseconds(150))
            #expect(store.isLoading, "lo spinner si vede mentre la lista arriva")
            await refresh.value
            #expect(!store.isLoading && store.hasLoaded)
        }

        @Test func concurrentSyncsSendOnlyOneRenewal() async throws {
            let (_, store) = try await TestEnv.signedInStore()
            server.route("PUT /v1/mobile/me/availability", .json(me(), delay: 0.3))
            server.route(openKey, .json("[]"))
            server.route(closedKey, .json("[]"))

            async let first: Void = store.sync()
            async let second: Void = store.sync()
            async let third: Void = store.sync()
            _ = await (first, second, third)

            #expect(server.calls("PUT /v1/mobile/me/availability").count == 1, "apertura e ritorno in primo piano insieme non raddoppiano le chiamate")
        }

        @Test func aStaleListResponseNeverOverwritesANewerOne() async throws {
            let (_, store) = try await TestEnv.signedInStore()
            server.route("GET /v1/mobile/me", .json(me()))
            server.route(closedKey, .json("[]"))
            // La prima richiesta della lista è lenta e vecchia; la seconda è veloce e nuova.
            server.route(openKey,
                         .json("[\(TestEnv.orderJSON(id: "old"))]", delay: 0.5),
                         .json("[\(TestEnv.orderJSON(id: "new"))]"))

            let slow = Task { await store.refresh() }
            try await Task.sleep(for: .milliseconds(150))
            await store.refresh()
            #expect(store.orders.map(\.id) == ["new"])
            await slow.value
            #expect(store.orders.map(\.id) == ["new"], "la risposta lenta arriva dopo e viene scartata")
            #expect(!store.isLoading)
        }

        @Test func cancellingARefreshIsNotAnError() async throws {
            let (_, store) = try await TestEnv.signedInStore()
            stubHome(listDelay: 0.6)
            let refresh = Task { await store.refresh() }
            try await Task.sleep(for: .milliseconds(200))
            refresh.cancel()
            await refresh.value
            #expect(store.errorMessage == nil, "il pull-to-refresh annullato non mostra errori")
        }

        @Test func aSlowTokenRenewalIsSharedByParallelRequests() async throws {
            let client = try await TestEnv.signedInClient()
            server.route("GET /api/aria/token", TestEnv.tokenReply(tag: "slow", delay: 0.3))
            server.route("GET /v1/mobile/me", .json(me()))
            await client.auth.invalidate()

            let started = ContinuousClock.now
            try await withThrowingTaskGroup(of: Void.self) { group in
                for _ in 0..<6 {
                    group.addTask { let _: AriaMobileProfile = try await client.get("v1/mobile/me") }
                }
                try await group.waitForAll()
            }
            #expect(server.calls("GET /api/aria/token").count == 2, "un solo rinnovo per sei richieste")
            #expect(ContinuousClock.now - started < .seconds(2))
        }

        @Test func fullSyncWithAnInstantServerFinishesQuickly() async throws {
            let (_, store) = try await TestEnv.signedInStore()
            stubHome()
            let elapsed = await ContinuousClock().measure { await store.sync() }
            #expect(elapsed < .seconds(1.5))
            #expect(store.hasLoaded)
        }

        @Test func requestTimeoutsSurfaceAsOfflineQuickly() async throws {
            let (backend, store) = try await TestEnv.signedInStore()
            stubHome()
            server.route(openKey, .failing(.timedOut))
            let elapsed = await ContinuousClock().measure { await store.sync() }
            #expect(elapsed < .seconds(1.5))
            #expect(store.errorMessage != nil && backend.isSignedIn)
        }
    }
}

/// Funzioni pesanti: decodifica di liste lunghe, date, foto. Non toccano stato condiviso: girano in parallelo.
struct PerformanceTests {
    @Test func decodingALargeOrderListStaysFast() throws {
        let order = TestEnv.orderJSON(id: "x", withProcedure: true, reported: 5, total: 12)
        let json = "[" + Array(repeating: order, count: 400).joined(separator: ",") + "]"
        let data = Data(json.utf8)
        var list: AriaWorkOrderList?
        let elapsed = ContinuousClock().measure { list = try? JSONDecoder().decode(AriaWorkOrderList.self, from: data) }
        #expect(list?.orders.count == 400)
        #expect(elapsed < .seconds(2), "400 ordini da 12 passi ciascuno: \(elapsed)")
    }

    @Test func parsingManyWireDatesStaysFast() {
        let elapsed = ContinuousClock().measure {
            for i in 0..<5_000 { _ = AriaWireDate.parse("2026-10-09T09:12:\(String(format: "%02d", i % 60)).\(100000 + i)Z") }
        }
        #expect(elapsed < .seconds(2))
    }

    @Test func wireDateParsingDoesNotDependOnFractionLength() {
        let base = AriaWireDate.parse("2026-10-09T09:12:00Z")
        for digits in 0...9 {
            let fraction = digits == 0 ? "" : "." + String(repeating: "5", count: digits)
            #expect(AriaWireDate.parse("2026-10-09T09:12:00\(fraction)Z") == base, "\(digits) cifre")
        }
    }

    @Test func largePhotoIsShrunkUnderTheLimitAndStaysAnImage() throws {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1800, height: 2400),
                                               format: { let f = UIGraphicsImageRendererFormat(); f.scale = 1; return f }())
        let image = renderer.image { context in
            for i in 0..<400 {
                UIColor(hue: CGFloat(i % 40) / 40, saturation: 0.9, brightness: 0.9, alpha: 1).setFill()
                context.fill(CGRect(x: (i * 37) % 1800, y: (i * 91) % 2400, width: 300, height: 300))
            }
        }
        let limit = 150_000
        var jpeg: Data?
        let elapsed = ContinuousClock().measure { jpeg = AriaPhoto.jpeg(from: image, maxBytes: limit) }
        let data = try #require(jpeg)
        #expect(data.count <= limit)
        #expect(UIImage(data: data) != nil)
        #expect(data.prefix(2) == Data([0xFF, 0xD8]), "è un JPEG")
        #expect(elapsed < .seconds(5))
    }

    @Test func photoThatAlreadyFitsIsNotShrunk() throws {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 200, height: 200))
        let image = renderer.image { UIColor.red.setFill(); $0.fill(CGRect(x: 0, y: 0, width: 200, height: 200)) }
        let jpeg = try #require(AriaPhoto.jpeg(from: image))
        #expect(jpeg.count < 10 * 1024 * 1024)
        #expect(AriaPhoto.jpeg(from: Data("not an image".utf8)) == nil)
    }

    @Test func lengthyChatContextIsTruncatedForTheWAFLimit() throws {
        let description = String(repeating: "A long alarm diagnosis. ", count: 400)
        let warnings = (0..<30).map { _ in String(repeating: "W", count: 100) }.map { "\"\($0)\"" }.joined(separator: ",")
        let json = #"{"id":"1","title":"T","status":"assigned","description":"\#(description)","procedure":{"steps":[{"id":"a","number":1,"text":"\#(String(repeating: "s", count: 2000))","report":null}],"safetyWarnings":[\#(warnings)]}}"#
        let order = try JSONDecoder().decode(AriaWorkOrder.self, from: Data(json.utf8))
        let context = order.chatContext(step: order.procedure?.steps.first)
        #expect(context.utf8.count < AriaConfig.production.maxBodyBytes - 2_000, "il contesto lascia spazio al messaggio dell'operatore")
        #expect(context.contains("Work order: T"))
    }
}
