//
//  AriaJSON.swift
//  AriaLite
//
//  Tipi JSON tolleranti per i payload del backend Aria (args dei tool,
//  `data` degli artifact, eventi `aria.*` sconosciuti).
//

import Foundation

/// JSON libero.
nonisolated enum AriaJSON: Codable, Sendable, Hashable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: AriaJSON])
    case array([AriaJSON])
    case null

    init(from decoder: any Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else if let v = try? c.decode(Double.self) { self = .number(v) }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else if let v = try? c.decode([AriaJSON].self) { self = .array(v) }
        else { self = .object(try c.decode([String: AriaJSON].self)) }
    }

    func encode(to encoder: any Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let v): try c.encode(v)
        // Gli interi restano interi (123, non 123.0): gli id dei tool sono int lato Python.
        case .number(let v):
            if let i = Int(exactly: v) { try c.encode(i) } else { try c.encode(v) }
        case .bool(let v): try c.encode(v)
        case .object(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        case .null: try c.encodeNil()
        }
    }

    subscript(key: String) -> AriaJSON? {
        if case .object(let o) = self { return o[key] }
        return nil
    }

    var stringValue: String? {
        switch self {
        case .string(let s): s
        case .number(let n): Int(exactly: n).map(String.init) ?? String(n)
        case .bool(let b): String(b)
        default: nil
        }
    }

    var doubleValue: Double? {
        switch self {
        case .number(let n): n
        case .string(let s): Double(s)
        default: nil
        }
    }

    var boolValue: Bool? {
        if case .bool(let b) = self { return b }
        return nil
    }

    var arrayValue: [AriaJSON] {
        if case .array(let a) = self { return a }
        return []
    }

    var objectValue: [String: AriaJSON]? {
        if case .object(let o) = self { return o }
        return nil
    }

    /// Testo non vuoto (le stringhe vuote e i null contano come assenti).
    var nonEmptyString: String? {
        guard let s = stringValue?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return nil }
        return s
    }

    /// JSON compatto per mostrare valori complessi in sola lettura.
    var compactDescription: String {
        guard let data = try? JSONEncoder().encode(self) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }

    /// Converte un JSON libero (es. `artifact.data`) in un tipo Swift.
    func decoded<T: Decodable>(as type: T.Type) throws -> T {
        try JSONDecoder().decode(T.self, from: JSONEncoder().encode(self))
    }
}

/// Id che il backend a volte manda come stringa (REST) e a volte come numero (wo-card, tool args).
nonisolated struct AriaFlexibleID: Codable, Sendable, Hashable, CustomStringConvertible {
    let value: String

    init(_ value: String) { self.value = value }

    init(from decoder: any Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let i = try? c.decode(Int.self) { value = String(i) } else { value = try c.decode(String.self) }
    }

    func encode(to encoder: any Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(value)
    }

    var description: String { value }
}

/// Enum stringa che non esplode se il backend aggiunge un valore nuovo.
nonisolated protocol AriaUnknownCaseDecodable: RawRepresentable, Codable, Sendable where RawValue == String {
    static var unknownCase: Self { get }
}

nonisolated extension AriaUnknownCaseDecodable {
    init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = Self(rawValue: raw) ?? Self.unknownCase
    }
}
