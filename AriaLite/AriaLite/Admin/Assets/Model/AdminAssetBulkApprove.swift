//
//  AdminAssetBulkApprove.swift
//  AriaLite
//
//  Created by Giovanni Michele on 10/11/26.
//
//  Il body e la risposta di POST /v1/assets/bulk-approve (approvazione in blocco delle bozze).
//

import Foundation

nonisolated struct AdminAssetBulkApproveBody: Encodable, Sendable {
    let ids: [String]
}

/// `{"approved": n}`: quanti asset sono stati approvati (gli id sconosciuti sono saltati dal server).
nonisolated struct AdminAssetBulkApproveResult: Decodable, Sendable {
    let approved: Int?

    private enum CodingKeys: String, CodingKey { case approved }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        approved = try? c.decodeIfPresent(Int.self, forKey: .approved)
    }
}
