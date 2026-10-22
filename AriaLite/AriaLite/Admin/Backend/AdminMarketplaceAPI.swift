//
//  AdminMarketplaceAPI.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le rotte dei connettori dell'azienda, come la pagina /marketplace della web. Una riga per rotta;
//  si eseguono con `backend.api.call(endpoint)`. Tutte sotto /v1/companies/{company_id}/connectors e in
//  snake_case. MaintainX ha le sue rotte (`maintainx`, `maintainx/test`, `maintainx/tools`), che sono le
//  stesse stringhe di `{provider}` con lo slug fisso: chi cambia è il body del PUT e la verifica.
//

import Foundation

nonisolated enum AdminMarketplaceAPI {
    // MARK: Elenco e tool

    static func connectors(companyId: String) -> AriaEndpoint<AdminConnectorListResponse> {
        AriaEndpoint.get(base(companyId)).snakeCased()
    }

    /// I tool esposti. Per MaintainX il server ha la sua rotta (la generica la rifiuta), con lo stesso percorso.
    static func tools(companyId: String, provider: String) -> AriaEndpoint<AdminConnectorTools> {
        AriaEndpoint.get(path(companyId, provider, "tools")).snakeCased()
    }

    // MARK: Credenziali

    /// PUT /connectors/maintainx: verifica la chiave prima di salvarla. Se vede più organizzazioni le rimanda
    /// in `organizations` senza sceglierne una; la scelta torna con un secondo PUT.
    static func connectMaintainX(companyId: String, _ body: AdminConnectorMaintainXConnect) -> AriaEndpoint<AdminConnector> {
        AriaEndpoint.put(path(companyId, AdminConnector.maintainXProvider), body: body).snakeCased()
    }

    /// PUT /connectors/{provider}: server MCP con credenziale statica. Un connettore OAuth risponde 409.
    static func connectRemote(companyId: String, provider: String, _ body: AdminConnectorRemoteConnect) -> AriaEndpoint<AdminConnector> {
        AriaEndpoint.put(path(companyId, provider), body: body).snakeCased()
    }

    /// Riverifica la chiave salvata di MaintainX (non la cambia).
    static func verifyMaintainX(companyId: String) -> AriaEndpoint<AdminConnector> {
        AriaEndpoint.post(path(companyId, AdminConnector.maintainXProvider, "test")).snakeCased()
    }

    /// Rilegge i tool del server: controllo di salute e nuovi tool senza aspettare la cache (non MaintainX).
    static func refresh(companyId: String, provider: String) -> AriaEndpoint<AdminConnector> {
        AriaEndpoint.post(path(companyId, provider, "refresh")).snakeCased()
    }

    /// Rimuove il connettore e la sua credenziale; per uno personale anche le connessioni di tutti i membri.
    static func disconnect(companyId: String, provider: String) -> AriaEndpoint<AriaNoContent> {
        AriaEndpoint.delete(path(companyId, provider)).snakeCased()
    }

    // MARK: OAuth

    /// Consenso aziendale: l'URL da aprire nel browser. Il ritorno lo gestisce il server (nessun redirect_uri qui).
    static func startOAuth(companyId: String, provider: String, requestWrite: Bool) -> AriaEndpoint<AdminConnectorOAuthStart> {
        AriaEndpoint.post(path(companyId, provider, "oauth", "start"),
                          body: AdminConnectorOAuthStartRequest(requestWrite: requestWrite)).snakeCased()
    }

    /// Consenso personale per un connettore per-membro. Il server non legge il body.
    static func startMyOAuth(companyId: String, provider: String) -> AriaEndpoint<AdminConnectorOAuthStart> {
        AriaEndpoint.post(path(companyId, provider, "me", "oauth", "start")).snakeCased()
    }

    /// Scollega solo l'account di chi chiama.
    static func disconnectMine(companyId: String, provider: String) -> AriaEndpoint<AriaNoContent> {
        AriaEndpoint.delete(path(companyId, provider, "me")).snakeCased()
    }

    // MARK: Connessioni dei membri (owner e admin)

    static func grants(companyId: String, provider: String) -> AriaEndpoint<AdminConnectorGrantList> {
        AriaEndpoint.get(path(companyId, provider, "grants")).snakeCased()
    }

    static func revokeGrant(companyId: String, provider: String, userId: String) -> AriaEndpoint<AriaNoContent> {
        AriaEndpoint.delete(path(companyId, provider, "grants", userId)).snakeCased()
    }

    // MARK: Percorsi

    /// I pezzi vanno così come sono: `appending(path:)` nel client li codifica già.
    private static func base(_ companyId: String) -> String {
        "v1/companies/\(companyId)/connectors"
    }

    private static func path(_ companyId: String, _ provider: String, _ rest: String...) -> String {
        ([base(companyId), provider] + rest).joined(separator: "/")
    }
}
