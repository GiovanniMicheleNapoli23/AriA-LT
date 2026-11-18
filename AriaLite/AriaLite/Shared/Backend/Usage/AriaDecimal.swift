//
//  AriaDecimal.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  I decimali dei crediti: il server li manda come stringa esatta ("2.4", "0.70", "1200") o, in qualche campo, come
//  numero JSON. Lettura rigorosa e mai un errore: un valore illeggibile è `nil`, non rompe il payload.
//

import Foundation

nonisolated enum AriaDecimal {
    /// Solo `-?[0-9]+(\.[0-9]+)?`: niente esponente, spazi, virgole o codice dopo il numero. `Decimal(string:)` da solo
    /// accetta "2.4abc" come 2.4, quindi la forma si controlla prima.
    static func parse(_ text: String) -> Decimal? {
        guard isStrictDecimal(text) else { return nil }
        return Decimal(string: text, locale: Locale(identifier: "en_US_POSIX"))
    }

    /// Un numero JSON come decimale esatto: passa dalla sua scrittura ("0.035"), mai da un prodotto in virgola mobile.
    static func parse(_ number: Double) -> Decimal? {
        guard number.isFinite else { return nil }
        if let whole = Int(exactly: number) { return Decimal(whole) }
        // Gli esponenti (1e-05) non sono nella forma rigorosa: per loro vale la conversione diretta.
        return parse(String(number)) ?? Decimal(number)
    }

    /// Un valore JSON libero: stringa decimale o numero; qualsiasi altra cosa è `nil`.
    static func from(_ json: AriaJSON?) -> Decimal? {
        switch json {
        case .string(let text)?: parse(text)
        case .number(let number)?: parse(number)
        default: nil
        }
    }

    private static func isStrictDecimal(_ text: String) -> Bool {
        var digitsBefore = 0
        var digitsAfter = 0
        var seenDot = false
        var first = true
        for byte in text.utf8 {
            defer { first = false }
            switch byte {
            case UInt8(ascii: "-") where first: continue
            case UInt8(ascii: "0")...UInt8(ascii: "9"):
                if seenDot { digitsAfter += 1 } else { digitsBefore += 1 }
            case UInt8(ascii: ".") where !seenDot && digitsBefore > 0:
                seenDot = true
            default: return false
            }
        }
        return digitsBefore > 0 && (!seenDot || digitsAfter > 0)
    }
}

/// Un campo decimale del server: stringa esatta o numero JSON. Qualsiasi altra cosa (stringa malformata, booleano,
/// null) vale `value == nil`; la decodifica non lancia mai.
nonisolated struct AriaWireDecimal: Decodable, Sendable, Hashable {
    let value: Decimal?

    init(value: Decimal?) {
        self.value = value
    }

    init(from decoder: any Decoder) {
        guard let container = try? decoder.singleValueContainer() else { value = nil; return }
        if (try? container.decode(Bool.self)) != nil {
            value = nil
        } else if let text = try? container.decode(String.self) {
            value = AriaDecimal.parse(text)
        } else if let number = try? container.decode(Decimal.self) {
            // Il decoder legge la scrittura del numero (0.1, 172.8) come decimale esatto, senza passare da `Double`.
            value = number
        } else if let number = try? container.decode(Double.self) {
            value = AriaDecimal.parse(number)
        } else {
            value = nil
        }
    }
}

/// Un valore che si decodifica o vale `nil`: serve a scartare un elemento di un array o di un dizionario
/// senza far fallire tutto.
nonisolated struct AriaLenient<Value: Decodable & Sendable>: Decodable, Sendable {
    let value: Value?

    init(from decoder: any Decoder) {
        value = try? Value(from: decoder)
    }
}

nonisolated extension KeyedDecodingContainer {
    /// Un decimale (stringa o numero) o `nil`: mancante, null o malformato non fanno fallire il payload.
    nonisolated func ariaDecimal(_ key: Key) -> Decimal? {
        (try? decodeIfPresent(AriaWireDecimal.self, forKey: key))?.value
    }

    /// `true` quando la chiave c'è, non è `null` e il suo valore non si legge come decimale (stringa malformata,
    /// booleano, oggetto). Mancante o `null` non sono malformati: sono assenti, e per i contratti vuol dire altro.
    nonisolated func ariaIsMalformedDecimal(_ key: Key) -> Bool {
        guard contains(key), let isNull = try? decodeNil(forKey: key), !isNull else { return false }
        return ariaDecimal(key) == nil
    }

    /// Un intero (anche scritto come numero intero con decimali, 1.0) o `nil`.
    nonisolated func ariaWhole(_ key: Key) -> Int? {
        if let number = try? decodeIfPresent(Int.self, forKey: key) { return number }
        guard let decimal = ariaDecimal(key) else { return nil }
        var value = decimal
        var rounded = Decimal()
        NSDecimalRound(&rounded, &value, 0, .plain)
        return rounded == decimal ? NSDecimalNumber(decimal: rounded).intValue : nil
    }

    /// Un valore di qualsiasi tipo o `nil`: mancante, null o del tipo sbagliato. Il tipo si deduce dove si scrive il risultato.
    nonisolated func ariaLenient<Value: Decodable>(_ key: Key) -> Value? {
        try? decodeIfPresent(Value.self, forKey: key)
    }

    /// Lo stesso, col tipo scritto (per `String.self`, array e dizionari).
    nonisolated func ariaLenient<Value: Decodable>(_ type: Value.Type, _ key: Key) -> Value? {
        try? decodeIfPresent(type, forKey: key)
    }
}
