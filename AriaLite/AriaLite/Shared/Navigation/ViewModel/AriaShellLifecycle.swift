//
//  AriaShellLifecycle.swift
//  AriaLite
//
//  Created by Giovanni Michele on 20/11/26.
//
//  Quando la shell rilegge i dati rientrando in primo piano e quando aggiorna i lavori per una notifica. Un
//  Control Center aperto, un foglio di sistema o Face ID passano da `.inactive` e tornano `.active` senza che l'app
//  sia andata in background: non è un ritorno, e non deve rifare la lettura di diritti, lavori e notifiche.
//  Le notifiche a raffica (più lavori assegnati insieme) fanno un solo aggiornamento al secondo.
//  Non è osservabile: la shell lo tiene in uno @State e lo scrive senza ridisegnarsi.
//

import SwiftUI

@MainActor
final class AriaShellLifecycle {
    /// Sotto questa durata, un `.inactive` senza passare dal background è un lampo del sistema, non un ritorno.
    static let blipLimit: TimeInterval = 2
    /// Quanto restano buoni i diritti letti: rientrando prima non si rileggono.
    static let membershipMaxAge: Duration = .seconds(30)
    /// Distanza minima tra due aggiornamenti dei lavori per le notifiche.
    static let arrivalSpacing: Duration = .seconds(1)

    /// Un vero ritorno in primo piano.
    struct Return: Equatable {
        /// L'app era stata in background: il permesso delle notifiche può essere cambiato da Impostazioni.
        let fromBackground: Bool
    }

    private var inactiveSince: Date?
    private var wasInBackground = false

    private var isRefreshingArrivals = false
    private var arrivalPending = false

    /// Da chiamare a ogni cambio di fase. Restituisce qualcosa solo quando l'app torna `.active` e va riletto tutto.
    func phaseChanged(_ phase: ScenePhase, now: Date = .now) -> Return? {
        switch phase {
        case .inactive:
            if inactiveSince == nil { inactiveSince = now }
            return nil
        case .background:
            // Il ritorno è background → inactive → active: il segno resta finché non torna attiva.
            wasInBackground = true
            if inactiveSince == nil { inactiveSince = now }
            return nil
        case .active:
            let fromBackground = wasInBackground
            let away = inactiveSince.map { now.timeIntervalSince($0) } ?? .infinity
            inactiveSince = nil
            wasInBackground = false
            guard fromBackground || away >= Self.blipLimit else { return nil }
            return Return(fromBackground: fromBackground)
        @unknown default:
            return nil
        }
    }

    /// Una notifica di lavoro è arrivata: `refresh` parte subito, quelle che arrivano mentre gira (o nel secondo
    /// dopo) si fondono in un solo giro in coda.
    func workOrderArrived(refresh: @escaping @MainActor () async -> Void) {
        guard !isRefreshingArrivals else {
            arrivalPending = true
            return
        }
        isRefreshingArrivals = true
        Task {
            repeat {
                arrivalPending = false
                await refresh()
                try? await Task.sleep(for: Self.arrivalSpacing)
            } while arrivalPending
            isRefreshingArrivals = false
        }
    }
}
