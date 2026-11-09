//
//  AdminCraftedAriaPlan.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Il documento tagliato in richieste che stanno sotto il limite del firewall (planEdit di edit-with-aria.ts).
//  Il firewall davanti all'API rifiuta un corpo oltre 8 KB (`AriaConfig.maxBodyBytes`): ogni parte si misura
//  sul corpo vero che partirà — la `AriaResponsesRequest` codificata come fa il client — con prompt,
//  escape e UTF-8. Un blocco di testo troppo grande si taglia in pezzi; una tabella enorme resta com'è.
//

import Foundation

/// I campi della richiesta che non dipendono dalla parte.
nonisolated struct AdminCraftedAriaFields: Hashable, Sendable {
    var plantId: String
    var companyId: String?
    var sessionId: String
    var locale: String?
}

nonisolated struct AdminCraftedAriaPlan: Hashable, Sendable {
    /// I blocchi di ogni richiesta, in ordine.
    let parts: [[AdminCraftedAriaBlock]]
    /// I blocchi di testo tagliati, per rimettere insieme le modifiche.
    let pieces: [AdminCraftedAriaPieces]
    /// Blocchi troppo grandi anche da soli (una tabella enorme): restano come sono.
    let skipped: [String]

    // MARK: Misure

    /// La richiesta com'è nella chat: stile "auto", metadati accesi (servono per vedere cosa ha fatto un turno vuoto).
    static func request(input: String, fields: AdminCraftedAriaFields) -> AriaResponsesRequest {
        AriaResponsesRequest(input: input, plantId: fields.plantId, sessionId: fields.sessionId,
                             companyId: fields.companyId, style: AriaChatStyle.auto.rawValue, locale: fields.locale)
    }

    /// I byte del corpo che `AriaAPIClient.stream` manderebbe (stesso `JSONEncoder`).
    static func bytes(of input: String, fields: AdminCraftedAriaFields) -> Int {
        (try? JSONEncoder().encode(request(input: input, fields: fields)).count) ?? .max
    }

    /// I byte di un testo come stringa JSON, con le virgolette.
    private static func jsonBytes(_ text: String) -> Int {
        (try? JSONEncoder().encode(text).count) ?? text.utf8.count + 2
    }

    /// Il più lungo dei due prompt con cui parte una parte: fra le altre, o ultima di una lettura intera.
    private static func partInput(_ instruction: String, _ blocks: [AdminCraftedAriaBlock], _ focus: String?) -> String {
        let among = AdminCraftedAriaPrompt.edit(instruction: instruction, blocks: blocks, focus: focus,
                                                part: .init(n: 99, total: 99))
        let last = AdminCraftedAriaPrompt.edit(instruction: instruction, blocks: blocks, focus: focus,
                                               part: .init(n: 99, total: 99, whole: true))
        return among.utf8.count >= last.utf8.count ? among : last
    }

    /// Quanto pesa un blocco nel corpo: quello che aggiunge al prompt, come stringa JSON.
    private static func cost(_ block: AdminCraftedAriaBlock) -> Int {
        let empty = AdminCraftedAriaPrompt.edit(instruction: "", blocks: [])
        let withBlock = AdminCraftedAriaPrompt.edit(instruction: "", blocks: [block])
        return jsonBytes(String(withBlock.dropFirst(empty.count))) + 2
    }

    // MARK: Piano

    /// Il documento in richieste che stanno tutte sotto `limit` byte.
    static func make(instruction: String, blocks: [AdminCraftedAriaBlock], focus: String?,
                     fields: AdminCraftedAriaFields, limit: Int) throws -> AdminCraftedAriaPlan {
        // Una cornice nel caso peggiore, misurata senza blocchi: quello che pesa a ogni parte.
        let frame = bytes(of: partInput(instruction, [], focus), fields: fields)
        let room = limit - frame
        guard room >= 200 else { throw AdminCraftedAriaError.instructionTooLong }

        var pieces: [AdminCraftedAriaPieces] = []
        var skipped: [String] = []
        var units: [AdminCraftedAriaBlock] = []
        for block in blocks {
            if cost(block) <= room {
                units.append(block)
            } else if case .text(let id, let text) = block {
                // Gli escape JSON possono raddoppiare il peso di un carattere: si taglia con quel margine.
                let texts = AdminCraftedAriaSplitter.split(text, budget: (room - 40) / 2)
                let ids = texts.indices.map { "\(id)~\($0)" }
                pieces.append(AdminCraftedAriaPieces(blockId: id, ids: ids, texts: texts))
                for (pieceId, pieceText) in zip(ids, texts) { units.append(.text(id: pieceId, text: pieceText)) }
            } else {
                skipped.append(block.id)
            }
        }

        var parts: [[AdminCraftedAriaBlock]] = []
        var current: [AdminCraftedAriaBlock] = []
        var used = 0
        for unit in units {
            let weight = cost(unit)
            if !current.isEmpty, used + weight > room {
                parts.append(current)
                current = []
                used = 0
            }
            current.append(unit)
            used += weight
        }
        if !current.isEmpty { parts.append(current) }

        // La stima è per blocco, quello che conta è il corpo com'è partito: una parte che esce ancora oltre
        // il limite si dimezza finché ogni parte ci sta.
        func fits(_ part: [AdminCraftedAriaBlock]) -> Bool {
            bytes(of: partInput(instruction, part, focus), fields: fields) <= limit
        }
        var checked: [[AdminCraftedAriaBlock]] = []
        var queue = parts
        while !queue.isEmpty {
            let part = queue.removeFirst()
            if part.count > 1, !fits(part) {
                let half = (part.count + 1) / 2
                queue.insert(contentsOf: [Array(part[..<half]), Array(part[half...])], at: 0)
            } else {
                checked.append(part)
            }
        }
        return AdminCraftedAriaPlan(parts: checked, pieces: pieces, skipped: skipped)
    }
}
