//
//  AriaDomainResolver.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  La ricerca DNS del sito dell'azienda: il resolver del telefono via getaddrinfo, con un timeout e un controllo per
//  distinguere "il dominio non esiste" da "il DNS non è raggiungibile".
//

import Foundation

/// L'esito di una ricerca DNS.
nonisolated enum AriaDomainLookup: Sendable, Equatable { case found, notFound, failed }

nonisolated protocol AriaDomainResolving: Sendable {
    func lookup(_ host: String) async -> AriaDomainLookup
}

/// Il resolver del telefono via getaddrinfo (AF_UNSPEC: basta un record A o AAAA). Si risolve solo il nome, non si
/// scarica nulla.
nonisolated struct AriaSystemDomainResolver: AriaDomainResolving {
    /// Un host sempre raggiungibile (quello dell'API dell'app): serve a capire se "non trovato" è vero o se il DNS è giù.
    let controlHost: String
    let timeout: Duration

    init(controlHost: String, timeout: Duration = .seconds(5)) {
        self.controlHost = controlHost
        self.timeout = timeout
    }

    func lookup(_ host: String) async -> AriaDomainLookup {
        let controlHost = controlHost
        let seconds = Double(timeout.components.seconds) + Double(timeout.components.attoseconds) / 1e18

        return await withCheckedContinuation { continuation in
            let answer = SingleAnswer(continuation)
            // Il timeout vale per tutto (ricerca e controllo): getaddrinfo blocca e non si annulla, quindi non si fa una
            // gara in un task group (aspetterebbe il figlio bloccato) ma si risponde una volta sola, al primo che arriva.
            DispatchQueue.global().asyncAfter(deadline: .now() + seconds) { answer.send(.failed) }
            DispatchQueue.global(qos: .userInitiated).async {
                switch Self.resolve(host) {
                case .found:
                    answer.send(.found)
                case .failed:
                    answer.send(.failed)
                case .noSuchName:
                    // Su iOS anche il DNS irraggiungibile (offline, captive portal) dà EAI_NONAME: "non trovato" solo se
                    // l'host di controllo, cercato adesso, si risolve.
                    answer.send(Self.resolve(controlHost) == .found ? .notFound : .failed)
                }
            }
        }
    }

    private enum Resolution { case found, noSuchName, failed }

    /// Una chiamata a getaddrinfo (bloccante). EAI_NONAME (8) ed EAI_NODATA (7) sono "nessun nome".
    private static func resolve(_ host: String) -> Resolution {
        var hints = addrinfo()
        hints.ai_family = AF_UNSPEC
        hints.ai_socktype = SOCK_STREAM
        var result: UnsafeMutablePointer<addrinfo>?
        let code = getaddrinfo(host, nil, &hints, &result)
        if let result { freeaddrinfo(result) }
        switch code {
        case 0: return .found
        case 7, 8: return .noSuchName
        default: return .failed
        }
    }
}

/// Riprende la continuation una volta sola, qualunque tra ricerca e timeout arrivi per prima.
private nonisolated final class SingleAnswer: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<AriaDomainLookup, Never>?

    init(_ continuation: CheckedContinuation<AriaDomainLookup, Never>) {
        self.continuation = continuation
    }

    func send(_ result: AriaDomainLookup) {
        lock.lock()
        let pending = continuation
        continuation = nil
        lock.unlock()
        pending?.resume(returning: result)
    }
}
