//
//  AdminReportAssets.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il report degli asset (AssetReports): ripartizioni per stato e tipo e gli asset con più guasti. Le righe
//  di top_failing sono oggetti liberi: il nome, il tag e il conteggio si cercano sotto i nomi più
//  probabili.
//

import Foundation

nonisolated struct AdminReportAssets: Decodable, Sendable, Hashable {
    let byStatus: [AdminReportBreakdownItem]
    let byType: [AdminReportBreakdownItem]
    let topFailing: [AdminReportFailingAsset]

    enum CodingKeys: String, CodingKey {
        case byStatus = "by_status"
        case byType = "by_type"
        case topFailing = "top_failing"
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func json(_ key: CodingKeys) -> AriaJSON? { try? c.decodeIfPresent(AriaJSON.self, forKey: key) }
        byStatus = AdminReportBreakdownItem.parse(json(.byStatus))
        byType = AdminReportBreakdownItem.parse(json(.byType))
        topFailing = (json(.topFailing)?.arrayValue ?? []).enumerated()
            .compactMap { AdminReportFailingAsset(json: $1, position: $0) }
    }

    init(byStatus: [AdminReportBreakdownItem], byType: [AdminReportBreakdownItem],
         topFailing: [AdminReportFailingAsset]) {
        self.byStatus = byStatus
        self.byType = byType
        self.topFailing = topFailing
    }

    var isEmpty: Bool { byStatus.isEmpty && byType.isEmpty && topFailing.isEmpty }

    /// Se il server non dà il nome degli asset che si guastano, si completa da GET /v1/assets.
    var needsAssetNames: Bool { topFailing.contains { $0.name == nil } }

    func withNames(from assets: [AdminAsset]) -> AdminReportAssets {
        AdminReportAssets(byStatus: byStatus, byType: byType, topFailing: topFailing.map { $0.named(from: assets) })
    }
}

/// Una riga di "asset con più guasti".
nonisolated struct AdminReportFailingAsset: Sendable, Hashable, Identifiable {
    let assetId: String?
    let tag: String?
    let name: String?
    let count: Double?
    let position: Int

    var id: String { assetId ?? tag ?? name ?? "\(position)" }
    /// Il titolo della riga: il nome, poi il tag.
    var title: String { name ?? tag ?? String(localized: "Unknown asset") }
    /// Il tag sotto il nome (solo se non è già il titolo).
    var subtitle: String? { name != nil ? tag : nil }

    init?(json: AriaJSON, position: Int = 0) {
        guard let object = json.objectValue else { return nil }
        let tag = AdminReportFormat.text(object, keys: ["asset_tag", "tag"])
        let name = AdminReportFormat.text(object, keys: ["asset_name", "name", "title", "asset"])
        let assetId = AdminReportFormat.text(object, keys: ["asset_id", "id"])
        guard tag != nil || name != nil || assetId != nil else { return nil }
        self.init(assetId: assetId, tag: tag, name: name, position: position,
                  count: ["failures", "failure_count", "count", "work_orders", "wo_count", "total", "n"]
                      .lazy.compactMap { AdminReportFormat.number(object[$0]) }.first)
    }

    private init(assetId: String?, tag: String?, name: String?, position: Int, count: Double?) {
        self.assetId = assetId
        self.tag = tag
        self.name = name
        self.count = count
        self.position = position
    }

    /// Il nome dall'elenco asset, trovato per id o per tag.
    func named(from assets: [AdminAsset]) -> AdminReportFailingAsset {
        guard name == nil else { return self }
        let match = assets.first {
            ($0.serverId != nil && $0.serverId == assetId) || $0.tag == tag || $0.tag == assetId
        }
        return AdminReportFailingAsset(assetId: assetId, tag: tag ?? match?.tag, name: match?.name,
                                       position: position, count: count)
    }
}
