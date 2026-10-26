//
//  AdminCraftedStorage.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Dove e come si tengono sul dispositivo gli artifact e le versioni di Crafted: file JSON in
//  Application Support/Crafted/<azienda>/, scritti in modo atomico. Un file danneggiato si legge
//  come vuoto, mai come un crash. Le date sono ISO 8601 con i millisecondi, come le scrive la web.
//

import Foundation

nonisolated enum AdminCraftedStorage {
    /// Application Support/Crafted: la cartella da cui partono i file di ogni azienda.
    static var defaultBaseURL: URL {
        let support = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                    appropriateFor: nil, create: true))
            ?? FileManager.default.temporaryDirectory
        return support.appendingPathComponent("Crafted", isDirectory: true)
    }

    /// `<base>/<azienda>/<nome>`; dall'id si tolgono i caratteri che non vanno in un percorso.
    static func fileURL(baseURL: URL, companyId: String, name: String) -> URL {
        let safe = String(companyId.map { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" ? $0 : "_" })
        return baseURL.appendingPathComponent(safe.isEmpty ? "_" : safe, isDirectory: true).appendingPathComponent(name)
    }

    /// Il contenuto del file, o `nil` se non c'è o non si legge.
    static func read(_ url: URL) -> Data? { try? Data(contentsOf: url) }

    static func write(_ data: Data, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUnlessOpen])
    }

    // MARK: JSON

    private nonisolated(unsafe) static let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(formatter.string(from: date))
        }
        return encoder
    }

    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let raw = try decoder.singleValueContainer().decode(String.self)
            guard let date = AriaDate.parse(raw) else {
                throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid date \(raw)"))
            }
            return date
        }
        return decoder
    }

    /// Adesso, arrotondato al millisecondo come lo scrive il file: ricaricato dal disco è lo stesso valore, quindi `==` regge.
    static func now() -> Date {
        AriaDate.parse(formatter.string(from: Date())) ?? Date()
    }

    /// Un id nuovo per un artifact o una versione.
    static func newID() -> String { UUID().uuidString.lowercased() }
}
