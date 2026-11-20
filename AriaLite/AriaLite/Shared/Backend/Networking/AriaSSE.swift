//
//  AriaSSE.swift
//  AriaLite
//
//  Created by Giovanni Michele on 20/11/26.
//
//  Spezza i byte dello stream di POST /v1/responses in eventi SSE, man mano che arrivano.
//  Puro e senza rete, quindi si prova con byte finti.
//

import Foundation

nonisolated struct AriaSSEEvent: Sendable {
    let event: String
    let data: String
}

/// Parser incrementale: frame separati da una riga vuota, righe `event:` e `data:`.
/// Un frame oltre `maxFrameBytes` si scarta fino alla riga vuota: un server che non la manda mai non fa crescere la memoria.
nonisolated struct AriaSSEParser {
    static let maxFrameBytes = 1 << 20

    private var buffer: [UInt8] = []
    /// Frame troppo grande: si ignora tutto fino al prossimo confine. `buffer` tiene solo l'ultimo byte.
    private var discarding = false

    mutating func consume(_ byte: UInt8) -> AriaSSEEvent? {
        if byte == 0x0D { return nil }  // normalizza \r\n
        if discarding {
            if byte == 0x0A, buffer.last == 0x0A { discarding = false; buffer.removeAll(keepingCapacity: true) }
            else { buffer.removeAll(keepingCapacity: true); buffer.append(byte) }
            return nil
        }
        buffer.append(byte)
        let n = buffer.count
        guard byte == 0x0A, n >= 2, buffer[n - 2] == 0x0A else {
            if n > Self.maxFrameBytes { buffer = [byte]; discarding = true }
            return nil
        }
        defer { buffer.removeAll(keepingCapacity: true) }
        return Self.parse(buffer)
    }

    mutating func finish() -> AriaSSEEvent? {
        defer { buffer.removeAll(); discarding = false }
        return buffer.isEmpty || discarding ? nil : Self.parse(buffer)
    }

    private static func parse(_ bytes: [UInt8]) -> AriaSSEEvent? {
        let text = String(decoding: bytes, as: UTF8.self)
        var event = "message"
        var dataLines: [String] = []
        for line in text.split(separator: "\n") {
            if line.hasPrefix(":") { continue }  // commento / keep-alive
            if line.hasPrefix("event:") {
                event = line.dropFirst(6).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("data:") {
                var value = line.dropFirst(5)
                if value.first == " " { value = value.dropFirst() }
                dataLines.append(String(value))
            }
        }
        guard !dataLines.isEmpty else { return nil }
        return AriaSSEEvent(event: event, data: dataLines.joined(separator: "\n"))
    }
}
