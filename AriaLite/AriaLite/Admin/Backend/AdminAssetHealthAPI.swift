//
//  AdminAssetHealthAPI.swift
//  AriaLite
//
//  Created by Giovanni Michele on 10/11/26.
//
//  Le rotte del punteggio di salute di un asset: lettura e ricalcolo. Si chiamano per TAG (non per id);
//  il client codifica il percorso da solo, quindi il tag si passa com'è.
//

import Foundation

extension AdminAssetsAPI {
    /// GET /v1/asset-health/{asset_tag}: basta la sezione assets. 404 se non è ancora stato calcolato.
    static func health(assetTag: String) -> AriaEndpoint<AdminAssetHealth> {
        AriaEndpoint.get("v1/asset-health/\(assetTag)").snakeCased()
    }

    /// POST /v1/asset-health/{asset_tag}/refresh: senza body, risponde con il punteggio nuovo.
    static func refreshHealth(assetTag: String) -> AriaEndpoint<AdminAssetHealth> {
        AriaEndpoint.post("v1/asset-health/\(assetTag)/refresh").snakeCased()
    }
}
