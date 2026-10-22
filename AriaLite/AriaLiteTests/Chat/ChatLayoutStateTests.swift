//
//  ChatLayoutStateTests.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le decisioni di layout della chat senza backend: come si dispone la chat vuota nello spazio
//  libero (tastiera aperta compresa) e quando la lista smette o riprende di seguire l'ultimo messaggio.
//

import SwiftUI
import Testing
@testable import AriaLite

struct ChatLayoutStateTests {
    // MARK: Chat vuota

    @Test("Con spazio: sfera grande, saluto e griglia", arguments: [540, 700, 1000] as [CGFloat])
    func regularWithRoom(height: CGFloat) {
        let layout = AriaChatEmptyLayout(height: height, hasSuggestions: true)
        #expect(layout == .regular)
        #expect(!layout.isCompact)
        #expect(layout.showsGreeting)
    }

    @Test("Tastiera aperta: layout compatto, il saluto resta", arguments: [270, 350, 539] as [CGFloat])
    func compactWithKeyboard(height: CGFloat) {
        let layout = AriaChatEmptyLayout(height: height, hasSuggestions: true)
        #expect(layout == .compact)
        #expect(layout.showsGreeting)
    }

    @Test("Schermo molto basso: restano sfera e suggerimenti")
    func minimalWhenTiny() {
        let layout = AriaChatEmptyLayout(height: 269, hasSuggestions: true)
        #expect(layout == .minimal)
        #expect(layout.isCompact)
        #expect(!layout.showsGreeting)
    }

    @Test("iPhone in orizzontale con la tastiera: solo la riga dei suggerimenti, poi niente")
    func landscapeWithKeyboard() {
        let row = AriaChatEmptyLayout(height: 199, hasSuggestions: true)
        #expect(row == .suggestionsOnly)
        #expect(!row.showsOrb)
        #expect(!row.showsGreeting)
        #expect(row.showsSuggestions)

        let hidden = AriaChatEmptyLayout(height: 76, hasSuggestions: true)
        #expect(hidden == .hidden)
        #expect(!hidden.showsSuggestions)
        #expect(AriaChatEmptyLayout(height: 200, hasSuggestions: true) == .minimal)
    }

    @Test("Senza suggerimenti serve meno spazio e il saluto non sparisce mai")
    func withoutSuggestions() {
        #expect(AriaChatEmptyLayout(height: 320, hasSuggestions: false) == .regular)
        #expect(AriaChatEmptyLayout(height: 319, hasSuggestions: false) == .compact)
        #expect(AriaChatEmptyLayout(height: 100, hasSuggestions: false).showsGreeting)
    }

    // MARK: Segui il fondo

    private let overflowing = AriaChatScrollFollow.Sizes(content: 2000, container: 600)

    @Test("All'inizio segue il fondo, ma non con un contenuto più corto dello schermo")
    func followsByDefault() {
        let scroll = AriaChatScrollFollow()
        #expect(scroll.sticksToBottom(overflowing))
        #expect(!scroll.sticksToBottom(.init(content: 400, container: 600)))
        #expect(!scroll.showsJumpToBottom)
    }

    @Test("Mentre il dito scorre non si torna in fondo")
    func userScrollingWins() {
        var scroll = AriaChatScrollFollow()
        scroll.phaseChanged(to: .interacting)
        #expect(!scroll.sticksToBottom(overflowing))
    }

    @Test("Scorrendo verso l'alto si smette di seguire e compare il pulsante")
    func scrollingAwayStopsFollowing() {
        var scroll = AriaChatScrollFollow()
        scroll.phaseChanged(to: .tracking)
        scroll.isNearBottom = false
        scroll.phaseChanged(to: .idle)
        #expect(!scroll.followsBottom)
        #expect(!scroll.sticksToBottom(overflowing))
        #expect(scroll.showsJumpToBottom)
    }

    @Test("Fermandosi in fondo si riprende a seguire")
    func stoppingNearBottomResumes() {
        var scroll = AriaChatScrollFollow()
        scroll.phaseChanged(to: .tracking)
        scroll.isNearBottom = false
        scroll.phaseChanged(to: .idle)
        scroll.phaseChanged(to: .tracking)
        scroll.isNearBottom = true
        scroll.phaseChanged(to: .idle)
        #expect(scroll.followsBottom)
    }

    @Test("Lo scorrimento animato (scrollTo, streaming) non cambia il segui")
    func programmaticScrollKeepsFollowing() {
        var scroll = AriaChatScrollFollow()
        scroll.isNearBottom = false
        scroll.phaseChanged(to: .animating)
        scroll.phaseChanged(to: .idle)
        #expect(scroll.followsBottom)
    }

    @Test("Un messaggio nuovo o il pulsante riportano a seguire")
    func followBottomResets() {
        var scroll = AriaChatScrollFollow()
        scroll.phaseChanged(to: .tracking)
        scroll.isNearBottom = false
        scroll.phaseChanged(to: .idle)
        scroll.followBottom()
        #expect(scroll.followsBottom)
        #expect(!scroll.showsJumpToBottom)
    }

    @Test("Scrivendo in un campo dentro un messaggio la lista non torna in fondo")
    func inlineEditingHoldsPosition() {
        var scroll = AriaChatScrollFollow()
        scroll.isEditingInline = true
        #expect(!scroll.sticksToBottom(overflowing))
        scroll.isEditingInline = false
        #expect(scroll.sticksToBottom(overflowing))
    }
}
