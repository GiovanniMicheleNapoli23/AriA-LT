//
//  MembersPeopleTests.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 12/11/26.
//
//  Members assorbe Mobile Users (specifica del 12/11/2026): i codici di rifiuto delle persone, il modello con
//  `access`, `access_role` e `is_field`, i body e le chiamate nuove, e le regole pure di AdminMemberRules.
//

import Foundation
import Testing
@testable import AriaLite

// MARK: - Senza rete

struct MembersPeoplePureTests {
    // MARK: Aiuti

    /// Una persona come la manda GET /v1/members (snake_case).
    private func person(_ id: String = "u9", access: String? = "member", membership: String = "member",
                        role: (id: String, set: String)? = nil, field: Bool = true) throws -> AdminMember {
        let accessJSON = access.map { "\"\($0)\"" } ?? "null"
        let roleJSON = role.map { #"{"id":"\#($0.id)","name":"Role \#($0.id)","set":"\#($0.set)"}"# } ?? "null"
        let json = #"{"id":"\#(id)","email":"\#(id)@acme.test","full_name":"Person \#(id)","is_active":true,"membership_role":"\#(membership)","access":\#(accessJSON),"access_role":\#(roleJSON),"is_field":\#(field)}"#
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(AdminMember.self, from: Data(json.utf8))
    }

    /// Una riga di GET …/mobile-users (camelCase).
    private func row(_ status: String, id: String = "u9", availability: String = "available",
                     invitedUntil: String? = nil) throws -> AdminMobileUser {
        let until = invitedUntil.map { #","invitedUntil":"\#($0)""# } ?? ""
        let json = #"{"id":"\#(id)","name":"Person \#(id)","email":"\#(id)@acme.test","status":"\#(status)","availability":"\#(availability)"\#(until)}"#
        return try JSONDecoder().decode(AdminMobileUser.self, from: Data(json.utf8))
    }

    private func seats(used: Int, total: Int) throws -> AdminMobileUserSeats {
        try JSONDecoder().decode(AdminMobileUserSeats.self, from: Data(#"{"used":\#(used),"total":\#(total)}"#.utf8))
    }

    private static let roleHolderSections = #"{"members":{"granted":true,"actions":["edit","assign_shifts"]}}"#

    /// Chi ha un ruolo (non admin) con i diritti dati; `canManage` e `ownRoleId` per un ruolo alto.
    private func holder(sections: String? = nil, set: String = "low", canManage: Bool = false,
                        ownRoleId: String? = nil, userId: String? = "me") throws -> AdminPeopleViewer {
        let sections = sections ?? Self.roleHolderSections
        let access = try JSONDecoder().decode(AriaAccess.self, from: Data(TestEnv.accessJSON(
            role: #"{"id":"rMe","name":"Mine","set":"\#(set)","enabled":true}"#, sections: sections,
            canManageRoles: canManage).utf8))
        return AdminPeopleViewer(userId: userId, membershipRole: "member", rights: AriaRights(access: access),
                                 canManageRoles: canManage, ownRoleId: ownRoleId)
    }

    private func admin(userId: String? = "me", role: String = "admin") -> AdminPeopleViewer {
        AdminPeopleViewer(userId: userId, membershipRole: role, rights: .unrestricted, canManageRoles: true)
    }

    // MARK: Task 1

    @Test func peopleRefusalsKeepTheirCode() {
        func refusal(_ status: Int, _ code: String) -> AriaError? {
            let response = HTTPURLResponse(url: URL(string: "https://api.test/x")!, statusCode: status, httpVersion: nil, headerFields: nil)!
            do {
                try AriaHTTP.check(response, Data(#"{"detail":{"code":"\#(code)","message":"m"}}"#.utf8))
                return nil
            } catch { return error as? AriaError }
        }
        for code in AriaPeopleRefusal.allCases {
            guard case .peopleRefused(let found, let detail)? = refusal(409, code.rawValue) else {
                Issue.record("\(code.rawValue) dovrebbe restare un rifiuto delle persone")
                continue
            }
            #expect(found == code)
            #expect(detail == "m")
            #expect(!code.message.isEmpty)
        }
        // Un 403 con lo stesso codice è il rifiuto dei diritti (Agent Studio): non diventa un rifiuto delle persone.
        guard case .http(403, _)? = refusal(403, "membership_suspended") else {
            Issue.record("un 403 membership_suspended resta un 403 qualsiasi")
            return
        }
    }

    @Test func assignShiftsIsASectionAction() {
        #expect(AriaSectionAction(rawValue: "assign_shifts") == .assignShifts)
    }

    // MARK: Task 2

    @Test func memberDecodesAccessRoleAndField() throws {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        func decode(_ json: String) throws -> AdminMember { try decoder.decode(AdminMember.self, from: Data(json.utf8)) }

        let full = try decode(#"{"id":"u1","email":"a@b.it","access":"operator_suspended","access_role":{"id":"r1","name":"Night","set":"low"},"membership_role":"member","is_field":true}"#)
        #expect(full.access == .operatorSuspended)
        #expect(full.accessRole == AdminMemberRoleBrief(id: "r1", name: "Night", set: "low"))
        #expect(full.membershipRole == "member")
        #expect(full.isField)
        #expect(full.access?.hasAppAccess == true)
        #expect(full.isRegularMember && !full.isOwnerOrAdmin && !full.isSuspendedInCompany)

        let weird = try decode(#"{"id":"u2","access":"weird","membership_role":"mobile_operator"}"#)
        #expect(weird.access == nil, "un valore sconosciuto vale nil")
        #expect(weird.isRegularMember, "mobile_operator vale come member")
        #expect(weird.accessRole == nil)
        #expect(!weird.isField, "senza il campo: non lavora sul campo")

        let legacy = try decode(#"{"id":"u3","access":null,"access_role":null,"membership_role":"owner"}"#)
        #expect(legacy.access == nil && legacy.accessRole == nil)
        #expect(legacy.isOwner && legacy.isOwnerOrAdmin && !legacy.isRegularMember)

        let suspended = try decode(#"{"id":"u4","access":"suspended","membership_role":"admin"}"#)
        #expect(suspended.isSuspendedInCompany && suspended.isCompanyAdmin)
        #expect(suspended.access?.hasAppAccess == false)

        let brokenRole = try decode(#"{"id":"u5","access_role":{"name":"No id"}}"#)
        #expect(brokenRole.accessRole == nil, "un ruolo illeggibile non fa cadere la persona")
    }

    @Test func createBodyHasNoPasswordAndAlwaysTheRole() throws {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let body = AdminMemberUserCreate(email: "a@b.it", fullName: "A", role: nil, accessRoleId: "r1")
        let json = try #require(JSONSerialization.jsonObject(with: try encoder.encode(body)) as? [String: Any])
        #expect(Set(json.keys) == ["email", "full_name", "access_role_id"])
        #expect(json["access_role_id"] as? String == "r1")

        let withLabel = AdminMemberUserCreate(email: "a@b.it", fullName: "A", role: "technician", accessRoleId: "r1")
        let labelled = try #require(JSONSerialization.jsonObject(with: try encoder.encode(withLabel)) as? [String: Any])
        #expect(labelled["role"] as? String == "technician")
    }

    @Test func updateSendsOnlyWhatChanged() throws {
        #expect(String(decoding: try JSONEncoder().encode(AdminMemberUpdate(field: true)), as: UTF8.self) == #"{"field":true}"#)
        #expect(String(decoding: try JSONEncoder().encode(AdminMemberUpdate(status: "suspended")), as: UTF8.self) == #"{"status":"suspended"}"#)
        let all = AdminMemberUpdate(name: "N", label: "manager", specialties: ["HVAC"], field: false, status: "active")
        let json = try #require(JSONSerialization.jsonObject(with: try JSONEncoder().encode(all)) as? [String: Any])
        #expect(Set(json.keys) == ["name", "label", "specialties", "field", "status"])
    }

    @Test func aCreatedUserCarriesItsId() throws {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let created = try decoder.decode(AdminMemberCreated.self, from: Data(#"{"id":"u9","email":"m@acme.test","full_name":"Mario"}"#.utf8))
        #expect(created.id == "u9" && created.email == "m@acme.test" && created.fullName == "Mario")
        #expect(throws: DecodingError.self) { try decoder.decode(AdminMemberCreated.self, from: Data(#"{"email":"m@acme.test"}"#.utf8)) }
    }

    // MARK: Task 3 - Chi può fare cosa

    @Test func aRoleHolderReachesOnlyLowOrNoRoleMembers() throws {
        let viewer = try holder()
        let reachable = [try person("low", role: (id: "r1", set: "low")), try person("none")]
        for member in reachable {
            #expect(AdminMemberRules.reaches(viewer, member), "\(member.id)")
            #expect(AdminMemberRules.canEditProfile(viewer, member), "\(member.id)")
            #expect(AdminMemberRules.canAssignShifts(viewer, member), "\(member.id)")
        }
        let beyond = [try person("high", role: (id: "rH", set: "high")),
                      try person("owner", access: "owner", membership: "owner"),
                      try person("admin", access: "admin", membership: "admin"),
                      try person("legacy", access: nil)]
        for member in beyond {
            #expect(!AdminMemberRules.canEditProfile(viewer, member), "\(member.id)")
            #expect(!AdminMemberRules.canAssignShifts(viewer, member), "\(member.id)")
        }
        // Senza le azioni nel ruolo, nemmeno su chi raggiunge.
        let noActions = try holder(sections: #"{"members":{"granted":true,"actions":[]}}"#)
        #expect(!AdminMemberRules.canEditProfile(noActions, reachable[0]))
        #expect(!AdminMemberRules.canAssignShifts(noActions, reachable[0]))
        // Un admin raggiunge tutti.
        #expect(AdminMemberRules.canEditProfile(admin(), beyond[0]))
        #expect(AdminMemberRules.canAssignShifts(admin(), beyond[1]))
        let roleHolder = try holder()
        #expect(AdminMemberRules.canCreate(admin()) && !AdminMemberRules.canCreate(roleHolder))
    }

    @Test func profileFieldsAreLockedWithoutFieldWork() throws {
        #expect(AdminMemberRules.profileFieldsLocked(try person(field: false)))
        #expect(!AdminMemberRules.profileFieldsLocked(try person(field: true)))
    }

    @Test func ownersAreProtected() throws {
        let owner = try person("o1", access: "owner", membership: "owner")
        let suspendedOwner = try person("o2", access: "suspended", membership: "owner")
        let peer = try person("a1", access: "admin", membership: "admin")
        let regular = try person("m1")

        // Un admin non tocca un titolare.
        #expect(!AdminMemberRules.canChangeCompanyStatus(admin(), owner, activeOwners: 2))
        #expect(!AdminMemberRules.canRemove(admin(), owner, activeOwners: 2))
        #expect(AdminMemberRules.canChangeCompanyStatus(admin(), peer, activeOwners: 1))
        #expect(AdminMemberRules.canRemove(admin(), regular, activeOwners: 1))

        // Un titolare: non l'ultimo titolare attivo.
        let viewer = admin(role: "owner")
        #expect(!AdminMemberRules.canChangeCompanyStatus(viewer, owner, activeOwners: 1))
        #expect(AdminMemberRules.canChangeCompanyStatus(viewer, owner, activeOwners: 2))
        #expect(!AdminMemberRules.canRemove(viewer, owner, activeOwners: 1))
        #expect(AdminMemberRules.canRemove(viewer, owner, activeOwners: 2))
        #expect(AdminMemberRules.canChangeCompanyStatus(viewer, suspendedOwner, activeOwners: 1), "riattivare si può sempre")

        // Mai su se stessi.
        let me = try person("me")
        #expect(!AdminMemberRules.canChangeCompanyStatus(admin(), me, activeOwners: 3))
        #expect(!AdminMemberRules.canRemove(admin(), me, activeOwners: 3))

        // Senza sapere chi si è: nessuna azione su nessuno.
        let unknown = admin(userId: nil)
        for member in [regular, peer, owner, me] {
            #expect(!AdminMemberRules.canChangeCompanyStatus(unknown, member, activeOwners: 3), "\(member.id)")
            #expect(!AdminMemberRules.canRemove(unknown, member, activeOwners: 3), "\(member.id)")
        }
        // Un ruolo non sospende né rimuove.
        #expect(!AdminMemberRules.canChangeCompanyStatus(try holder(), regular, activeOwners: 3))
        #expect(!AdminMemberRules.canRemove(try holder(), regular, activeOwners: 3))
        // Il record senza membership non si tocca.
        #expect(!AdminMemberRules.canRemove(admin(), try person("legacy", access: nil), activeOwners: 3))
    }

    // MARK: Task 3 - Ruolo

    @Test func roleChoicesMirrorTheWeb() throws {
        let roles = [AdminRole(id: "rH", name: "H", set: .high),
                     AdminRole(id: "low1", name: "Low 1", set: .low, ownerRoleId: "rH"),
                     AdminRole(id: "low2", name: "Low 2", set: .low, ownerRoleId: "rX")]
        let noRole = try person("m1")
        let withLow1 = try person("m2", role: (id: "low1", set: "low"))
        let withLow2 = try person("m3", role: (id: "low2", set: "low"))
        let withHigh = try person("m4", role: (id: "rH", set: "high"))

        // Owner e admin: tutti i ruoli; "Nessun ruolo" solo se ne ha uno.
        let all = try #require(AdminMemberRules.roleChoices(admin(), noRole, roles: roles))
        #expect(all.options.map(\.id) == ["rH", "low1", "low2"] && !all.canUnassign)
        #expect(AdminMemberRules.roleChoices(admin(), withLow1, roles: roles)?.canUnassign == true)
        #expect(AdminMemberRules.roleChoices(admin(), withHigh, roles: roles)?.canUnassign == true)

        // Un ruolo alto: i Low creati dal suo ruolo, e niente su chi ha un ruolo High.
        let high = try holder(set: "high", canManage: true, ownRoleId: "rH")
        let mine = try #require(AdminMemberRules.roleChoices(high, noRole, roles: roles))
        #expect(mine.options.map(\.id) == ["low1"] && !mine.canUnassign)
        #expect(AdminMemberRules.roleChoices(high, withLow1, roles: roles)?.canUnassign == true)
        let other = try #require(AdminMemberRules.roleChoices(high, withLow2, roles: roles))
        #expect(other.options.map(\.id) == ["low1"] && !other.canUnassign, "il ruolo di un altro ruolo alto non si toglie")
        #expect(AdminMemberRules.roleChoices(high, withHigh, roles: roles) == nil)
        #expect(AdminMemberRules.roleChoices(high, noRole, roles: [roles[0], roles[2]]) == nil, "non resta niente")

        // Chi non gestisce i ruoli, titolari e admin, record senza membership: niente.
        #expect(AdminMemberRules.roleChoices(try holder(), noRole, roles: roles) == nil)
        #expect(AdminMemberRules.roleChoices(admin(), try person("o", access: "owner", membership: "owner"), roles: roles) == nil)
        #expect(AdminMemberRules.roleChoices(admin(), try person("a", access: "admin", membership: "admin"), roles: roles) == nil)
        #expect(AdminMemberRules.roleChoices(admin(), try person("legacy", access: nil), roles: roles) == nil)
        // Un ruolo alto senza un ruolo proprio attivo non offre niente (non confonde "nessun creatore" con il suo).
        let paused = try holder(set: "high", canManage: true, ownRoleId: nil)
        #expect(AdminMemberRules.roleChoices(paused, noRole, roles: roles + [AdminRole(id: "seed", name: "Seed", set: .low)]) == nil)
    }

    @Test func preselectionPrefersTheLabelSeed() {
        let tech = AdminRole(id: "tech", name: "Technician", set: .low, seedKey: "technician")
        let def = AdminRole(id: "def", name: "Default", set: .low, isDefault: true)
        #expect(AdminMemberRules.preselectedRole([tech, def], label: "technician") == "tech")
        #expect(AdminMemberRules.preselectedRole([tech, def], label: nil) == "def")
        #expect(AdminMemberRules.preselectedRole([tech, def], label: "") == "def")
        #expect(AdminMemberRules.preselectedRole([tech, def], label: "manager") == "def", "nessun ruolo base per quella qualifica")

        let pausedSeed = AdminRole(id: "tech", name: "Technician", set: .low, enabled: false, seedKey: "technician")
        #expect(AdminMemberRules.preselectedRole([pausedSeed, def], label: "technician") == "def", "il ruolo base in pausa si salta")
        let pausedDefault = AdminRole(id: "def", name: "Default", set: .low, enabled: false, isDefault: true)
        #expect(AdminMemberRules.preselectedRole([pausedSeed, pausedDefault], label: "technician") == nil)
        #expect(AdminMemberRules.preselectedRole([], label: nil) == nil)
    }

    // MARK: Task 3 - Accesso all'app

    @Test func companySuspensionHidesTheAppState() throws {
        let member = try person(access: "suspended")
        // Con la persona sospesa in azienda la riga dice `suspended` anche se era `revoked`.
        for status in ["suspended", "revoked", "active", "invited", "expired"] {
            let state = AdminMemberRules.appAccessState(member, row: try row(status))
            #expect(state == .companySuspended(hasRow: true), "riga \(status)")
            let offers = AdminMemberRules.appOffers(state, seats: nil)
            #expect(offers == [AdminAppAccessOffer(action: .revokeAccess, isEnabled: true)], "riga \(status)")
            #expect(!offers.contains { $0.action == .reactivateApp })
        }
        let withoutRow = AdminMemberRules.appAccessState(member, row: nil)
        #expect(withoutRow == .companySuspended(hasRow: false))
        #expect(AdminMemberRules.appOffers(withoutRow, seats: nil).isEmpty, "dare l'accesso darebbe 409 membership_suspended")
    }

    @Test func appStateComesFromTheRowThenFromAccess() throws {
        let owner = try person("o", access: "owner", membership: "owner")
        #expect(AdminMemberRules.appAccessState(owner, row: nil) == .ownerOrAdmin)
        #expect(AdminMemberRules.appOffers(.ownerOrAdmin, seats: nil).isEmpty)

        let plain = try person()
        #expect(AdminMemberRules.appAccessState(plain, row: nil) == AdminAppAccessState.none)
        #expect(AdminMemberRules.appAccessState(plain, row: try row("revoked")) == AdminAppAccessState.none)

        let invitedUntil = "2026-11-24T10:00:00Z"
        let invitedRow = try row("invited", invitedUntil: invitedUntil)
        #expect(invitedRow.invitedUntil != nil)
        let invited = try person(access: "operator_invited")
        #expect(AdminMemberRules.appAccessState(invited, row: invitedRow) == .invited(until: invitedRow.invitedUntil))
        #expect(AdminMemberRules.appAccessState(invited, row: nil) == .invited(until: nil), "senza riga si legge da access")

        let expiredRow = try row("expired", invitedUntil: invitedUntil)
        #expect(AdminMemberRules.appAccessState(invited, row: expiredRow) == .expired(on: expiredRow.invitedUntil))

        let active = try person(access: "operator")
        #expect(AdminMemberRules.appAccessState(active, row: try row("active", availability: "busy")) == .active(availability: "busy"))
        #expect(AdminMemberRules.appAccessState(active, row: nil) == .active(availability: ""))

        let appSuspended = try person(access: "operator_suspended")
        #expect(AdminMemberRules.appAccessState(appSuspended, row: try row("suspended")) == .appSuspended)
        #expect(AdminMemberRules.appAccessState(appSuspended, row: nil) == .appSuspended)
    }

    @Test func offersFollowTheTableAndSeats() throws {
        let open = try seats(used: 3, total: 10)
        let full = try seats(used: 10, total: 10)
        let states: [(AdminAppAccessState, [AdminAppAccessAction])] = [
            (.none, [.giveAccess]),
            (.invited(until: nil), [.resendInvite, .revokeAccess]),
            (.expired(on: nil), [.renewAndResend, .revokeAccess]),
            (.active(availability: "free"), [.suspendApp, .revokeAccess]),
            (.appSuspended, [.reactivateApp, .revokeAccess])
        ]
        let needsSeat: Set<AdminAppAccessAction> = [.giveAccess, .renewAndResend, .reactivateApp]
        for (state, actions) in states {
            let withSeats = AdminMemberRules.appOffers(state, seats: open)
            #expect(withSeats.map(\.action) == actions, "\(state)")
            #expect(withSeats.allSatisfy { $0.isEnabled }, "\(state): con licenze libere tutto è attivo")
            #expect(AdminMemberRules.appOffers(state, seats: nil).allSatisfy { $0.isEnabled }, "senza dati sulle licenze non si blocca")

            let noSeats = AdminMemberRules.appOffers(state, seats: full)
            #expect(noSeats.map(\.action) == actions, "\(state)")
            for offer in noSeats {
                #expect(offer.isEnabled == !needsSeat.contains(offer.action), "\(state) \(offer.action)")
            }
        }
    }

    @Test func fieldToggleRules() throws {
        let viewer = admin()
        for access in ["operator", "operator_invited", "operator_suspended"] {
            #expect(AdminMemberRules.fieldToggle(viewer, try person(access: access), hasMobileRow: true) == .removeAppAccessFirst, "\(access)")
        }
        let suspended = try person(access: "suspended")
        #expect(AdminMemberRules.fieldToggle(viewer, suspended, hasMobileRow: true) == .reactivateFirst, "qualsiasi riga, anche revocata")
        #expect(AdminMemberRules.fieldToggle(viewer, suspended, hasMobileRow: false) == .enabled)
        #expect(AdminMemberRules.fieldToggle(try holder(), suspended, hasMobileRow: false) == .adminOnly)
        #expect(AdminMemberRules.fieldToggle(viewer, try person(), hasMobileRow: false) == .enabled)
        #expect(AdminMemberRules.fieldToggle(try holder(), try person(), hasMobileRow: false) == .enabled)
        #expect(AdminMemberRules.fieldToggle(try holder(), try person("high", role: (id: "rH", set: "high")), hasMobileRow: false) == .notAllowed)
        #expect(AdminMemberRules.fieldToggle(viewer, try person("legacy", access: nil), hasMobileRow: false) == .notAllowed)
    }

    @Test func aSeatIsHeldOnlyWhenActiveOrInvited() throws {
        let active = try person(access: "operator")
        #expect(AdminMemberRules.holdsSeat(active, row: try row("active")))
        #expect(AdminMemberRules.holdsSeat(try person(access: "operator_invited"), row: try row("invited")))
        for status in ["expired", "suspended", "revoked"] {
            #expect(!AdminMemberRules.holdsSeat(active, row: try row(status)), "\(status)")
        }
        #expect(!AdminMemberRules.holdsSeat(active, row: nil))
        #expect(!AdminMemberRules.holdsSeat(try person(access: "suspended"), row: try row("active")), "sospesa in azienda: la licenza è libera")
    }

    // MARK: Task 3 - Elenco

    @Test func badgesAndRoleLine() throws {
        func badge(_ access: String?, row status: String? = nil) throws -> AdminMemberBadgeKind? {
            AdminMemberRules.badge(try person(access: access), row: try status.map { try row($0) })
        }
        #expect(try badge("suspended") == .companySuspended)
        #expect(try badge("operator_invited") == .appInvited)
        #expect(try badge("operator_invited", row: "invited") == .appInvited)
        #expect(try badge("operator_invited", row: "expired") == .appInviteExpired)
        #expect(try badge("operator_suspended") == .appSuspended)
        #expect(try badge("operator") == .appActive)
        for access in ["owner", "admin", "member"] { #expect(try badge(access) == nil, "\(access)") }
        #expect(try badge(nil) == nil, "legacy: nessun badge")

        let owner = try person("o", access: "owner", membership: "owner")
        let adminPerson = try person("a", access: "admin", membership: "admin")
        #expect(AdminMemberRules.roleLine(owner, viewerCanManageRoles: false) == String(localized: "Owner"))
        #expect(AdminMemberRules.roleLine(adminPerson, viewerCanManageRoles: false) == String(localized: "Admin"))
        let withRole = try person("r", role: (id: "r1", set: "low"))
        #expect(AdminMemberRules.roleLine(withRole, viewerCanManageRoles: false) == "Role r1")
        let noRole = try person("n")
        #expect(AdminMemberRules.roleLine(noRole, viewerCanManageRoles: false) == nil, "a chi non dà ruoli, niente")
        #expect(AdminMemberRules.roleLine(noRole, viewerCanManageRoles: true) == String(localized: "Needs a role"))
    }

    // MARK: - Elenco e creazione

    @Test func theStatusFilterReadsAccessNotIsActive() throws {
        // `is_active` è vero per tutti nell'aiuto: lo stato viene solo da `access`.
        let suspended = try person("s", access: "suspended")
        #expect(AdminMemberStatusFilter.suspended.matches(suspended))
        #expect(!AdminMemberStatusFilter.active.matches(suspended))
        let pairs: [(String, AdminMemberStatusFilter)] = [
            ("operator", .appActive), ("operator_invited", .appInvited), ("operator_suspended", .appSuspended)]
        for (access, filter) in pairs {
            let member = try person("p", access: access)
            #expect(filter.matches(member), "\(access)")
            #expect(AdminMemberStatusFilter.active.matches(member), "l'app non è la sospensione in azienda")
            #expect(!AdminMemberStatusFilter.suspended.matches(member))
        }
        let legacy = try person("l", access: nil)
        #expect(AdminMemberStatusFilter.active.matches(legacy) && !AdminMemberStatusFilter.suspended.matches(legacy))
    }

    @Test func theRoleFilterKnowsOwnersAdminsAndNoRole() throws {
        let owner = try person("o", access: "owner", membership: "owner")
        let adminPerson = try person("a", access: "admin", membership: "admin")
        let withRole = try person("r", role: (id: "r1", set: "low"))
        let noRole = try person("n")
        let key = AdminMemberRoleFilter.ownersAndAdmins
        #expect(AdminMemberRoleFilter.matches(key, owner) && AdminMemberRoleFilter.matches(key, adminPerson))
        #expect(!AdminMemberRoleFilter.matches(key, withRole) && !AdminMemberRoleFilter.matches(key, noRole))
        let none = AdminMemberRoleFilter.noRole
        #expect(AdminMemberRoleFilter.matches(none, noRole))
        #expect(!AdminMemberRoleFilter.matches(none, withRole) && !AdminMemberRoleFilter.matches(none, owner))
        #expect(AdminMemberRoleFilter.matches("r1", withRole))
        #expect(!AdminMemberRoleFilter.matches("r1", noRole) && !AdminMemberRoleFilter.matches("r2", withRole))
    }

    @Test func aLabelIsAClosedListAndEmptyIsNeverSent() {
        #expect(AdminMemberLabel.allCases == [.none, .technician, .manager])
        #expect(AdminMemberLabel.none.apiValue == nil)
        #expect(AdminMemberLabel.technician.apiValue == "technician")
        #expect(AdminMemberLabel.manager.apiValue == "manager")
    }

    @MainActor
    @Test func nameAndEmailFollowTheForm() {
        #expect(!AdminMemberCreateViewModel.isValidName(""))
        #expect(AdminMemberCreateViewModel.isValidName("A"))
        #expect(AdminMemberCreateViewModel.isValidName(String(repeating: "a", count: 100)))
        #expect(!AdminMemberCreateViewModel.isValidName(String(repeating: "a", count: 101)))
        #expect(AdminMemberCreateViewModel.isPlausibleEmail("a@b.it"))
        #expect(!AdminMemberCreateViewModel.isPlausibleEmail("a@b"))
        #expect(!AdminMemberCreateViewModel.isPlausibleEmail("a b@c.it"))
    }

    // MARK: - Navigazione

    private func roleRights(sections: String) throws -> AriaRights {
        let json = TestEnv.accessJSON(sections: sections)
        return AriaRights(access: try JSONDecoder().decode(AriaAccess.self, from: Data(json.utf8)))
    }

    @Test func roleHoldersWithMembersSeeTheSection() throws {
        let withMembers = try roleRights(sections: Self.roleHolderSections)
        #expect(AriaSidebarSections.destinations(operatorLayout: true, rights: withMembers).contains(.adminMembers))
        let without = try roleRights(sections: #"{"members":{"granted":false,"actions":[]}}"#)
        #expect(!AriaSidebarSections.destinations(operatorLayout: true, rights: without).contains(.adminMembers))
    }

    @Test func adminSidebarKeepsMembers() {
        let destinations = AriaSidebarSections.destinations(operatorLayout: false, rights: .unrestricted)
        #expect(destinations.contains(.adminMembers))
    }
}

// MARK: - Con la rete finta

extension BackendTests {
    @Suite("Members people")
    @MainActor
    struct MembersPeople {
        private let server = StubServer.shared

        init() { TestEnv.reset() }

        private func connected() async throws -> AriaBackend {
            let backend = try await TestEnv.signedInStore().backend
            await TestEnv.grant(TestEnv.accessJSON(admin: true, role: nil, sections: "{}", canManageRoles: true),
                                to: backend, restricted: false)
            return backend
        }

        // MARK: Task 1

        private func refusal(_ status: Int, _ body: String) -> AriaError? {
            let response = HTTPURLResponse(url: URL(string: "https://api.test/x")!, statusCode: status, httpVersion: nil, headerFields: nil)!
            do {
                try AriaHTTP.check(response, Data(body.utf8))
                return nil
            } catch { return error as? AriaError }
        }

        @Test func roleNotFoundIsNotAMissingPerson() async throws {
            let backend = try await connected()
            let body = #"{"detail":{"code":"role_not_found","message":"m"}}"#
            guard case .accessRefused(.roleNotFound)? = refusal(404, body) else {
                Issue.record("role_not_found (404) dovrebbe restare un rifiuto dei ruoli")
                return
            }
            let error = try #require(refusal(404, body))
            let failure = try #require(AdminMembersFailure.from(error, action: .write, backend: backend))
            #expect(!failure.isNotFound, "non è una persona sparita")
            #expect(failure.accessRefusal == .roleNotFound)
            #expect(failure.message == AriaAccessRefusal.roleNotFound.localized)

            // `role_not_assignable` è un 422: si legge dal codice, come gli altri.
            let notAssignable = try #require(refusal(422, #"{"detail":{"code":"role_not_assignable","message":"m"}}"#))
            #expect(AdminMembersFailure.from(notAssignable, action: .write, backend: backend)?.accessRefusal == .roleNotAssignable)

            // Un 404 senza codice è davvero una persona che non c'è più.
            let gone = try #require(refusal(404, #"{"detail":"Member not found"}"#))
            let missing = try #require(AdminMembersFailure.from(gone, action: .write, backend: backend))
            #expect(missing.isNotFound && missing.accessRefusal == nil && missing.refusal == nil)
        }

        @Test func aCodelessConflictKeepsTheServerText() async throws {
            let backend = try await connected()
            let error = try #require(refusal(409, #"{"detail":"Cannot remove the last owner"}"#))
            guard case .http(409, "Cannot remove the last owner") = error else {
                Issue.record("un 409 senza codice resta .http con il testo del server: \(error)")
                return
            }
            let failure = try #require(AdminMembersFailure.from(error, action: .write, backend: backend))
            #expect(failure.message == "Cannot remove the last owner")
            #expect(!failure.isNotFound && !failure.isForbidden && failure.refusal == nil)

            let unprocessable = AriaError.http(status: 422, detail: "Name is too long")
            #expect(AdminMembersFailure.from(unprocessable, action: .write, backend: backend)?.message == "Name is too long")
        }

        @Test func aPeopleRefusalBecomesItsMessage() async throws {
            let backend = try await connected()
            let error = try #require(refusal(409, #"{"detail":{"code":"seat_limit_reached","message":"No seats"}}"#))
            let failure = try #require(AdminMembersFailure.from(error, action: .write, backend: backend))
            #expect(failure.refusal == .seatLimitReached)
            #expect(failure.message == AriaPeopleRefusal.seatLimitReached.message)
            #expect(!failure.isNotFound && !failure.isForbidden)
        }

        // MARK: Task 2

        @Test func theListAsksForEveryone() async throws {
            let backend = try await connected()
            server.route("GET /v1/members", .json("[]"))
            let members = try await AdminMembersAPI(api: backend.api).list()
            #expect(members.isEmpty)
            let call = try #require(server.calls("GET /v1/members").last)
            let query = try #require(call.query)
            #expect(query.contains("field_only=false"))
            #expect(query.contains("active_only=false"))
        }

        @Test func openOrdersAlwaysAskForAll() async throws {
            let backend = try await connected()
            server.route("GET /v1/work-orders", .json("[]"))
            let rows = try await backend.api.call(AdminMobileUsersAPI.openWorkOrders(userId: "u9"))
            #expect(rows.items.isEmpty)
            let query = try #require(server.calls("GET /v1/work-orders").last?.query)
            #expect(query.contains("scope=all"))
            #expect(query.contains("assigned_to_user_id=u9"))
            #expect(query.contains("status_group=open"))
        }

        @Test func updateAndRemoveUseTheirRoutes() async throws {
            let backend = try await connected()
            let api = AdminMembersAPI(api: backend.api)
            server.route("PATCH /v1/members/u9", .json(#"{"id":"u9","email":"u9@acme.test","access":"suspended","is_field":true}"#))
            let updated = try await api.update(userId: "u9", AdminMemberUpdate(status: "suspended"))
            #expect(updated.access == .suspended)
            #expect(server.calls("PATCH /v1/members/u9").last?.json?["status"] as? String == "suspended")

            server.route("DELETE /v1/companies/c1/members/u9", .noContent)
            try await api.removeFromCompany(companyId: "c1", userId: "u9")
            #expect(server.calls("DELETE /v1/companies/c1/members/u9").count == 1)

            server.route("POST /v1/users", .json(#"{"id":"u10","email":"n@acme.test","full_name":"New"}"#, status: 201))
            let created = try await api.createUser(AdminMemberUserCreate(email: "n@acme.test", fullName: "New", accessRoleId: "r1"))
            #expect(created.id == "u10")
            let body = try #require(server.calls("POST /v1/users").last?.json)
            #expect(Set(body.keys) == ["email", "full_name", "access_role_id"], "niente password né role vuoto")
        }

        @Test func inviteLinkGoesToTheWebWithTheSession() async throws {
            let backend = try await connected()
            server.route("POST /api/auth/mobile/invite-link", .json(#"{"sent":false}"#, status: 202))
            let sent = try await backend.api.auth.sendMobileInviteLink(companyId: "c1", userId: "u9")
            #expect(!sent, "sent:false: ha già tre link validi")
            let call = try #require(server.calls("POST /api/auth/mobile/invite-link").first)
            #expect(call.host == backend.authURL.host(), "sull'host della web, non dell'API")
            #expect(call.header("authorization") == "Bearer SESSION", "con la sessione, non con il JWT")
            #expect(call.json?["companyId"] as? String == "c1")
            #expect(call.json?["userId"] as? String == "u9")

            server.route("POST /api/auth/mobile/invite-link", .json(#"{"sent":true}"#, status: 202))
            #expect(try await backend.api.auth.sendMobileInviteLink(companyId: "c1", userId: "u9"))
        }

        @Test func anInviteLinkWithoutAnOpenInvitationIsA404() async throws {
            let backend = try await connected()
            server.route("POST /api/auth/mobile/invite-link", .json(#"{"detail":"No open invitation"}"#, status: 404))
            do {
                _ = try await backend.api.auth.sendMobileInviteLink(companyId: "c1", userId: "u9")
                Issue.record("un invito chiuso dovrebbe dare un errore")
            } catch AriaError.http(404, let detail) {
                #expect(detail == "No open invitation")
            }
        }

        // MARK: Task 3

        @Test func theViewerComesFromTheBackend() async throws {
            let backend = try await connected()
            let viewer = AdminPeopleViewer(backend: backend)
            #expect(viewer.isAdmin, "lo dice il blocco access anche con myRole member")
            #expect(viewer.userId == backend.mobileAccount?.id && viewer.userId != nil)
            #expect(viewer.canManageRoles)
            #expect(viewer.ownRoleId == nil)

            // Un ruolo alto attivo: il suo id è quello che crea i ruoli base.
            await TestEnv.grant(TestEnv.accessJSON(role: #"{"id":"rH","name":"Manager","set":"high","enabled":true}"#,
                                                   sections: "{}", canManageRoles: true), to: backend)
            let high = AdminPeopleViewer(backend: backend)
            #expect(!high.isAdmin && !high.isOwner)
            #expect(high.ownRoleId == "rH" && high.canManageRoles)
            #expect(high.membershipRole == "member")

            // In pausa: non è più il ruolo di nessuno.
            await TestEnv.grant(TestEnv.accessJSON(role: #"{"id":"rH","name":"Manager","set":"high","enabled":false}"#,
                                                   sections: "{}", canManageRoles: false), to: backend)
            #expect(AdminPeopleViewer(backend: backend).ownRoleId == nil)
        }

        // MARK: - Elenco e creazione

        private static let rolesRoute = "GET /v1/companies/c1/access/roles"
        private static let mobileRoute = "GET /v1/companies/c1/mobile-users"
        private static let mobileAddRoute = "POST /v1/companies/c1/mobile-users"
        private static let inviteRoute = "POST /api/auth/mobile/invite-link"

        /// Una persona come la manda GET /v1/members (snake_case).
        private static func personJSON(_ id: String, email: String? = nil, name: String? = nil,
                                       membership: String = "member", access: String? = "member",
                                       role: (id: String, set: String)? = nil, field: Bool = true) -> String {
            let accessJSON = access.map { "\"\($0)\"" } ?? "null"
            let roleJSON = role.map { #"{"id":"\#($0.id)","name":"Role \#($0.id)","set":"\#($0.set)"}"# } ?? "null"
            return #"{"id":"\#(id)","email":"\#(email ?? "\(id)@acme.test")","full_name":"\#(name ?? "Person \(id)")","is_active":true,"membership_role":"\#(membership)","access":\#(accessJSON),"access_role":\#(roleJSON),"is_field":\#(field)}"#
        }

        private static func list(_ people: String...) -> String { "[\(people.joined(separator: ","))]" }

        private static func roleJSON(_ id: String, enabled: Bool = true, isDefault: Bool = false, seed: String? = nil) -> String {
            let seedJSON = seed.map { "\"\($0)\"" } ?? "null"
            return #"{"id":"\#(id)","name":"Role \#(id)","set":"low","enabled":\#(enabled),"isDefault":\#(isDefault),"seedKey":\#(seedJSON)}"#
        }

        private static func roles(_ items: String...) -> String { #"{"roles":[\#(items.joined(separator: ","))]}"# }

        private static func mobileList(used: Int, total: Int, _ rows: String...) -> String {
            #"{"seats":{"used":\#(used),"total":\#(total)},"operators":[\#(rows.joined(separator: ","))]}"#
        }

        private static func mobileRow(_ id: String, status: String) -> String {
            #"{"id":"\#(id)","name":"Person \#(id)","email":"\#(id)@acme.test","status":"\#(status)","availability":"available"}"#
        }

        /// Chi ha un ruolo con la sezione members (senza azioni): non è admin.
        private func roleHolder() async throws -> AriaBackend {
            let backend = try await TestEnv.signedInStore().backend
            await TestEnv.grant(TestEnv.accessJSON(sections: #"{"members":{"granted":true,"actions":[]}}"#), to: backend)
            return backend
        }

        /// Un elenco caricato e un modulo "New person" con nome, email e ruoli (r1 e r2 attivi) già pronti.
        private func newForm(_ backend: AriaBackend, people: String, preload: Bool = false)
            async -> (model: AdminMembersViewModel, form: AdminMemberCreateViewModel) {
            server.route("GET /v1/members", .json(people))
            server.route(Self.rolesRoute, .json(Self.roles(Self.roleJSON("r1"), Self.roleJSON("r2"))))
            server.route("POST /v1/users", .json(#"{"id":"u10","email":"mario@acme.test","full_name":"Mario Rossi"}"#, status: 201))
            let model = AdminMembersViewModel(backend: backend)
            if preload { await model.refresh() }
            let form = AdminMemberCreateViewModel(owner: model)
            await form.loadRoles()
            form.name = "Mario Rossi"
            form.email = "mario@acme.test"
            form.roleId = "r1"
            return (model, form)
        }

        // MARK: Elenco

        @Test func anAdminLoadsSeatsAndMobileRows() async throws {
            let backend = try await connected()
            server.route("GET /v1/members", .json(Self.list(
                Self.personJSON("u9", access: "operator", role: ("r1", "low")),
                Self.personJSON("u8", access: "operator_invited", role: ("r1", "low")),
                Self.personJSON("u7", access: "member"))))
            server.route(Self.mobileRoute, .json(Self.mobileList(
                used: 7, total: 10, Self.mobileRow("u9", status: "active"), Self.mobileRow("u8", status: "expired"))))
            let model = AdminMembersViewModel(backend: backend)
            await model.refresh()

            #expect(model.members.count == 3 && model.failure == nil)
            #expect(model.seats?.used == 7 && model.seats?.total == 10)
            #expect(model.seatsText == String(localized: "App seats: \(7) of \(10)"))
            #expect(!model.seatsAreFull)
            #expect(model.mobileRow(for: "u9")?.status == "active")
            #expect(model.mobileRow(for: "u7") == nil)
            let byId = Dictionary(uniqueKeysWithValues: model.members.map { ($0.id, $0) })
            #expect(model.badge(for: byId["u9"]!) == .appActive)
            #expect(model.badge(for: byId["u8"]!) == .appInviteExpired, "l'invito scaduto lo dice la riga mobile")
            #expect(model.badge(for: byId["u7"]!) == nil)
            #expect(model.roleLine(for: byId["u7"]!) == String(localized: "Needs a role"), "un admin può dare il ruolo")
            #expect(model.canCreate)
        }

        @Test func aRoleHolderNeverCallsMobileUsers() async throws {
            let backend = try await roleHolder()
            server.route("GET /v1/members", .json(Self.list(Self.personJSON("u7", access: "member"))))
            server.route(Self.mobileRoute, .json(Self.mobileList(used: 1, total: 2)))
            let model = AdminMembersViewModel(backend: backend)
            await model.refresh()

            #expect(server.calls(Self.mobileRoute).isEmpty, "…/mobile-users è solo per owner e admin (403)")
            #expect(model.members.count == 1 && model.seats == nil && model.mobileRows.isEmpty)
            #expect(model.seatsText == nil)
            #expect(!model.canCreate)
            model.startCreatingMember()
            #expect(model.newMemberForm == nil, "il \"+\" è solo per owner e admin")
            #expect(model.roleLine(for: model.members[0]) == nil, "chi non dà ruoli non vede \"Needs a role\"")
        }

        @Test func aFailedMobileListKeepsTheMembers() async throws {
            let backend = try await connected()
            server.route("GET /v1/members", .json(Self.list(Self.personJSON("u7", access: "operator"))))
            server.route(Self.mobileRoute, .json(#"{"detail":"boom"}"#, status: 500))
            let model = AdminMembersViewModel(backend: backend)
            await model.refresh()

            #expect(model.members.count == 1 && model.hasLoaded && model.failure == nil)
            #expect(model.seats == nil && model.mobileRows.isEmpty)
            #expect(model.badge(for: model.members[0]) == .appActive, "il badge resta quello di `access`")
        }

        @Test func filtersUseTheAccessRole() async throws {
            let backend = try await connected()
            server.route("GET /v1/members", .json(Self.list(
                Self.personJSON("u1", membership: "owner", access: "owner"),
                Self.personJSON("u2", membership: "admin", access: "admin"),
                Self.personJSON("u3", role: ("r1", "low")),
                Self.personJSON("u4"),
                Self.personJSON("u5", role: ("r2", "low")))))
            server.route(Self.mobileRoute, .json(Self.mobileList(used: 0, total: 5)))
            let model = AdminMembersViewModel(backend: backend)
            await model.refresh()

            #expect(Set(model.roleOptions.map(\.key)) == ["owners_admins", "no_role", "r1", "r2"])
            model.roleFilter = "r1"
            #expect(model.visibleMembers.map(\.id) == ["u3"])
            model.roleFilter = "no_role"
            #expect(model.visibleMembers.map(\.id) == ["u4"])
            model.roleFilter = "owners_admins"
            #expect(model.visibleMembers.map(\.id) == ["u1", "u2"])
            model.roleFilter = nil
            model.selectStatus(AdminMemberStatusFilter.suspended.rawValue)
            #expect(model.visibleMembers.isEmpty)
        }

        @Test func suspendedPeopleAreListedAndLookSuspendedFromAccess() async throws {
            let backend = try await connected()
            server.route("GET /v1/members", .json(Self.list(
                Self.personJSON("u1", access: "suspended"), Self.personJSON("u2", access: "member"))))
            server.route(Self.mobileRoute, .json(Self.mobileList(used: 0, total: 5)))
            let model = AdminMembersViewModel(backend: backend)
            await model.refresh()

            #expect(model.members.count == 2)
            let query = try #require(server.calls("GET /v1/members").last?.query)
            #expect(query.contains("active_only=false"))
            let suspended = try #require(model.members.first { $0.id == "u1" })
            #expect(suspended.isActive && suspended.isSuspendedInCompany, "il look viene da `access`, non da `isActive`")
            #expect(model.badge(for: suspended) == .companySuspended)
            model.selectStatus(AdminMemberStatusFilter.suspended.rawValue)
            #expect(model.visibleMembers.map(\.id) == ["u1"])
        }

        @Test func onlyActiveOwnersCount() async throws {
            let backend = try await connected()
            server.route("GET /v1/members", .json(Self.list(
                Self.personJSON("o1", membership: "owner", access: "owner"),
                Self.personJSON("o2", membership: "owner", access: "suspended"),
                Self.personJSON("a1", membership: "admin", access: "admin"))))
            server.route(Self.mobileRoute, .json(Self.mobileList(used: 0, total: 5)))
            let model = AdminMembersViewModel(backend: backend)
            await model.refresh()
            #expect(model.activeOwners == 1, "un titolare sospeso e un admin non contano")
        }

        @Test func roleHoldersReadShiftTeamsFromLookups() async throws {
            let backend = try await roleHolder()
            server.route("GET /v1/lookups/teams", .json(#"[{"id":"t1","name":"Night"},{"id":"t2","name":"Day"}]"#))
            server.route("GET /v1/teams", .json("[]"))
            let model = AdminMembersViewModel(backend: backend)
            await model.loadTeamsIfNeeded()

            #expect(model.teams.map(\.name) == ["Day", "Night"])
            #expect(model.teams.allSatisfy { !$0.isAdHoc })
            #expect(server.calls("GET /v1/teams").isEmpty, "senza la sezione Teams: /v1/lookups/teams")
            #expect(server.calls("GET /v1/lookups/teams").count == 1)
        }

        @Test func anAdminReadsShiftTeamsFromTeams() async throws {
            let backend = try await connected()
            server.route("GET /v1/teams", .json(#"[{"id":"t1","name":"Night","is_ad_hoc":true}]"#))
            server.route("GET /v1/lookups/teams", .json("[]"))
            let model = AdminMembersViewModel(backend: backend)
            await model.loadTeamsIfNeeded()

            #expect(model.teams.map(\.id) == ["t1"] && model.teams.first?.isAdHoc == true)
            #expect(server.calls("GET /v1/lookups/teams").isEmpty)
        }

        // MARK: Creazione

        @Test func createSendsTheChosenRoleAndNoPassword() async throws {
            let backend = try await connected()
            let (model, form) = await newForm(backend, people: Self.list(Self.personJSON("u10", email: "mario@acme.test", role: ("r1", "low"))))
            #expect(form.canSave)
            let result = try #require(await form.save())

            let body = try #require(server.calls("POST /v1/users").last?.json)
            #expect(Set(body.keys) == ["email", "full_name", "access_role_id"], "niente password né role vuoto")
            #expect(body["access_role_id"] as? String == "r1")
            #expect(body["full_name"] as? String == "Mario Rossi" && body["email"] as? String == "mario@acme.test")
            #expect(result.userId == "u10" && result.notices.isEmpty, "stesso ruolo: nessun avviso")
            #expect(model.path == [AdminMemberRoute(userId: "u10")], "si apre la scheda della persona")
            #expect(model.newMemberForm == nil)

            form.label = .technician
            _ = await form.save()
            #expect(server.calls("POST /v1/users").last?.json?["role"] as? String == "technician")
        }

        @Test func aNewPersonOpensWithoutNoticesAndTheNoticesAreTakenOnce() async throws {
            let backend = try await connected()
            let (model, form) = await newForm(backend, people: Self.list(Self.personJSON("u10", role: ("r2", "low"))))
            let result = try #require(await form.save())
            #expect(result.notices == [.roleUnchanged])
            #expect(model.takeCreationNotices(for: "other").isEmpty)
            #expect(model.takeCreationNotices(for: "u10") == [.roleUnchanged])
            #expect(model.takeCreationNotices(for: "u10").isEmpty, "si leggono una volta sola")
        }

        @Test func anExistingMemberWithoutARoleAsksForOne() async throws {
            let backend = try await connected()
            let (_, form) = await newForm(backend, people: Self.list(Self.personJSON("u10", role: nil)))
            #expect(try #require(await form.save()).notices == [.noRoleChooseOne])
        }

        @Test func anExistingOwnerOrAdminSkipsTheAppStep() async throws {
            let backend = try await connected()
            let (_, form) = await newForm(backend, people: Self.list(
                Self.personJSON("u10", membership: "admin", access: "admin")))
            form.wantsApp = true
            let result = try #require(await form.save())
            #expect(result.notices == [.alreadyOwnerOrAdmin, .appSkippedOwnerOrAdmin])
            #expect(server.calls(Self.mobileAddRoute).isEmpty, "titolari e admin entrano già: niente POST")
            #expect(server.calls(Self.inviteRoute).isEmpty)
        }

        @Test func aPersonSuspendedInTheCompanyGetsNoAppAccess() async throws {
            let backend = try await connected()
            let (_, form) = await newForm(backend, people: Self.list(
                Self.personJSON("u10", access: "suspended", role: ("r1", "low"))))
            form.wantsApp = true
            let result = try #require(await form.save())
            #expect(result.notices == [.appSkippedSuspended])
            #expect(server.calls(Self.mobileAddRoute).isEmpty && server.calls(Self.inviteRoute).isEmpty)
        }

        @Test func appAccessFollowsCreation() async throws {
            let backend = try await connected()
            let (_, form) = await newForm(backend, people: Self.list(Self.personJSON("u10", role: ("r1", "low"))))
            server.route(Self.mobileAddRoute, .json(Self.mobileRow("u10", status: "invited"), status: 201))
            server.route(Self.inviteRoute, .json(#"{"sent":true}"#, status: 202))
            form.wantsApp = true
            let result = try #require(await form.save())

            #expect(result.notices.isEmpty)
            let order = server.calls.map { "\($0.method) \($0.path)" }
                .filter { ["POST /v1/users", Self.mobileAddRoute, Self.inviteRoute].contains($0) }
            #expect(order == ["POST /v1/users", Self.mobileAddRoute, Self.inviteRoute])
            #expect(server.calls(Self.mobileAddRoute).last?.json?["userId"] as? String == "u10")
            let invite = try #require(server.calls(Self.inviteRoute).last?.json)
            #expect(invite["companyId"] as? String == "c1" && invite["userId"] as? String == "u10")
        }

        @Test func anEmailThatDidNotLeaveIsSaid() async throws {
            let backend = try await connected()
            let (_, form) = await newForm(backend, people: Self.list(Self.personJSON("u10", role: ("r1", "low"))))
            server.route(Self.mobileAddRoute, .json(Self.mobileRow("u10", status: "invited"), status: 201))
            server.route(Self.inviteRoute, .json(#"{"sent":false}"#, status: 202))
            form.wantsApp = true
            #expect(try #require(await form.save()).notices == [.emailNotSent])

            server.route(Self.inviteRoute, .json(#"{"detail":"No open invitation"}"#, status: 404))
            #expect(try #require(await form.save()).notices == [.emailNotSent], "un invito chiuso: l'email non è partita")
        }

        @Test func noSeatLeftLeavesThePersonCreatedWithoutApp() async throws {
            let backend = try await connected()
            let (model, form) = await newForm(backend, people: Self.list(Self.personJSON("u10", role: ("r1", "low"))))
            server.route(Self.mobileAddRoute, .json(#"{"detail":{"code":"seat_limit_reached","message":"No seats"}}"#, status: 409))
            form.wantsApp = true
            let result = try #require(await form.save())

            #expect(result.notices == [.appNotGiven(AriaPeopleRefusal.seatLimitReached.message)])
            #expect(server.calls(Self.inviteRoute).isEmpty, "senza l'accesso, niente email")
            #expect(model.path == [AdminMemberRoute(userId: "u10")], "la persona esiste: si apre la sua scheda")
        }

        @Test func fullSeatsDisableTheToggleAndSkipTheAppStep() async throws {
            let backend = try await connected()
            server.route(Self.mobileRoute, .json(Self.mobileList(used: 10, total: 10)))
            let (model, form) = await newForm(backend, people: Self.list(Self.personJSON("u10", role: ("r1", "low"))),
                                              preload: true)
            #expect(model.seatsAreFull && !form.appToggleEnabled)
            form.wantsApp = true
            #expect(!form.wantsAppEffective, "con le licenze finite l'interruttore resta spento")
            _ = await form.save()
            #expect(server.calls(Self.mobileAddRoute).isEmpty)
        }

        @Test func alreadyListedStaysInTheForm() async throws {
            let backend = try await connected()
            let (model, form) = await newForm(backend, people: Self.list(
                Self.personJSON("u5", email: "mario@acme.test", role: ("r1", "low"))), preload: true)
            server.route("POST /v1/users", .json(#"{"detail":{"code":"already_listed","message":"m"}}"#, status: 409))
            #expect(await form.save() == nil)
            #expect(form.errorMessage == AriaPeopleRefusal.alreadyListed.message)
            #expect(model.path.isEmpty, "il modulo resta aperto")
            #expect(form.duplicate?.id == "u5", "il collegamento alla scheda c'è")
            form.openDuplicate()
            #expect(model.path == [AdminMemberRoute(userId: "u5")])
        }

        @Test func duplicateEmailIsFlaggedBeforeSaving() async throws {
            let backend = try await connected()
            let (_, form) = await newForm(backend, people: Self.list(
                Self.personJSON("u5", email: "mario@acme.test")), preload: true)
            form.email = " Mario@Acme.test "
            #expect(form.duplicate?.id == "u5")
            #expect(form.canSave, "\"Create\" resta attivo: lo decide il server")
            form.email = "luca@acme.test"
            #expect(form.duplicate == nil)
            form.email = ""
            #expect(form.duplicate == nil)
        }

        @Test func theRoleFollowsTheLabelUntilChosenByHand() async throws {
            let backend = try await connected()
            server.route(Self.rolesRoute, .json(Self.roles(
                Self.roleJSON("tech", seed: "technician"), Self.roleJSON("mgr", enabled: false, seed: "manager"),
                Self.roleJSON("def", isDefault: true))))
            let form = AdminMemberCreateViewModel(owner: AdminMembersViewModel(backend: backend))
            await form.loadRoles()

            #expect(form.roles.map(\.id) == ["tech", "def"], "i ruoli in pausa non si offrono")
            #expect(form.roleId == "def")
            form.label = .technician
            #expect(form.roleId == "tech")
            form.label = .manager
            #expect(form.roleId == "def", "il ruolo base della qualifica è in pausa: il predefinito")
            form.roleId = "def"
            form.label = .technician
            #expect(form.roleId == "def", "scelto a mano: la qualifica non lo cambia più")
        }

        @Test func noActiveRoleMeansNoCreation() async throws {
            let backend = try await connected()
            server.route(Self.rolesRoute, .json(Self.roles(Self.roleJSON("paused", enabled: false))))
            let form = AdminMemberCreateViewModel(owner: AdminMembersViewModel(backend: backend))
            form.name = "Mario"
            form.email = "mario@acme.test"
            await form.loadRoles()
            #expect(form.hasNoActiveRoles && form.roleId == nil && !form.canSave)
        }

        @Test func theRoleIsRequiredToSave() async throws {
            let backend = try await connected()
            server.route(Self.rolesRoute, .json(Self.roles(Self.roleJSON("r1"))))
            let form = AdminMemberCreateViewModel(owner: AdminMembersViewModel(backend: backend))
            await form.loadRoles()
            form.name = "Mario"
            form.email = "mario@acme.test"
            #expect(form.roleId == nil && !form.canSave, "nessuna preselezione: \"Create\" disattivato")
            form.roleId = "r1"
            #expect(form.canSave)
            form.name = String(repeating: "a", count: 101)
            #expect(!form.canSave)
            form.name = "  "
            #expect(!form.canSave)
        }
    }
}

// MARK: - Scheda (senza rete)

extension MembersPeoplePureTests {
    @Test func confirmationsTellWhatHappens() {
        let orders = AdminMemberConfirmation.ordersReleased
        let seat = AdminMemberConfirmation.seatFreed

        // "Rimuovi" rilascia sempre gli ordini, con o senza app.
        #expect(AdminMemberConfirmation.removeFromCompany(hadApp: false).message.contains(orders))
        #expect(AdminMemberConfirmation.removeFromCompany(hadApp: true).message.contains(orders))

        // "Sospendi in azienda": gli ordini solo se l'app era attiva; la frase sull'azienda c'è sempre.
        let reach = String(localized: "They won't be able to use this company, on the web or in the app.")
        #expect(AdminMemberConfirmation.suspendInCompany(appWasActive: false).message.contains(reach))
        #expect(!AdminMemberConfirmation.suspendInCompany(appWasActive: false).message.contains(orders))
        #expect(AdminMemberConfirmation.suspendInCompany(appWasActive: true).message.contains(orders))

        // "Sospendi solo l'app" libera sempre la licenza e rilascia gli ordini.
        #expect(AdminMemberConfirmation.suspendApp.message.contains(seat))
        #expect(AdminMemberConfirmation.suspendApp.message.contains(orders))

        // "Togli accesso": la licenza solo se ne occupava una, gli ordini solo se l'app era attiva.
        let none = AdminMemberConfirmation.revokeAccess(freesSeat: false, appWasActive: false).message
        #expect(!none.contains(seat) && !none.contains(orders))
        let seatOnly = AdminMemberConfirmation.revokeAccess(freesSeat: true, appWasActive: false).message
        #expect(seatOnly.contains(seat) && !seatOnly.contains(orders))
        let both = AdminMemberConfirmation.revokeAccess(freesSeat: true, appWasActive: true).message
        #expect(both.contains(seat) && both.contains(orders))
    }
}

// MARK: - Scheda (con la rete finta)

extension BackendTests.MembersPeople {
    private static func schedaPerson(membership: String = "member", access: String? = "member",
                                     role: (id: String, set: String)? = nil, field: Bool = true) -> String {
        let accessJSON = access.map { "\"\($0)\"" } ?? "null"
        let roleJSON = role.map { #"{"id":"\#($0.id)","name":"Role \#($0.id)","set":"\#($0.set)"}"# } ?? "null"
        return #"{"id":"u9","email":"u9@acme.test","full_name":"Person u9","is_active":true,"membership_role":"\#(membership)","access":\#(accessJSON),"access_role":\#(roleJSON),"is_field":\#(field)}"#
    }

    private nonisolated static func schedaMobile(used: Int = 3, total: Int = 10, status: String? = nil) -> String {
        let row = status.map {
            #"{"id":"u9","name":"Person u9","email":"u9@acme.test","status":"\#($0)","availability":"available"}"#
        } ?? ""
        return #"{"seats":{"used":\#(used),"total":\#(total)},"operators":[\#(row)]}"#
    }

    private static let schedaRoles = #"{"roles":[{"id":"r1","name":"Role r1","set":"low","enabled":true},{"id":"r2","name":"Role r2","set":"low","enabled":true}]}"#

    /// Routes comuni della scheda di u9: elenco, GET della persona, turni, ordini, lista mobile, ruoli e dispositivi.
    private func schedaRoutes(person: String, mobile: String) {
        server.route("GET /v1/members", .json("[\(person)]"))
        server.route("GET /v1/members/u9", .json(person))
        server.route("GET /v1/members/u9/shifts", .json("[]"))
        server.route("GET /v1/work-orders", .json(#"[{"id":"w1","title":"Fix pump","status":"assigned","priority":"high"}]"#))
        server.route("GET /v1/companies/c1/mobile-users", .json(mobile))
        server.route("GET /v1/companies/c1/access/roles", .json(Self.schedaRoles))
        server.route("GET /v1/companies/c1/mobile-users/u9/sessions", .json("[]"))
    }

    /// L'elenco caricato e la scheda di u9 aperta, come fa la vista.
    private func schedaOpened(_ backend: AriaBackend, person: String, mobile: String = BackendTests.MembersPeople.schedaMobile())
        async -> (owner: AdminMembersViewModel, detail: AdminMemberDetailViewModel) {
        schedaRoutes(person: person, mobile: mobile)
        let owner = AdminMembersViewModel(backend: backend)
        await owner.refresh()
        let detail = AdminMemberDetailViewModel(userId: "u9", owner: owner)
        await detail.load()
        return (owner, detail)
    }

    /// Chi ha un ruolo (non admin) con le azioni dette sulla sezione members.
    private func schedaRoleHolder(actions: String) async throws -> AriaBackend {
        let backend = try await TestEnv.signedInStore().backend
        await TestEnv.grant(TestEnv.accessJSON(sections: #"{"members":{"granted":true,"actions":\#(actions)}}"#), to: backend)
        return backend
    }

    /// I percorsi chiamati, nell'ordine.
    private var schedaPaths: [String] { server.calls.map { "\($0.method) \($0.path)" } }

    // MARK: In azienda

    @Test func suspendInCompanySendsStatus() async throws {
        let backend = try await connected()
        let detail = await schedaOpened(backend, person: Self.schedaPerson()).detail
        #expect(detail.member?.id == "u9" && detail.canChangeCompanyStatus)

        detail.askToSuspend()
        #expect(detail.pendingConfirmation == .suspendInCompany(appWasActive: false))
        server.route("PATCH /v1/members/u9", .json(Self.schedaPerson(access: "suspended")))
        let pending = try #require(detail.pendingConfirmation)
        await detail.confirm(pending)
        #expect(server.calls("PATCH /v1/members/u9").last?.json?["status"] as? String == "suspended")
        #expect(detail.actionError == nil)
    }

    @Test func removeCallsTheCompanyRoute() async throws {
        let backend = try await connected()
        let detail = await schedaOpened(backend, person: Self.schedaPerson()).detail
        server.route("DELETE /v1/companies/c1/members/u9",
                     .json(#"{"detail":"Cannot remove the last owner"}"#, status: 409), .noContent)

        detail.askToRemove()
        #expect(detail.pendingConfirmation == .removeFromCompany(hadApp: false))
        await detail.confirm(.removeFromCompany(hadApp: false))
        #expect(detail.actionError == "Cannot remove the last owner", "un 409 senza codice mostra il detail del server")
        #expect(!detail.isGone)

        await detail.confirm(.removeFromCompany(hadApp: false))
        #expect(server.calls("DELETE /v1/companies/c1/members/u9").count == 2)
        #expect(detail.isGone, "rimossa: la scheda torna all'elenco")
    }

    @Test func roleChangeSendsCamelCaseOrNull() async throws {
        let backend = try await connected()
        let detail = await schedaOpened(backend, person: Self.schedaPerson(role: ("r1", "low"))).detail
        #expect(detail.roleChoice?.options.map(\.id) == ["r1", "r2"] && detail.roleChoice?.canUnassign == true)

        server.route("PUT /v1/companies/c1/members/u9/access-role", .noContent)
        await detail.setRole("r2")
        #expect(server.calls("PUT /v1/companies/c1/members/u9/access-role").last?.json?["roleId"] as? String == "r2")

        await detail.setRole(nil)
        let body = try #require(server.calls("PUT /v1/companies/c1/members/u9/access-role").last?.json)
        #expect(body.keys.contains("roleId") && body["roleId"] is NSNull, "nessun ruolo = null, non assente")
    }

    @Test func aMissingRoleIsNotAMissingPerson() async throws {
        let backend = try await connected()
        let detail = await schedaOpened(backend, person: Self.schedaPerson(role: ("r1", "low"))).detail
        server.route("PUT /v1/companies/c1/members/u9/access-role",
                     .json(#"{"detail":{"code":"role_not_found","message":"m"}}"#, status: 404))
        await detail.setRole("r2")
        #expect(!detail.isGone)
        #expect(detail.actionError == AriaAccessRefusal.roleNotFound.localized)
        #expect(server.calls("GET /v1/companies/c1/access/roles").count >= 2, "i ruoli si ricaricano")
    }

    @Test func aMissingPersonClosesTheCard() async throws {
        let backend = try await connected()
        schedaRoutes(person: Self.schedaPerson(), mobile: Self.schedaMobile())
        server.route("GET /v1/members/u9", .json(#"{"detail":"Member not found"}"#, status: 404))
        let owner = AdminMembersViewModel(backend: backend)
        let detail = AdminMemberDetailViewModel(userId: "u9", owner: owner)
        await detail.load()
        #expect(detail.isGone)
    }

    @Test func profileIsLockedWithoutFieldWork() async throws {
        let backend = try await connected()
        let detail = await schedaOpened(backend, person: Self.schedaPerson(field: false)).detail
        #expect(detail.profileLocked && !detail.canStartEditingProfile)
        #expect(detail.profileHint == String(localized: "Turn on Field work to edit them."))
        detail.startEditingProfile()
        #expect(detail.profileForm == nil, "nome, qualifica e specialità restano chiusi")
        #expect(detail.fieldToggle == .enabled && !detail.isFieldOn)

        server.route("PATCH /v1/members/u9", .json(Self.schedaPerson(field: true)))
        await detail.setField(true)
        let body = try #require(server.calls("PATCH /v1/members/u9").last?.json)
        #expect(Set(body.keys) == ["field"] && body["field"] as? Bool == true)
    }

    @Test func theProfileFormSendsOnlyWhatChanged() async throws {
        let backend = try await connected()
        let detail = await schedaOpened(backend, person: Self.schedaPerson()).detail
        detail.startEditingProfile()
        let form = try #require(detail.profileForm)
        #expect(!form.canSave, "niente è cambiato")

        form.name = "  Maria Rossi "
        form.label = "technician"
        form.draft = "HVAC, Electrical"
        #expect(form.canSave)
        server.route("PATCH /v1/members/u9", .json(Self.schedaPerson()))
        let saved = await form.save()
        #expect(saved)
        let body = try #require(server.calls("PATCH /v1/members/u9").last?.json)
        #expect(Set(body.keys) == ["name", "label", "specialties"])
        #expect(body["name"] as? String == "Maria Rossi")
        #expect(body["specialties"] as? [String] == ["HVAC", "Electrical"])

        // Il nome non si svuota.
        form.name = " "
        #expect(!form.canSave)
    }

    @Test func aNotAFieldWorkerRefusalStaysInTheForm() async throws {
        let backend = try await connected()
        let detail = await schedaOpened(backend, person: Self.schedaPerson()).detail
        detail.startEditingProfile()
        let form = try #require(detail.profileForm)
        form.name = "Maria"
        server.route("PATCH /v1/members/u9",
                     .json(#"{"detail":{"code":"not_a_field_worker","message":"m"}}"#, status: 409))
        let saved = await form.save()
        #expect(!saved)
        #expect(form.errorMessage == AriaPeopleRefusal.notAFieldWorker.message)
    }

    // MARK: Chi ha un ruolo

    @Test func aRoleHolderCannotSeeShiftActionsOnAHighRole() async throws {
        let backend = try await schedaRoleHolder(actions: #"["assign_shifts"]"#)
        let high = await schedaOpened(backend, person: Self.schedaPerson(role: ("rH", "high")))
        #expect(!high.detail.canAssignShifts, "403 escalation_denied prevedibile: il pulsante non c'è")
        high.detail.startAssigning()
        #expect(high.detail.assignForm == nil)

        let low = await schedaOpened(backend, person: Self.schedaPerson(role: ("r1", "low")))
        #expect(low.detail.canAssignShifts)
        low.detail.startAssigning()
        #expect(low.detail.assignForm != nil)

        // Niente delle rotte dell'app, dei ruoli o degli ordini: non sono suoi.
        #expect(server.calls("GET /v1/companies/c1/mobile-users").isEmpty)
        #expect(server.calls("GET /v1/companies/c1/access/roles").isEmpty)
        #expect(low.detail.appState == nil && !low.detail.canSeeOrders)
        #expect(server.calls("GET /v1/work-orders").isEmpty)
    }

    // MARK: Lavoro

    @Test func ordersOfThePersonAskForAll() async throws {
        let backend = try await connected()
        let detail = await schedaOpened(backend, person: Self.schedaPerson()).detail
        let query = try #require(server.calls("GET /v1/work-orders").last?.query)
        #expect(query.contains("scope=all") && query.contains("assigned_to_user_id=u9"))
        #expect(detail.orders.map(\.id) == ["w1"] && detail.hasLoadedOrders)
    }

    // MARK: Accesso all'app

    @Test func givingAccessThenEmails() async throws {
        let backend = try await connected()
        let detail = await schedaOpened(backend, person: Self.schedaPerson()).detail
        #expect(detail.appOffers == [.init(action: .giveAccess, isEnabled: true)])

        server.route("POST /v1/companies/c1/mobile-users",
                     .json(#"{"id":"u9","name":"Person u9","email":"u9@acme.test","status":"invited"}"#, status: 201))
        server.route("POST /api/auth/mobile/invite-link", .json(#"{"sent":true}"#, status: 202))
        await detail.perform(.giveAccess)

        let paths = schedaPaths
        let add = try #require(paths.firstIndex(of: "POST /v1/companies/c1/mobile-users"))
        let email = try #require(paths.firstIndex(of: "POST /api/auth/mobile/invite-link"))
        #expect(add < email, "prima l'accesso, poi l'email")
        #expect(server.calls("POST /v1/companies/c1/mobile-users").last?.json?["userId"] as? String == "u9")
        #expect(server.calls("POST /api/auth/mobile/invite-link").last?.json?["userId"] as? String == "u9")
        #expect(detail.emailNotice == nil && detail.appInfo != nil)
        #expect(server.calls("GET /v1/members/u9").count >= 2, "la persona si rilegge dopo l'azione")
    }

    @Test func anEmailThatWasNotSentIsAnoticeNotAnError() async throws {
        let backend = try await connected()
        let detail = await schedaOpened(backend, person: Self.schedaPerson()).detail
        server.route("POST /v1/companies/c1/mobile-users",
                     .json(#"{"id":"u9","name":"Person u9","email":"u9@acme.test","status":"invited"}"#, status: 201))
        server.route("POST /api/auth/mobile/invite-link", .json(#"{"sent":false}"#, status: 202))
        await detail.perform(.giveAccess)
        #expect(detail.emailNotice == String(localized: "Access given, but the email wasn't sent."))
        #expect(detail.actionError == nil)
    }

    @Test func anExpiredInviteIsRenewedFirst() async throws {
        let backend = try await connected()
        let detail = await schedaOpened(
            backend, person: Self.schedaPerson(access: "operator_invited"),
            mobile: Self.schedaMobile(status: "expired")).detail
        #expect(detail.appOffers.map(\.action) == [.renewAndResend, .revokeAccess])

        server.route("POST /v1/companies/c1/mobile-users/u9/resend",
                     .json(#"{"id":"u9","name":"Person u9","email":"u9@acme.test","status":"invited"}"#))
        server.route("POST /api/auth/mobile/invite-link", .json(#"{"sent":true}"#, status: 202))
        await detail.perform(.renewAndResend)
        let paths = schedaPaths
        let resend = try #require(paths.firstIndex(of: "POST /v1/companies/c1/mobile-users/u9/resend"))
        let email = try #require(paths.firstIndex(of: "POST /api/auth/mobile/invite-link"))
        #expect(resend < email, "…/resend non manda email: prima il rinnovo, poi il link")
    }

    @Test func aValidInviteOnlySendsTheEmail() async throws {
        let backend = try await connected()
        let detail = await schedaOpened(
            backend, person: Self.schedaPerson(access: "operator_invited"),
            mobile: Self.schedaMobile(status: "invited")).detail
        #expect(detail.appOffers.map(\.action) == [.resendInvite, .revokeAccess])

        server.route("POST /api/auth/mobile/invite-link", .json(#"{"sent":true}"#, status: 202))
        await detail.perform(.resendInvite)
        #expect(server.calls("POST /api/auth/mobile/invite-link").count == 1)
        #expect(server.calls("POST /v1/companies/c1/mobile-users/u9/resend").isEmpty)
    }

    @Test func anInviteThatIsNoLongerOpenSaysSoAndReloads() async throws {
        let backend = try await connected()
        let detail = await schedaOpened(
            backend, person: Self.schedaPerson(access: "operator_invited"),
            mobile: Self.schedaMobile(status: "invited")).detail
        server.route("POST /api/auth/mobile/invite-link", .json(#"{"detail":"No open invitation"}"#, status: 404))
        let reads = server.calls("GET /v1/members/u9").count
        await detail.perform(.resendInvite)
        #expect(detail.actionError == String(localized: "The invitation is no longer open."))
        #expect(!detail.isGone, "un 404 dell'invito non è una persona sparita")
        #expect(server.calls("GET /v1/members/u9").count > reads)
    }

    @Test func aCompanySuspendedPersonOffersOnlyRevoke() async throws {
        let backend = try await connected()
        let detail = await schedaOpened(
            backend, person: Self.schedaPerson(access: "suspended"), mobile: Self.schedaMobile(status: "suspended")).detail
        #expect(detail.appState == .companySuspended(hasRow: true))
        #expect(detail.appOffers == [.init(action: .revokeAccess, isEnabled: true)])
        #expect(!detail.showsDevices, "con la persona sospesa in azienda non si sa se l'app era attiva")
        #expect(detail.fieldToggle == .reactivateFirst)
        #expect(server.calls("GET /v1/companies/c1/mobile-users/u9/sessions").isEmpty)
    }

    @Test func suspendAppAndRevokeGoThroughAConfirmation() async throws {
        let backend = try await connected()
        let detail = await schedaOpened(
            backend, person: Self.schedaPerson(access: "operator"), mobile: Self.schedaMobile(status: "active")).detail
        #expect(detail.appOffers.map(\.action) == [.suspendApp, .revokeAccess])

        await detail.perform(.suspendApp)
        #expect(detail.pendingConfirmation == .suspendApp)
        #expect(server.calls("PATCH /v1/companies/c1/mobile-users/u9").isEmpty, "prima la conferma")
        server.route("PATCH /v1/companies/c1/mobile-users/u9",
                     .json(#"{"id":"u9","name":"Person u9","email":"u9@acme.test","status":"suspended"}"#))
        await detail.confirm(.suspendApp)
        #expect(server.calls("PATCH /v1/companies/c1/mobile-users/u9").last?.json?["status"] as? String == "suspended")

        await detail.perform(.revokeAccess)
        #expect(detail.pendingConfirmation == .revokeAccess(freesSeat: true, appWasActive: true))
        server.route("DELETE /v1/companies/c1/mobile-users/u9", .noContent)
        await detail.confirm(.revokeAccess(freesSeat: true, appWasActive: true))
        #expect(server.calls("DELETE /v1/companies/c1/mobile-users/u9").count == 1)
    }

    @Test func reactivateAppWithNoSeatsIsDisabled() async throws {
        let backend = try await connected()
        let detail = await schedaOpened(
            backend, person: Self.schedaPerson(access: "operator_suspended"),
            mobile: Self.schedaMobile(used: 10, total: 10, status: "suspended")).detail
        #expect(detail.appOffers == [.init(action: .reactivateApp, isEnabled: false),
                                     .init(action: .revokeAccess, isEnabled: true)])
        #expect(detail.seatsFullNote != nil)
        await detail.perform(.reactivateApp)
        #expect(server.calls("PATCH /v1/companies/c1/mobile-users/u9").isEmpty)
    }

    @Test func sessions404IsEmpty() async throws {
        let backend = try await connected()
        schedaRoutes(person: Self.schedaPerson(access: "operator"), mobile: Self.schedaMobile(status: "active"))
        server.route("GET /v1/companies/c1/mobile-users/u9/sessions", .json(#"{"detail":"Not found"}"#, status: 404))
        let owner = AdminMembersViewModel(backend: backend)
        await owner.refresh()
        let detail = AdminMemberDetailViewModel(userId: "u9", owner: owner)
        await detail.load()
        #expect(detail.showsDevices && detail.sessions.isEmpty && detail.hasLoadedSessions)
        #expect(detail.sessionsMessage == nil && !detail.isGone, "un 404 delle sessioni non è un errore")
    }

    @Test func sharedSessionsExplainThemselves() async throws {
        let backend = try await connected()
        schedaRoutes(person: Self.schedaPerson(access: "operator"), mobile: Self.schedaMobile(status: "active"))
        let shared = Reply.json(#"{"detail":{"code":"sessions_shared","message":"m"}}"#, status: 409)
        server.route("GET /v1/companies/c1/mobile-users/u9/sessions", shared)
        let owner = AdminMembersViewModel(backend: backend)
        await owner.refresh()
        let detail = AdminMemberDetailViewModel(userId: "u9", owner: owner)
        await detail.load()
        #expect(detail.sessionsMessage == AriaPeopleRefusal.sessionsShared.message)

        server.route("DELETE /v1/companies/c1/mobile-users/u9/sessions", shared)
        await detail.logOutAll()
        #expect(detail.actionError == AriaPeopleRefusal.sessionsShared.message)
    }

    @Test func devicesLogOutOneOrAll() async throws {
        let backend = try await connected()
        schedaRoutes(person: Self.schedaPerson(access: "operator"), mobile: Self.schedaMobile(status: "active"))
        server.route("GET /v1/companies/c1/mobile-users/u9/sessions", .json(
            #"[{"id":"s1","device":"iPhone","createdAt":"2026-11-01T10:00:00Z"},{"id":"s2","device":"iPad","createdAt":"2026-11-02T10:00:00Z"}]"#))
        let owner = AdminMembersViewModel(backend: backend)
        await owner.refresh()
        let detail = AdminMemberDetailViewModel(userId: "u9", owner: owner)
        await detail.load()
        #expect(detail.sessions.count == 2)

        let first = try #require(detail.sessions.first)
        detail.askToLogOut(first)
        #expect(detail.pendingConfirmation == .logoutDevice(first))
        server.route("DELETE /v1/companies/c1/mobile-users/u9/sessions/\(first.id)", .noContent)
        await detail.confirm(.logoutDevice(first))
        #expect(detail.sessions.count == 1 && !detail.sessions.contains { $0.id == first.id })

        detail.askToLogOutAll()
        #expect(detail.pendingConfirmation == .logoutAll)
        server.route("DELETE /v1/companies/c1/mobile-users/u9/sessions", .noContent)
        await detail.confirm(.logoutAll)
        #expect(detail.sessions.isEmpty)
    }

    @Test func creationNoticesAreReadOnce() async throws {
        let backend = try await connected()
        schedaRoutes(person: Self.schedaPerson(), mobile: Self.schedaMobile())
        let owner = AdminMembersViewModel(backend: backend)
        owner.didCreate(AdminMemberCreationResult(userId: "u9", notices: [.noRoleChooseOne, .emailNotSent]))

        let detail = AdminMemberDetailViewModel(userId: "u9", owner: owner)
        await detail.load()
        #expect(detail.noticeLines == [AdminMemberDetailViewModel.text(for: .noRoleChooseOne),
                                       AdminMemberDetailViewModel.text(for: .emailNotSent)])
        await detail.load()
        #expect(detail.noticeLines.count == 2, "un secondo load non le legge di nuovo né le perde")
        #expect(AdminMemberDetailViewModel(userId: "u9", owner: owner).notices.isEmpty)
    }
}
