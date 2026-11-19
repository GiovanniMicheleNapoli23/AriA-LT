//
//  AriaSetupTourViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 13/11/26.
//
//  "Primi passi con AriA", il giro guidato dell'admin: un'intro e poi i passi che spettano all'utente. La prima
//  volta è obbligatoria (niente X, "Indietro" sì), si salva il passo corrente per riprendere dopo una chiusura
//  dell'app e "fatto" si scrive solo alla fine. Il replay parte dall'intro, si può chiudere e non cambia lo stato.
//  Sa quali passi servono, quando partire, dove si è, dove stanno gli elementi da indicare e quando farsi da parte
//  (un foglio aperto dalla sezione).
//

import CoreGraphics
import Foundation
import Observation

@Observable
final class AriaSetupTourViewModel {
    /// Dove si è nel giro: l'intro, oppure un passo.
    enum Position: Equatable {
        case intro
        case step(AriaSetupTourStep)
    }

    /// I passi di questo account. Vuoto per l'operatore o prima di `configure`.
    private(set) var steps: [AriaSetupTourStep] = []
    /// Dove si è; `nil` = giro non attivo.
    private(set) var position: Position?
    /// Il giro è un replay (dalle Impostazioni): ha la X e non salva né riprende il passo.
    private(set) var isReplay = false
    /// Sale a ogni fine del giro: la shell torna alla chat.
    private(set) var finishCount = 0
    /// Dove sta l'elemento di ogni passo, in coordinate globali: lo riportano le viste (`ariaSetupTourAnchor`).
    private(set) var frames: [AriaSetupTourStep: CGRect] = [:]
    /// Cosa può fare l'utente: decide i passi e il testo del caricamento.
    private(set) var access = AriaSetupTourAccess()
    /// Chi ha chiesto di farsi da parte (un foglio aperto): finché ce n'è uno il velo non si vede.
    private(set) var asideSources: Set<String> = []

    @ObservationIgnored private let progress: AriaSetupTourProgress
    @ObservationIgnored private let isTestHost: Bool
    @ObservationIgnored private var account = ""
    @ObservationIgnored private var operatorLayout = false
    @ObservationIgnored private var membershipRead = false

    /// Dentro i test (e con `-AriaTourHidden YES`) il giro non parte da solo: coprirebbe ogni schermata.
    init(
        progress: AriaSetupTourProgress = AriaSetupTourProgress(),
        isTestHost: Bool = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    ) {
        self.progress = progress
        self.isTestHost = isTestHost
    }

    // MARK: Stato

    var isActive: Bool { position != nil }

    /// Il velo si vede: giro attivo e nessun foglio aperto.
    var isVisible: Bool { isActive && asideSources.isEmpty }

    var hasSteps: Bool { !steps.isEmpty }

    var isOnIntro: Bool { position == .intro }

    /// Il passo in corso; `nil` all'intro e a giro fermo.
    var current: AriaSetupTourStep? {
        guard case .step(let step) = position else { return nil }
        return step
    }

    /// Solo il replay si chiude con la X (e l'intro con "Chiudi"): la prima volta è obbligatoria.
    var isClosable: Bool { isReplay }

    /// "Indietro" c'è da ogni passo (dal primo torna all'intro), non all'intro.
    var canGoBack: Bool { current != nil }

    /// Le sezioni della guida che restano, per i chip dell'intro.
    var sections: [AriaSetupTourSection] { access.sections }

    /// Il passo n. 1 è il primo dopo l'intro: l'intro non conta. 0 all'intro.
    var stepNumber: Int {
        guard let current, let index = steps.firstIndex(of: current) else { return 0 }
        return index + 1
    }

    var stepCount: Int { steps.count }

    var isLastStep: Bool { stepCount > 0 && stepNumber == stepCount }

    /// Quanto del giro è fatto, da 0 a 1, per l'anello attorno al simbolo.
    var progressFraction: Double {
        stepCount == 0 ? 0 : Double(stepNumber) / Double(stepCount)
    }

    /// "2 of 8".
    var counterLabel: String { String(localized: "\(stepNumber) of \(stepCount)") }

    /// Il testo del passo in corso, con la variante "nessun sito" del caricamento.
    var currentMessage: LocalizedStringResource? { current?.message(hasSite: access.hasSite) }

    /// Il passo dopo quello in corso, per "Avanti · …"; `nil` all'ultimo.
    var nextStep: AriaSetupTourStep? {
        guard let current, let index = steps.firstIndex(of: current), index + 1 < steps.count else { return nil }
        return steps[index + 1]
    }

    var currentFrame: CGRect? { current.flatMap { frames[$0] } }

    // MARK: Ingresso

    /// Dice al giro chi è l'utente e cosa può fare: ricalcola i passi e, se il giro è in corso, lo corregge.
    func configure(account: String, operatorLayout: Bool, membershipRead: Bool, access: AriaSetupTourAccess) {
        let accountChanged = self.account != account.lowercased()
        self.account = account.lowercased()
        self.operatorLayout = operatorLayout
        self.membershipRead = membershipRead
        if accountChanged { stop() }
        refilter(access: access)
    }

    /// Parte da solo se questo account non l'ha ancora completato: solo admin, a `/v1/me` letto. La prima
    /// esecuzione riprende dal passo salvato, se c'è.
    func startIfNeeded() {
        guard position == nil, !account.isEmpty, !progress.isHidden, !isTestHost,
              !operatorLayout, membershipRead, !steps.isEmpty,
              !progress.isDone(account: account) else { return }
        isReplay = false
        move(to: resumePosition())
    }

    /// Lo rifà dall'intro anche se già completato ("Primi passi con AriA" nel profilo). Non riprende nulla.
    func replay() {
        guard !steps.isEmpty else { return }
        isReplay = true
        position = .intro
    }

    // MARK: Avanzamento

    /// L'intro porta al primo passo, un passo al successivo; all'ultimo il giro finisce ed è fatto.
    func next() {
        switch position {
        case nil:
            return
        case .intro:
            if let first = steps.first { move(to: .step(first)) } else { stop() }
        case .step(let step):
            guard let index = steps.firstIndex(of: step) else { return }
            if index + 1 < steps.count {
                move(to: .step(steps[index + 1]))
            } else {
                finish()
            }
        }
    }

    /// Un passo indietro; dal primo si torna all'intro.
    func back() {
        guard let current, let index = steps.firstIndex(of: current) else { return }
        move(to: index > 0 ? .step(steps[index - 1]) : .intro)
    }

    /// La X del replay (e "Chiudi" dell'intro): lascia l'utente dov'è e non cambia lo stato di completamento.
    /// La prima volta non si chiude.
    func close() {
        guard isReplay, isActive else { return }
        end()
    }

    /// Ferma il giro senza darlo per fatto: la prima esecuzione riprenderà dal passo salvato.
    func stop() {
        end()
    }

    /// I permessi sono cambiati (diritti del ruolo): i passi si ricalcolano. Se manca il passo corrente si salta
    /// al primo successivo; se non ne resta nessuno dopo il giro finisce, se non ne resta alcuno si ferma.
    func refilter(access: AriaSetupTourAccess) {
        self.access = access
        steps = operatorLayout ? [] : access.steps
        guard let position else { return }
        if operatorLayout || steps.isEmpty {
            // Layout dell'operatore o niente più da mostrare: il giro si ferma, non è completato.
            end()
            return
        }
        guard case .step(let step) = position, !steps.contains(step) else { return }
        if let later = steps.first(where: { $0.order > step.order }) {
            move(to: .step(later))
        } else {
            finish()
        }
    }

    // MARK: Elementi da indicare

    /// `nil` = l'elemento non c'è più (vista sparita).
    func setFrame(_ frame: CGRect?, for step: AriaSetupTourStep) {
        guard frames[step] != frame else { return }
        frames[step] = frame
    }

    // MARK: Foglio aperto

    /// Una vista della sezione apre (o chiude) un foglio: finché ne resta uno il velo si fa da parte. `source`
    /// distingue chi lo chiede.
    func setAside(_ aside: Bool, source: String) {
        if aside {
            guard !asideSources.contains(source) else { return }
            asideSources.insert(source)
        } else {
            guard asideSources.contains(source) else { return }
            asideSources.remove(source)
        }
    }

    // MARK: Interno

    /// Il passo da cui riprende la prima esecuzione: quello salvato; se non c'è più, il primo dopo; senza
    /// niente di salvato (o niente dopo) l'intro.
    private func resumePosition() -> Position {
        guard let key = progress.savedStep(account: account),
              let saved = AriaSetupTourStep(rawValue: key) else { return .intro }
        if steps.contains(saved) { return .step(saved) }
        return steps.first(where: { $0.order > saved.order }).map(Position.step) ?? .intro
    }

    /// Cambia posizione. La prima esecuzione salva il passo (riprende da lì); tornando all'intro lo toglie.
    private func move(to new: Position) {
        position = new
        guard !isReplay else { return }
        switch new {
        case .intro: progress.clearStep(account: account)
        case .step(let step): progress.saveStep(step.rawValue, account: account)
        }
    }

    private func end() {
        position = nil
        isReplay = false
    }

    private func finish() {
        progress.markDone(account: account)
        progress.clearStep(account: account)
        end()
        finishCount += 1
    }
}
