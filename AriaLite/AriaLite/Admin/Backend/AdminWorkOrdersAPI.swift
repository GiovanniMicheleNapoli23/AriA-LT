//
//  AdminWorkOrdersAPI.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le rotte degli ordini di lavoro per gli account della piattaforma (owner/admin/member), come la pagina
//  /work-orders della web. Tutte `.snakeCased()`: body e risposte in snake_case, modelli in camelCase.
//  Le liste passano da AriaLossyArray: una riga che non si legge si scarta, non svuota la pagina.
//

import Foundation

nonisolated struct AdminWorkOrdersAPI: Sendable {
    let api: AriaAPIClient

    let root = "v1/work-orders"

    // MARK: Ordini

    func list(_ query: AdminWorkOrderQuery) async throws -> [AdminWorkOrder] {
        let page: AriaLossyArray<AdminWorkOrder> = try await api.call(AriaEndpoint(method: "GET", path: root, query: query.items).snakeCased())
        return page.items
    }

    func detail(_ id: String) async throws -> AdminWorkOrder {
        try await api.call(.get("\(root)/\(id)", query: ["include": "procedure"]).snakeCased())
    }

    func stepReports(_ id: String) async throws -> [AdminWorkOrderStepReport] {
        let rows: AriaLossyArray<AdminWorkOrderStepReport> = try await api.call(.get("\(root)/\(id)/step-reports").snakeCased())
        return rows.items
    }

    func create(_ body: AdminWorkOrderCreate) async throws -> AdminWorkOrder {
        try await api.call(.post(root, body: body).snakeCased())
    }

    func update(_ id: String, _ body: AdminWorkOrderUpdate) async throws -> AdminWorkOrder {
        try await api.call(.patch("\(root)/\(id)", body: body).snakeCased())
    }

    func delete(_ id: String) async throws {
        let _: AriaNoContent = try await api.call(.delete("\(root)/\(id)").snakeCased())
    }

    // MARK: Stato, assegnazione, traduzione

    /// POST /complete. Il body ha la sua chiave scritta a mano (`resolution_notes`, vedi
    /// AdminWorkOrderCompleteBody): niente `.snakeCased()`, la risposta si converte a mano. Ogni passo deve
    /// avere un risultato (`steps_incomplete`).
    func complete(_ id: String, resolutionNotes: String) async throws -> AdminWorkOrder {
        let json: AriaJSON = try await api.call(.post("\(root)/\(id)/complete",
                                                      body: AdminWorkOrderCompleteBody(resolutionNotes: resolutionNotes)))
        do { return try json.camelCased().decoded(as: AdminWorkOrder.self) }
        catch { throw AriaError.decoding("AdminWorkOrder: \(error)") }
    }

    /// Rifà la scelta automatica di chi esegue, ignorando l'assegnatario attuale. Senza nessuno disponibile
    /// cambia solo la nota: l'assegnatario non si toglie.
    func autoAssign(_ id: String) async throws -> AdminWorkOrderAutoAssignResult {
        try await api.call(.post("\(root)/\(id)/auto-assign").snakeCased())
    }

    /// Titolo e testi dell'ordine letti in un'altra lingua; sul server non cambia niente.
    func translation(_ id: String, locale: String) async throws -> AdminWorkOrderTranslation {
        let json: AriaJSON = try await api.call(.get("\(root)/\(id)/translation", query: ["locale": locale]))
        return AdminWorkOrderTranslation(json: json.camelCased(), locale: locale)
    }

    // MARK: Passi (planner)

    // Le risposte dei passi non si leggono: dopo ogni modifica il dettaglio si ricarica, perché il risultato
    // sta sia nella procedura sia nei resoconti.

    /// Risultato di un passo (fatto o non fatto, con nota), come lo darebbe l'operatore.
    func reportStep(_ id: String, step stepId: String, status: AdminWorkOrderStepStatus, note: String?) async throws {
        let body = AdminWorkOrderStepReportBody(status: status.rawValue, note: note)
        let _: AriaNoContent = try await api.call(.put("\(root)/\(id)/steps/\(stepId)", body: body).snakeCased())
    }

    /// La spunta del planner: cambia solo lo stato, nota e foto dell'operatore restano.
    func checkStep(_ id: String, step stepId: String, checked: Bool) async throws {
        let _: AriaNoContent = try await api.call(.put("\(root)/\(id)/steps/\(stepId)",
                                                       body: AdminWorkOrderStepCheckBody(checked: checked)).snakeCased())
    }

    /// Spunta o toglie la spunta a tutti i passi insieme.
    func checkAllSteps(_ id: String, checked: Bool) async throws {
        let _: AriaNoContent = try await api.call(.put("\(root)/\(id)/steps",
                                                       body: AdminWorkOrderStepCheckBody(checked: checked)).snakeCased())
    }

    /// Toglie il risultato di un passo, con nota e foto (204).
    func clearStep(_ id: String, step stepId: String) async throws {
        let _: AriaNoContent = try await api.call(.delete("\(root)/\(id)/steps/\(stepId)").snakeCased())
    }

    // MARK: Anagrafiche per il form

    func users() async throws -> [AdminWorkOrderUser] {
        let rows: AriaLossyArray<AdminWorkOrderUser> = try await api.call(.get("v1/users", query: ["active_only": "true"]).snakeCased())
        return rows.items
    }

    func teams(plantId: String?) async throws -> [AdminWorkOrderTeam] {
        let query = plantId.map { [URLQueryItem(name: "plant_id", value: $0)] } ?? []
        let rows: AriaLossyArray<AdminWorkOrderTeam> = try await api.call(AriaEndpoint(method: "GET", path: "v1/teams", query: query).snakeCased())
        return rows.items
    }

    func assets() async throws -> [AdminWorkOrderAsset] {
        let rows: AriaLossyArray<AdminWorkOrderAsset> = try await api.call(.get("v1/assets").snakeCased())
        return rows.items
    }
}
