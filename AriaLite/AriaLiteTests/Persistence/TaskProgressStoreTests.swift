//
//  TaskProgressStoreTests.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 17/10/26.
//
//  Le spunte dei task si salvano con SwiftData: una riga per conversazione, in memoria nei test.
//

import Testing
@testable import AriaLite

@Suite("Task progress store")
struct TaskProgressStoreTests {
    private let store = AriaTaskProgressStore(inMemory: true)

    private let sample = AriaTaskProgressStore.Snapshot(checked: ["step:1:r1:t1", "step:1:r1:t2"],
                                                        marks: ["step:1:r1:t3": "failed"])

    @Test func savedProgressComesBack() {
        store.save(sample, sessionId: "S1")
        #expect(store.load(sessionId: "S1") == sample)
    }

    @Test func conversationsDontShareProgress() {
        store.save(sample, sessionId: "S1")
        #expect(store.load(sessionId: "S2") == nil)
    }

    @Test func savingAgainReplacesTheOldState() {
        store.save(sample, sessionId: "S1")
        let next = AriaTaskProgressStore.Snapshot(checked: ["step:1:r1:t1"], marks: [:])
        store.save(next, sessionId: "S1")
        #expect(store.load(sessionId: "S1") == next)
    }

    @Test func anEmptyStateRemovesTheRecord() {
        store.save(sample, sessionId: "S1")
        store.save(.init(), sessionId: "S1")
        #expect(store.load(sessionId: "S1") == nil)
    }

    @Test func forgetOnlyRemovesThatConversation() {
        store.save(sample, sessionId: "S1")
        store.save(sample, sessionId: "S2")
        store.forget(sessionId: "S1")
        #expect(store.load(sessionId: "S1") == nil)
        #expect(store.load(sessionId: "S2") == sample)
    }

    @Test func forgetAllClearsEverything() {
        store.save(sample, sessionId: "S1")
        store.save(sample, sessionId: "S2")
        store.forgetAll()
        #expect(store.load(sessionId: "S1") == nil)
        #expect(store.load(sessionId: "S2") == nil)
    }
}
