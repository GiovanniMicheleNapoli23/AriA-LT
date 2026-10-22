//
//  AdminDocumentChunk.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un pezzo di testo estratto dal documento e indicizzato (RagChunkResponse): ordine, pagina, testo.
//

import Foundation

nonisolated struct AdminDocumentChunk: Decodable, Sendable, Identifiable, Hashable {
    let id: String
    let ordinal: Int?
    let text: String
    let charCount: Int?
    let page: Int?
    let runId: String?

    private enum CodingKeys: String, CodingKey { case id, ordinal, text, charCount, metadata, runId }
    private enum MetadataKeys: String, CodingKey { case page, chunkIndex }

    init(from decoder: any Decoder) throws {
        typealias D = AdminDocumentDecoding
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let metadata = try? c.nestedContainer(keyedBy: MetadataKeys.self, forKey: .metadata)
        let ordinal = D.int(c, .ordinal) ?? metadata.flatMap { D.int($0, .chunkIndex) }
        let runId = D.text(c, .runId)
        guard let id = D.text(c, .id) ?? ordinal.map({ "\(runId ?? "-")#\($0)" }) else {
            throw DecodingError.keyNotFound(CodingKeys.id, .init(codingPath: c.codingPath, debugDescription: "Chunk senza id"))
        }
        self.id = id
        self.ordinal = ordinal
        self.runId = runId
        text = (try? c.decodeIfPresent(String.self, forKey: .text)) ?? ""
        charCount = D.int(c, .charCount)
        page = metadata.flatMap { D.int($0, .page) }
    }
}
