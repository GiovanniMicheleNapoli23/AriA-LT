//
//  AriaSetupTourWiring.swift
//  AriaLite
//
//  Created by Giovanni Michele on 13/11/26.
//
//  Il collegamento tra la shell e il giro guidato, in un modificatore solo per non allungare il corpo della
//  shell: inietta il giro nell'ambiente, gli dice chi è l'utente e cosa può fare, lo fa partire (un po' dopo
//  che membership e diritti sono letti), porta la shell nella sezione di ogni passo (e alla chat alla fine) e
//  mette il velo sopra tutto, tranne col blocco.
//

import SwiftUI

struct AriaSetupTourWiring: ViewModifier {
    let tour: AriaSetupTourViewModel
    /// L'email dell'account: il giro è "fatto" per account.
    let account: String
    let isOperator: Bool
    /// `/v1/me` è stato letto: prima non si sa se l'account è admin né cosa può fare.
    let membershipRead: Bool
    let access: AriaSetupTourAccess
    /// Il blocco dell'app (Face ID): il velo non si mostra e il giro non parte.
    let locked: Bool
    /// Il passo cambia: la shell va nella sua sezione.
    let onStep: (AriaSetupTourStep) -> Void
    /// La fine del giro: la shell torna alla chat, da dove partono i suggerimenti.
    let onFinish: () -> Void

    /// Quanto aspetta dopo che tutto è letto, perché la schermata si sia assestata.
    private static let startDelay: Duration = .milliseconds(800)

    /// Cosa serve al giro per decidere i passi e se partire: confrontabile, così `configure` parte solo se cambia.
    private struct Setup: Equatable {
        let account: String
        let isOperator: Bool
        let membershipRead: Bool
        let access: AriaSetupTourAccess
    }

    func body(content: Content) -> some View {
        content
            .environment(\.ariaSetupTour, tour)
            .onChange(of: setup, initial: true) { _, setup in
                tour.configure(account: setup.account, operatorLayout: setup.isOperator,
                               membershipRead: setup.membershipRead, access: setup.access)
            }
            // Parte da solo: dopo una breve pausa, a membership letta e senza blocco. Si rifà se cambia qualcosa.
            .task(id: StartKey(setup: setup, locked: locked)) {
                guard membershipRead, !locked else { return }
                try? await Task.sleep(for: Self.startDelay)
                guard !Task.isCancelled else { return }
                tour.startIfNeeded()
            }
            .onChange(of: tour.current, initial: true) { _, step in
                if let step { onStep(step) }
            }
            .onChange(of: tour.finishCount) { _, _ in
                onFinish()
            }
            .overlay {
                if !locked { AriaSetupTourOverlay(tour: tour) }
            }
    }

    private var setup: Setup {
        Setup(account: account, isOperator: isOperator, membershipRead: membershipRead, access: access)
    }

    private struct StartKey: Equatable {
        let setup: Setup
        let locked: Bool
    }
}
