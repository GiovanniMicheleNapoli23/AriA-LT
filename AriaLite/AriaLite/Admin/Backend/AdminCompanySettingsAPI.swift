//
//  AdminCompanySettingsAPI.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le rotte di "Danger zone" della pagina /settings della web: cancellano i dati operativi di un'azienda
//  o di uno stabilimento. Operazioni irreversibili: la conferma sta nella VM, non qui.
//  La risposta non serve (è un riepilogo che l'app non mostra), quindi si ignora.
//

import Foundation

nonisolated struct AdminCompanySettingsAPI: Sendable {
    let api: AriaAPIClient

    /// DELETE /v1/companies/{company_id}/data: cancella i dati operativi di tutti gli stabilimenti.
    /// Senza query il server usa i suoi default (dati operativi sì, dati del piano di controllo no).
    func deleteCompanyData(companyId: String) async throws {
        let _: AriaNoContent = try await api.call(
            AriaEndpoint<AriaNoContent>.delete("v1/companies/\(companyId)/data"))
    }

    /// DELETE /v1/companies/{company_id}/plants/{plant_id}/data: cancella i dati operativi di uno stabilimento.
    func deletePlantData(companyId: String, plantId: String) async throws {
        let _: AriaNoContent = try await api.call(
            AriaEndpoint<AriaNoContent>.delete("v1/companies/\(companyId)/plants/\(plantId)/data"))
    }
}
