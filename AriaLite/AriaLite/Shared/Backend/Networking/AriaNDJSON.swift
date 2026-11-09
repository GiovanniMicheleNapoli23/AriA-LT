//
//  AriaNDJSON.swift
//  AriaLite
//
//  Created by Giovanni Michele on 27/10/26.
//
//  Spezza i byte di una risposta NDJSON in righe JSON, man mano che arrivano (stream di Agent Studio).
//  Puro e senza rete, quindi si prova con byte finti.
//

import Foundation

/// Un oggetto JSON per riga. Tollera il prefisso SSE `data:`, salta le righe che non sono JSON
/// (commenti, keep-alive) e scarta una riga oltre `maxLineBytes` fino al prossimo a capo.
nonisolated struct AriaNDJSONSplitter {
    static let maxLineBytes = 1 << 20

    private static let dataPrefix = Array("data:".utf8)

    private var buffer: [UInt8] = []
    /// Riga troppo lunga: si ignora tutto fino al prossimo `\n`.
    private var discarding = false

    /// Un byte alla volta; esce la riga appena si chiude con `\n` (se è JSON valido).
    mutating func consume(_ byte: UInt8) -> AriaJSON? {
        if byte == 0x0A {
            defer { buffer.removeAll(keepingCapacity: true); discarding = false }
            return discarding ? nil : Self.decode(buffer)
        }
        if discarding { return nil }
        if buffer.count >= Self.maxLineBytes {
            buffer.removeAll(keepingCapacity: true)
            discarding = true
            return nil
        }
        buffer.append(byte)
        return nil
    }

    /// Un blocco di byte: tutte le righe che si chiudono al suo interno.
    mutating func consume(_ chunk: some Sequence<UInt8>) -> [AriaJSON] {
        chunk.compactMap { consume($0) }
    }

    /// Fine del corpo: l'ultima riga senza `\n` vale lo stesso.
    mutating func finish() -> AriaJSON? {
        defer { buffer.removeAll(); discarding = false }
        return discarding ? nil : Self.decode(buffer)
    }

    private static func decode(_ bytes: [UInt8]) -> AriaJSON? {
        var slice = bytes[...]
        trim(&slice)
        if slice.starts(with: dataPrefix) {
            slice = slice.dropFirst(dataPrefix.count)
            trim(&slice)
        }
        // Solo oggetti o array: il resto (`event:`, `id:`, commenti) non porta JSON.
        guard let first = slice.first, first == 0x7B || first == 0x5B else { return nil }
        return try? JSONDecoder().decode(AriaJSON.self, from: Data(slice))
    }

    private static func trim(_ slice: inout ArraySlice<UInt8>) {
        while let first = slice.first, isSpace(first) { slice = slice.dropFirst() }
        while let last = slice.last, isSpace(last) { slice = slice.dropLast() }
    }

    private static func isSpace(_ byte: UInt8) -> Bool {
        byte == 0x20 || byte == 0x09 || byte == 0x0D
    }
}
