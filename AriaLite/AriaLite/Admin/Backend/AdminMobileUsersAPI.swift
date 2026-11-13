//
//  AdminMobileUsersAPI.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le rotte dell'accesso all'app (pagina /mobile-users della web), usate dalla scheda della persona in Members:
//  licenze, dare e togliere l'accesso, sospendere l'app, rinnovare l'invito, dispositivi; più gli ordini aperti.
//  ATTENZIONE ai due casing: gli operatori e le sessioni (`/v1/companies/{id}/mobile-users*`) viaggiano in
//  camelCase (`openCount`, `lastActiveAt`), quindi niente `.snakeCased()`; gli ordini di lavoro
//  (`/v1/work-orders*`) sono in snake_case e lo vogliono.
//

import Foundation

nonisolated enum AdminMobileUsersAPI {
    private static func base(_ companyId: String) -> String { "v1/companies/\(companyId)/mobile-users" }

    // MARK: Operatori

    /// GET …/mobile-users: i posti della licenza e tutti gli operatori (niente pagine).
    static func list(companyId: String) -> AriaEndpoint<AdminMobileUsersResponse> {
        .get(base(companyId))
    }

    /// POST …/mobile-users: un utente già dell'azienda diventa operatore.
    static func add(companyId: String, _ body: AdminMobileUserAdd) -> AriaEndpoint<AdminMobileUser> {
        .post(base(companyId), body: body)
    }

    /// PATCH …/mobile-users/{id}: stato (`active` o `suspended`) e specialità.
    static func update(companyId: String, userId: String,
                       _ body: AdminMobileUserUpdate) -> AriaEndpoint<AdminMobileUser> {
        .patch("\(base(companyId))/\(userId)", body: body)
    }

    /// POST …/mobile-users/{id}/resend: rimanda il link di accesso a chi è invitato o con l'invito scaduto.
    static func resend(companyId: String, userId: String) -> AriaEndpoint<AdminMobileUser> {
        .post("\(base(companyId))/\(userId)/resend")
    }

    /// DELETE …/mobile-users/{id}: toglie l'accesso mobile (204).
    static func remove(companyId: String, userId: String) -> AriaEndpoint<AriaNoContent> {
        .delete("\(base(companyId))/\(userId)")
    }

    // MARK: Sessioni (i telefoni su cui è entrato)

    static func sessions(companyId: String, userId: String) -> AriaEndpoint<AriaLossyArray<AdminMobileUserSession>> {
        .get("\(base(companyId))/\(userId)/sessions")
    }

    /// DELETE …/sessions: esce da tutti i dispositivi (204).
    static func revokeAllSessions(companyId: String, userId: String) -> AriaEndpoint<AriaNoContent> {
        .delete("\(base(companyId))/\(userId)/sessions")
    }

    static func revokeSession(companyId: String, userId: String, sessionId: String) -> AriaEndpoint<AriaNoContent> {
        .delete("\(base(companyId))/\(userId)/sessions/\(sessionId)")
    }

    // MARK: Ordini di lavoro (snake_case)

    /// GET /v1/work-orders aperti e assegnati a quell'operatore. `scope=all` sempre: senza, per chi ha un ruolo il
    /// server sostituisce `assigned_to_user_id` con l'id di chi guarda, e la scheda mostrerebbe gli ordini di lui.
    static func openWorkOrders(userId: String) -> AriaEndpoint<AriaLossyArray<AdminMobileUserWorkOrder>> {
        AriaEndpoint<AriaLossyArray<AdminMobileUserWorkOrder>>.get(
            "v1/work-orders",
            query: ["assigned_to_user_id": userId, "status_group": "open", "scope": "all", "limit": "100"]).snakeCased()
    }

    /// GET /v1/work-orders/{id}/step-reports: il risultato di ogni passo (nota, foto, chi l'ha segnato).
    static func stepReports(workOrderId: String) -> AriaEndpoint<AriaLossyArray<AdminMobileUserStepReport>> {
        AriaEndpoint<AriaLossyArray<AdminMobileUserStepReport>>
            .get("v1/work-orders/\(workOrderId)/step-reports").snakeCased()
    }

    /// GET /v1/work-orders/{id}?include=procedure: serve solo per il testo dei passi.
    static func procedure(workOrderId: String) -> AriaEndpoint<AdminMobileUserProcedureOrder> {
        AriaEndpoint<AdminMobileUserProcedureOrder>
            .get("v1/work-orders/\(workOrderId)", query: ["include": "procedure"]).snakeCased()
    }
}
