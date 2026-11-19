//
//  AdminUsageAutosaveTests.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Il motore del salvataggio automatico dei destinatari e delle regole degli avvisi: una richiesta alla volta, in attesa solo
//  l'ultima modifica, il valore fallito tenuto per "Retry", "blocked" quando un valore va corretto e il testo di stato.
//

import Foundation
import Testing
@testable import AriaLite

/// Una richiesta che resta ferma finché il test non la lascia andare.
@MainActor
private final class Gate {
    private var continuation: CheckedContinuation<Void, Never>?
    private(set) var isParked = false

    func park() async {
        isParked = true
        await withCheckedContinuation { continuation = $0 }
        isParked = false
    }

    func open() {
        continuation?.resume()
        continuation = nil
    }

    func waitUntilParked() async {
        while !isParked { await Task.yield() }
    }
}

@MainActor
@Suite("Usage autosave")
struct AdminUsageAutosaveTests {
    @Test func aSingleChangeIsSentAndSaysSaved() async {
        let saver = AdminUsageAutosave<Int>()
        var sent: [Int] = []
        saver.send = { value in sent.append(value); return true }

        saver.schedule(1)
        #expect(saver.state == .saving)
        await saver.settled()

        #expect(sent == [1])
        #expect(saver.state == .saved)
        #expect(!saver.isBusy)
    }

    @Test func oneRequestAtATimeAndOnlyTheLatestWaitingChangeGoesNext() async {
        let saver = AdminUsageAutosave<Int>()
        let gate = Gate()
        var sent: [Int] = []
        var inFlight = 0
        var most = 0
        saver.send = { value in
            inFlight += 1
            most = max(most, inFlight)
            sent.append(value)
            if value == 1 { await gate.park() }
            inFlight -= 1
            return true
        }

        saver.schedule(1)
        await gate.waitUntilParked()
        // Mentre la prima è in volo, tre modifiche: solo l'ultima aspetta.
        saver.schedule(2)
        saver.schedule(3)
        saver.schedule(4)
        #expect(saver.isBusy)
        gate.open()
        await saver.settled()

        #expect(sent == [1, 4])
        #expect(most == 1)
        #expect(saver.state == .saved)
    }

    @Test func aFailureKeepsTheValueForRetry() async {
        let saver = AdminUsageAutosave<String>()
        var sent: [String] = []
        var accept = false
        saver.send = { value in sent.append(value); return accept }

        saver.schedule("a")
        await saver.settled()
        #expect(saver.state == .error)
        #expect(saver.state.text == "Not saved")

        accept = true
        saver.retry()
        await saver.settled()

        #expect(sent == ["a", "a"])
        #expect(saver.state == .saved)
    }

    @Test func retryDoesNothingWithoutAFailedValue() async {
        let saver = AdminUsageAutosave<Int>()
        var sent: [Int] = []
        saver.send = { value in sent.append(value); return true }

        saver.retry()
        await saver.settled()

        #expect(sent.isEmpty)
        #expect(saver.state == .idle)
    }

    @Test func aNewChangeAfterAFailureReplacesTheFailedValue() async {
        let saver = AdminUsageAutosave<Int>()
        var sent: [Int] = []
        var accept = false
        saver.send = { value in sent.append(value); return accept }

        saver.schedule(1)
        await saver.settled()
        accept = true
        saver.schedule(2)
        await saver.settled()
        saver.retry()
        await saver.settled()

        #expect(sent == [1, 2])
        #expect(saver.state == .saved)
    }

    @Test func blockedSendsNothingAndHasNoRetryUntilUnblocked() async {
        let saver = AdminUsageAutosave<Int>()
        var sent: [Int] = []
        saver.send = { value in sent.append(value); return true }

        saver.block(true)
        #expect(saver.state == .blocked)
        #expect(saver.state.text == "Not saved")
        saver.retry()
        await saver.settled()
        #expect(sent.isEmpty)

        saver.block(false)
        #expect(saver.state == .idle)
        saver.schedule(7)
        await saver.settled()
        #expect(sent == [7])
    }

    @Test func blockingDropsTheWaitingChangeAndStaysBlockedAfterTheRequestInFlight() async {
        let saver = AdminUsageAutosave<Int>()
        let gate = Gate()
        var sent: [Int] = []
        saver.send = { value in
            sent.append(value)
            if value == 1 { await gate.park() }
            return true
        }

        saver.schedule(1)
        await gate.waitUntilParked()
        saver.schedule(2)
        saver.block(true)
        gate.open()
        await saver.settled()

        #expect(sent == [1])
        #expect(saver.state == .blocked)
    }

    @Test func resetForgetsEverythingAndALateAnswerDoesNotWrite() async {
        let saver = AdminUsageAutosave<Int>()
        let gate = Gate()
        var sent: [Int] = []
        saver.send = { value in
            sent.append(value)
            if value == 1 { await gate.park() }
            return true
        }

        saver.schedule(1)
        await gate.waitUntilParked()
        saver.reset()
        #expect(saver.state == .idle)
        #expect(!saver.isBusy)
        saver.schedule(2)
        gate.open()
        await saver.settled()

        // La richiesta 1 è finita dopo il reset e non ha toccato lo stato della 2.
        #expect(sent == [1, 2])
        #expect(saver.state == .saved)
    }

    @Test func theStatusTexts() {
        #expect(AdminUsageSaveState.idle.text == nil)
        #expect(AdminUsageSaveState.saving.text == "Saving…")
        #expect(AdminUsageSaveState.saved.text == "Saved")
        #expect(AdminUsageSaveState.error.text == "Not saved")
        #expect(AdminUsageSaveState.blocked.text == "Not saved")
    }
}
