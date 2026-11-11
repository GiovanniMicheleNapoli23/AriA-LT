//
//  AriaAccess.swift
//  AriaLite
//
//  Created by Giovanni Michele on 03/11/26.
//
//  Ruoli e diritti (guida "Roles & Rights" per le app, 29/10/2026): il blocco `access` di GET /v1/me con
//  `Company-Id`. Un'azienda passata ai ruoli (`model` "rbac") dà a ogni membro un ruolo che concede sezioni e,
//  dentro ciascuna, azioni. Owner e admin (`admin`) hanno tutto. Il server resta l'autorità: ciò che il ruolo
//  non ha è rifiutato alla richiesta successiva, qualunque cosa mostri l'app.
//

import Foundation

/// Il blocco `access` di GET /v1/me. Un backend precedente non lo manda: allora vale tutto come prima.
nonisolated struct AriaAccess: Decodable, Sendable, Equatable {
    nonisolated struct Role: Decodable, Sendable, Equatable {
        let id: String
        let name: String
        let enabled: Bool

        private enum CodingKeys: String, CodingKey { case id, name, enabled }

        init(id: String, name: String, enabled: Bool) {
            self.id = id
            self.name = name
            self.enabled = enabled
        }

        init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(String.self, forKey: .id)
            name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
            enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        }
    }

    nonisolated struct Grant: Decodable, Sendable, Equatable {
        let granted: Bool
        let actions: [String]

        private enum CodingKeys: String, CodingKey { case granted, actions }

        init(granted: Bool, actions: [String] = []) {
            self.granted = granted
            self.actions = actions
        }

        init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            granted = try c.decodeIfPresent(Bool.self, forKey: .granted) ?? false
            actions = try c.decodeIfPresent([String].self, forKey: .actions) ?? []
        }
    }

    /// "rbac" (ruoli accesi) o "legacy" (l'azienda si comporta come prima dei ruoli).
    let model: String
    /// `nil`: il membro non ha un ruolo.
    let role: Role?
    /// Owner o admin: tutto concesso.
    let admin: Bool
    /// Tutte le sezioni, concesse o no, per slug (`work_orders`, `assets`, …).
    let sections: [String: Grant]
    /// Cambia a ogni modifica dei diritti: lo stesso valore torna nell'header `X-Access-Version`.
    let version: String?
    /// La sessione dell'app di un membro segue il suo ruolo: si mostrano le sezioni concesse.
    let appFollowsRole: Bool

    private enum CodingKeys: String, CodingKey { case model, role, admin, sections, version, appFollowsRole }

    init(model: String, role: Role?, admin: Bool, sections: [String: Grant], version: String?, appFollowsRole: Bool) {
        self.model = model
        self.role = role
        self.admin = admin
        self.sections = sections
        self.version = version
        self.appFollowsRole = appFollowsRole
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        model = try c.decodeIfPresent(String.self, forKey: .model) ?? "legacy"
        role = try? c.decodeIfPresent(Role.self, forKey: .role)
        admin = try c.decodeIfPresent(Bool.self, forKey: .admin) ?? false
        sections = (try? c.decodeIfPresent([String: Grant].self, forKey: .sections)) ?? [:]
        version = try c.decodeIfPresent(String.self, forKey: .version)
        appFollowsRole = try c.decodeIfPresent(Bool.self, forKey: .appFollowsRole) ?? false
    }
}

/// Gli slug delle sezioni che l'app usa.
nonisolated enum AriaSection: String, Sendable, CaseIterable {
    case workOrders = "work_orders"
    case marketplace
    case crafted
    case scenarioAnalysis = "scenario_analysis"
    case maintenance
    case taskboard
    case assets
    case spareParts = "spare_parts"
    case alarms
    case vendors
    case llmUsage = "llm_usage"
    case categories
    case auditLog = "audit_log"
    case members
    case teams
}

/// Le azioni dentro una sezione che l'app usa (stesso nome della web).
nonisolated enum AriaSectionAction: String, Sendable, CaseIterable {
    case complete
    case stepPhotos = "step_photos"
    case approve
    case unapprove
    case reject
    case refreshHealth = "refresh_health"
    case acknowledge
    case autoAssign = "auto_assign"
    case bulkReassign = "bulk_reassign"
    case verify
    case cancel
    case reopen
    case stopSession = "stop_session"
    /// Le sezioni "solo da guardare" (Vendors, Categories…): senza queste si apre l'elenco e basta.
    case create
    case edit
    case delete
}

/// Cosa può fare chi ha fatto l'accesso, nell'azienda attiva. Senza blocco `access` (backend precedente), in
/// un'azienda "legacy" e per owner e admin è tutto concesso: l'app si comporta come prima dei ruoli.
nonisolated struct AriaRights: Sendable, Equatable {
    let access: AriaAccess?

    static let unrestricted = AriaRights(access: nil)

    /// Un membro in un'azienda passata ai ruoli: il ruolo può togliere schermate e pulsanti.
    var isRoleBased: Bool {
        guard let access else { return false }
        return access.model == "rbac" && !access.admin
    }

    /// Owner o admin secondo il server. `nil`: il server non lo dice (blocco assente).
    var isCompanyAdmin: Bool? { access?.admin }

    /// La sessione dell'app segue il ruolo: oltre a Task e Calendario si mostrano le sezioni concesse.
    var followsRole: Bool { isRoleBased && access?.appFollowsRole == true }

    /// Nessun ruolo, o un ruolo messo in pausa dall'admin: restano la chat e le schermate sempre disponibili.
    var isPaused: Bool {
        guard isRoleBased, let access else { return false }
        return access.role?.enabled != true
    }

    func has(_ section: AriaSection) -> Bool {
        guard isRoleBased else { return true }
        return !isPaused && access?.sections[section.rawValue]?.granted == true
    }

    func can(_ action: AriaSectionAction, in section: AriaSection) -> Bool {
        guard isRoleBased else { return true }
        return has(section) && access?.sections[section.rawValue]?.actions.contains(action.rawValue) == true
    }

    /// Spostare un asset, un allarme, un ricambio o un piano di manutenzione da `from` a `to` (stati del
    /// server): lo stato mandato nel PATCH, letto contro quello salvato, decide quale azione serve.
    func canMove(from: String, to: String, in section: AriaSection) -> Bool {
        guard from != to else { return true }
        switch to {
        case "approved": return can(.approve, in: section)
        case "rejected", "superseded": return can(.reject, in: section) && (from != "approved" || can(.unapprove, in: section))
        default:
            if from == "rejected" { return can(.reject, in: section) }
            if from == "approved" { return can(.unapprove, in: section) }
            return true
        }
    }

    /// Eliminare un asset, un allarme, un ricambio o un piano vuole quello che servirebbe a rifiutarlo (`reject`, più
    /// `unapprove` se è approvato); niente oltre la sezione se è già rifiutato.
    func canDelete(stored: String, in section: AriaSection) -> Bool {
        has(section) && canMove(from: stored, to: "rejected", in: section)
    }

    /// Portare un lavoro da `from` (`nil`: lo si sta creando) a `to`. Il ciclo di vita prima (409 qualunque sia il
    /// ruolo): un ordine verificato o annullato esce solo verso "proposed", con `reopen`; uno completato non si
    /// annulla. Poi l'azione: "completed" `complete`, "verified" `verify`, "cancelled" `cancel`; il resto nessuna.
    func canMoveWorkOrder(from: String?, to: String) -> Bool {
        guard from != to else { return true }
        if from == "verified" || from == "cancelled" { return to == "proposed" && can(.reopen, in: .workOrders) }
        switch to {
        case "completed": return can(.complete, in: .workOrders)
        case "verified": return can(.verify, in: .workOrders)
        case "cancelled": return from != "completed" && can(.cancel, in: .workOrders)
        default: return true
        }
    }

    /// Eliminare un lavoro vuole quello che serve ad annullarlo: niente di più se è già annullato.
    func canDeleteWorkOrder(status: String) -> Bool {
        status == "cancelled" || can(.cancel, in: .workOrders)
    }
}

/// Il corpo di un 403 `permission_denied` (o l'ultimo evento di uno stream con lo stesso `detail`).
nonisolated struct AriaPermissionDenial: Sendable, Equatable {
    /// `no_section`, `no_action`, `role_disabled`, `no_role`.
    let reason: String?
    let section: String?
    let action: String?
    /// Per le persone: l'app decide su `code` e `reason`.
    let message: String?

    init(reason: String? = nil, section: String? = nil, action: String? = nil, message: String? = nil) {
        self.reason = reason
        self.section = section
        self.action = action
        self.message = message
    }

    /// Da `{"detail": {"code": "permission_denied", …}}`, o dal solo `detail`.
    init?(_ json: AriaJSON) {
        let detail = json["detail"] ?? json
        guard detail["code"]?.stringValue == "permission_denied" else { return nil }
        self.init(reason: detail["reason"]?.stringValue, section: detail["section"]?.stringValue,
                  action: detail["action"]?.stringValue, message: detail["message"]?.stringValue)
    }

    init?(_ data: Data) {
        guard let json = try? JSONDecoder().decode(AriaJSON.self, from: data) else { return nil }
        self.init(json)
    }

    /// Ruolo in pausa o assente: non manca un diritto, manca l'accesso, finché l'admin non lo ridà.
    var pausesAccess: Bool { reason == "role_disabled" || reason == "no_role" }
}
