//
//  AdminWorkOrderFields.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Decodifica tollerante per le risposte degli ordini di lavoro admin: un campo assente, nullo o di un tipo
//  inatteso vale `nil` invece di far fallire tutta la risposta. Solo i campi davvero necessari (id e titolo)
//  si leggono con `decode` normale.
//

import Foundation

/// I campi di un oggetto JSON letti senza errori.
nonisolated struct AdminWorkOrderFields<Key: CodingKey> {
    let container: KeyedDecodingContainer<Key>

    init(_ decoder: any Decoder, keyedBy: Key.Type) throws {
        container = try decoder.container(keyedBy: Key.self)
    }

    /// Il valore se c'è ed è del tipo giusto, altrimenti `nil`.
    func value<T: Decodable>(_ type: T.Type, _ key: Key) -> T? {
        (try? container.decodeIfPresent(T.self, forKey: key)) ?? nil
    }

    /// Una data ISO-8601 del backend (con o senza frazioni di secondo e fuso).
    func date(_ key: Key) -> Date? {
        value(AriaWireDate.self, key)?.value
    }

    /// Un numero intero, anche se arriva come `12.0` o `"12"`.
    func int(_ key: Key) -> Int? {
        if let number = value(Int.self, key) { return number }
        if let number = value(Double.self, key) { return Int(exactly: number.rounded()) }
        return value(String.self, key).flatMap { Int($0) }
    }

    /// Un numero decimale, anche se arriva come stringa.
    func double(_ key: Key) -> Double? {
        value(Double.self, key) ?? value(String.self, key).flatMap { Double($0) }
    }

    /// Testo non vuoto.
    func text(_ key: Key) -> String? {
        guard let text = value(String.self, key)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else { return nil }
        return text
    }

    /// Un id che il backend può mandare come stringa o come numero.
    func id(_ key: Key) -> String? {
        value(AriaFlexibleID.self, key)?.value
    }

    /// Un array in cui gli elementi che non si leggono si scartano.
    func array<T: Decodable & Sendable>(_ type: T.Type, _ key: Key) -> [T] {
        value(AriaLossyArray<T>.self, key)?.items ?? []
    }
}
