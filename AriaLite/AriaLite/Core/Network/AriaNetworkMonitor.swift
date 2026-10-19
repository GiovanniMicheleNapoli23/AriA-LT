//
//  AriaNetworkMonitor.swift
//  AriaLite
//
//  Created by Giovanni Michele on 19/10/26.
//
//  Lo stato della rete del telefono (NWPathMonitor): se c'è, se è a consumo (cellulare, hotspot)
//  e se l'operatore ha attivato "Risparmio dati". Serve a non provare chiamate quando la rete
//  non c'è (niente timeout che scaricano la batteria e fanno aspettare), a mostrare "Offline",
//  e a ripartire con la sincronizzazione appena la rete torna.
//
//  La rete "c'è" non vuol dire che il server risponda: quello lo dicono gli errori delle chiamate
//  (AriaHTTP.isOffline), che restano la verità finale.
//

import Foundation
import Network
import Observation

@Observable
final class AriaNetworkMonitor {
    enum Interface: Equatable {
        case wifi, cellular, wired, other, none
    }

    struct Status: Equatable {
        var isOnline: Bool
        /// Rete a consumo (cellulare, hotspot personale).
        var isExpensive: Bool
        /// "Risparmio dati" attivo: niente traffico che si può rimandare (es. prefetch dei dettagli).
        var isConstrained: Bool
        var interface: Interface

        static let online = Status(isOnline: true, isExpensive: false, isConstrained: false, interface: .wifi)
        static let offline = Status(isOnline: false, isExpensive: false, isConstrained: false, interface: .none)
    }

    static let shared = AriaNetworkMonitor()

    private(set) var status: Status
    /// Da quando la rete manca (per "Offline da 5 min").
    private(set) var offlineSince: Date?

    var isOnline: Bool { status.isOnline }

    @ObservationIgnored private var monitor: NWPathMonitor?
    @ObservationIgnored private var handlers: [UUID: (Status, Status) -> Void] = [:]

    /// `monitoring: false` parte da `initial` e cambia solo con `simulate` (test e anteprime).
    init(monitoring: Bool = true, initial: Status = .online) {
        status = initial
        offlineSince = initial.isOnline ? nil : .now
        guard monitoring else { return }
        let monitor = NWPathMonitor()
        self.monitor = monitor
        monitor.pathUpdateHandler = { [weak self] path in
            let status = Self.status(of: path)
            Task { @MainActor in self?.update(status) }
        }
        monitor.start(queue: DispatchQueue(label: "aria.network-monitor", qos: .utility))
    }

    deinit { monitor?.cancel() }

    /// Chiamato a ogni cambio (vecchio, nuovo stato). Il token rimuove l'osservatore.
    @discardableResult
    func observe(_ handler: @escaping (Status, Status) -> Void) -> UUID {
        let token = UUID()
        handlers[token] = handler
        return token
    }

    func removeObserver(_ token: UUID) {
        handlers[token] = nil
    }

    /// Solo per test e anteprime.
    func simulate(_ status: Status) {
        update(status)
    }

    private func update(_ new: Status) {
        let old = status
        guard new != old else { return }
        status = new
        if new.isOnline { offlineSince = nil } else if old.isOnline { offlineSince = .now }
        for handler in handlers.values { handler(old, new) }
    }

    private nonisolated static func status(of path: NWPath) -> Status {
        let interface: Interface = if path.usesInterfaceType(.wifi) { .wifi }
            else if path.usesInterfaceType(.cellular) { .cellular }
            else if path.usesInterfaceType(.wiredEthernet) { .wired }
            else if path.status == .satisfied { .other }
            else { .none }
        return Status(isOnline: path.status == .satisfied, isExpensive: path.isExpensive,
                      isConstrained: path.isConstrained, interface: interface)
    }
}
