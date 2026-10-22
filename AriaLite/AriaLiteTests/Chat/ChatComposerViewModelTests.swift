//
//  ChatComposerViewModelTests.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La logica del composer senza interfaccia: cosa fa il pulsante tondo e quando si può toccare,
//  quanto è piena la memoria, il vassoio del contesto. Nessuna chiamata di rete: si guarda solo lo stato.
//

import Foundation
import Testing
@testable import AriaLite

extension BackendTests {
    @Suite("Chat composer view model")
    @MainActor
    struct ChatComposerViewModelTests {
        init() { TestEnv.reset() }

        private func composer(voice: AriaVoiceViewModel? = nil) -> AriaChatComposerViewModel {
            let backend = AriaBackend()
            let chat = AriaAgentChat(backend: backend, progressStore: AriaTaskProgressStore(inMemory: true))
            return AriaChatComposerViewModel(chat: chat, backend: backend, voice: voice)
        }

        private func usage(_ percent: Double, autoCompactAt: Double? = nil, used: Int = 100, overhead: Int? = nil) -> AriaContextUsage {
            AriaContextUsage(usedTokens: used, limitTokens: 1000, messageTokens: nil, overheadTokens: overhead,
                             percentUsed: percent, autoCompactAt: autoCompactAt, compactions: nil,
                             compactableMessages: nil, canCompact: true)
        }

        // MARK: Pulsante principale

        @Test("Campo vuoto senza voce dal vivo: pulsante spento")
        func idleWithoutVoice() {
            let model = composer()
            #expect(model.primaryRole == .idle)
            #expect(model.isPrimaryDisabled)
            #expect(!model.isPrimaryDimmed)
        }

        @Test("Campo vuoto con la voce dal vivo: il pulsante la apre")
        func voiceWhenEmpty() {
            let model = composer(voice: AriaVoiceViewModel())
            #expect(model.primaryRole == .voice)
            #expect(!model.isPrimaryDisabled)
        }

        @Test("Solo spazi non è testo da mandare")
        func whitespaceIsNotText() {
            let model = composer()
            model.draft = "  \n "
            #expect(!model.hasText)
            #expect(model.primaryRole == .idle)
        }

        @Test("Con testo ma senza stabilimento: invio spento e attenuato")
        func sendNeedsPlant() {
            let model = composer()
            model.draft = "Allarme F120"
            #expect(model.primaryRole == .send)
            #expect(model.isPrimaryDisabled)
            #expect(model.isPrimaryDimmed)
        }

        @Test("Il segnaposto segue la dettatura")
        func placeholderAtRest() {
            #expect(composer().placeholder == String(localized: "Ask Aria"))
        }

        // MARK: Memoria della conversazione

        @Test("Anello: normale, poi oltre la compattazione automatica, poi pieno")
        func contextLevels() {
            let model = composer()
            #expect(model.contextLevel(usage(40)) == .normal)
            #expect(model.contextLevel(usage(80)) == .high)
            #expect(model.contextLevel(usage(70, autoCompactAt: 65)) == .high)
            #expect(model.contextLevel(usage(95)) == .full)
        }

        @Test("La frazione dell'anello resta tra 0 e 1")
        func contextFractionIsClamped() {
            let model = composer()
            #expect(model.contextFraction(usage(130)) == 1)
            #expect(model.contextFraction(usage(-5)) == 0)
            #expect(model.contextFraction(usage(25)) == 0.25)
        }

        @Test("Il testo del popover dice quando lo spazio è di manuali e istruzioni")
        func overheadShare() {
            #expect(usage(50, used: 100, overhead: 50).isMostlyOverhead)
            #expect(!usage(50, used: 100, overhead: 49).isMostlyOverhead)
            #expect(!usage(0, used: 0, overhead: 10).isMostlyOverhead)
        }

        // MARK: Contesto e strumenti

        @Test("La ricerca web apre il vassoio; toglierla lo chiude")
        func webSearchTray() {
            let model = composer()
            #expect(!model.hasTray)
            model.webSearch = true
            #expect(model.hasTray)
            model.clearWebSearch()
            #expect(!model.hasTray)
        }

        @Test("Un file aggiunto si toglie dalla sua x")
        func removeContextItem() {
            let model = composer()
            model.chat.contextItems = [AriaContextItem(kind: .document, name: "manuale.pdf", size: 1200)]
            #expect(model.hasTray)
            model.removeContextItem(model.contextItems[0].id)
            #expect(model.contextItems.isEmpty)
            #expect(!model.hasTray)
        }

        @Test("Il popover della memoria si chiude se l'anello sparisce")
        func contextPopoverClosesWhenRingGoes() {
            let model = composer()
            model.showContext = true
            model.contextRingGoneChanged(true)
            #expect(!model.showContext)
        }
    }
}
