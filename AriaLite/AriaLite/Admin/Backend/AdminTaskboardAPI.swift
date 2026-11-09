//
//  AdminTaskboardAPI.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La rotta della Taskboard che gli ordini di lavoro non hanno già: GET /v1/members (snake_case).
//  Tutto il resto (lista, PATCH, creazione, modelli, bozza AI) si riusa da AdminWorkOrdersAPI.
//

import Foundation

nonisolated enum AdminTaskboardAPI {
    /// GET /v1/members. Una riga che non si legge si scarta, non svuota l'elenco.
    static func members() -> AriaEndpoint<AriaLossyArray<AdminTaskboardMember>> {
        AriaEndpoint.get("v1/members").snakeCased()
    }
}
