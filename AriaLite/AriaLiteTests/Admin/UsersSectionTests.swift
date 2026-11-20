//
//  UsersSectionTests.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 18/11/26.
//
//  La sezione Users (contratto del 18/11/2026): lettura delle righe, body delle scritture, chi apre la sezione,
//  le voci del livello, "online", i filtri, cosa mostra la scheda, Add user, il tetto e la tabella degli errori.
//  I casi del livello, di "online" e dei filtri sono quelli di `lib/users/rules.test.ts` e `presence.test.ts` della web.
//

import Foundation
import Testing
@testable import AriaLite

struct UsersSectionPureTests {
    // MARK: Aiuti

    private func row(_ id: String = "u1", name: String = "Ana", email: String? = "ana@acme.com",
                     level: AdminUserLevel = .member, role: AdminUserRole? = nil, status: AdminUserStatus = .active,
                     appAccess: Bool = true, field: Bool = false, availability: AdminUserAvailability? = nil,
                     lastSeen: AdminUserLastSeen? = nil, invitationId: String? = nil) -> AdminUserRow {
        AdminUserRow(userId: id, name: name, email: email, level: level, role: role, status: status, appAccess: appAccess,
                     fieldWorker: field, availability: availability, lastSeen: lastSeen, invitationId: invitationId)
    }

    private func page(_ people: [AdminUserRow], owners: Int = 1) -> AdminUsersPage {
        AdminUsersPage(people: people, seats: .init(used: people.count, total: 6), owners: .init(count: owners, max: 3))
    }

    private var owner: AdminUserRow { row("o1", name: "Olga", level: .owner) }
    private var owner2: AdminUserRow { row("o2", name: "Otto", level: .owner) }
    private var member: AdminUserRow { row("m1", name: "Mia") }

    private let high = AdminRole(id: "h1", name: "Planner", set: .high)
    private let low = AdminRole(id: "l1", name: "Night shift", set: .low, ownerRoleId: "h1")
    private let otherLow = AdminRole(id: "l2", name: "Day shift", set: .low, ownerRoleId: "h9")
    private var roles: [AdminRole] { [high, low, otherLow] }

    private let ownerViewer = AdminUsersViewer(userId: "o1", kind: .owner)
    private let highViewer = AdminUsersViewer(userId: "p1", kind: .highHolder, ownRoleId: "h1")
    private let lowViewer = AdminUsersViewer(userId: "x1", kind: .otherHolder)
    private let legacyOwner = AdminUsersViewer(userId: "o1", kind: .owner, legacy: true)

    private func access(_ json: String) throws -> AriaAccess {
        try JSONDecoder().decode(AriaAccess.self, from: Data(json.utf8))
    }

    private func encoded(_ value: some Encodable, snake: Bool = false) throws -> [String: Any] {
        let encoder = JSONEncoder()
        if snake { encoder.keyEncodingStrategy = .convertToSnakeCase }
        return try #require(try JSONSerialization.jsonObject(with: encoder.encode(value)) as? [String: Any])
    }

    // MARK: Lettura (§3.1, §9)

    @Test func theContractExampleDecodes() throws {
        let json = #"""
        {"people":[
          {"userId":"6720a1f0c2d94e0012ab34cd","name":"Giulia Ferri","email":"giulia@example.com","level":"owner","role":null,"status":"active","appAccess":true,"fieldWorker":false,"availability":null,"lastSeen":{"web":"2026-11-18T13:41:10Z","app":null},"invitationId":null},
          {"userId":"6720a1f0c2d94e0012ab34d2","name":"Marco Bianchi","email":"marco@example.com","level":"member","role":{"id":"6af5afd47395a0dc027ae4e5","name":"Technician","set":"low","enabled":true},"status":"invited","appAccess":true,"fieldWorker":true,"availability":"off_duty","lastSeen":{"web":null,"app":null},"invitationId":null},
          {"userId":"6b01c7e2a4f3d90011ee77aa","name":"","email":"new.person@example.com","level":"member","role":null,"status":"invited","appAccess":true,"fieldWorker":false,"availability":null,"lastSeen":null,"invitationId":"6b01c7e2a4f3d90011ee77aa"}
        ],"seats":{"used":5,"total":6},"owners":{"count":1,"max":3}}
        """#
        let page = try JSONDecoder().decode(AdminUsersPage.self, from: Data(json.utf8))
        #expect(page.people.count == 3)
        #expect(page.seats == .init(used: 5, total: 6))
        #expect(page.owners == .init(count: 1, max: 3))
        let marco = page.people[1]
        #expect(marco.role == AdminUserRole(id: "6af5afd47395a0dc027ae4e5", name: "Technician", set: "low", enabled: true))
        #expect(marco.availability == .offDuty && marco.status == .invited && marco.opens)
        #expect(marco.lastSeen == AdminUserLastSeen(web: nil, app: nil))
        let invitation = page.people[2]
        #expect(invitation.isInvitation && !invitation.opens)
        #expect(invitation.lastSeen == nil)
        #expect(invitation.displayName == "new.person@example.com")
    }

    @Test func anOlderServerGetsTheDefaults() throws {
        let json = #"{"people":[{"userId":"u1","name":"  ","email":null,"level":"member","role":null,"status":"active"},{"name":"no id"}],"seats":{"used":2,"total":null},"owners":{"count":1,"max":3}}"#
        let page = try JSONDecoder().decode(AdminUsersPage.self, from: Data(json.utf8))
        #expect(page.people.count == 1, "una riga senza id si salta")
        let person = try #require(page.people.first)
        #expect(person.appAccess && !person.fieldWorker)
        #expect(person.availability == nil && person.lastSeen == nil && person.invitationId == nil)
        #expect(person.displayName == String(localized: "Unnamed person"))
        #expect(page.seats.total == nil)
    }

    // MARK: Body (§5.2, §5.3, §6.1)

    @Test func aMemberLevelAlwaysWritesTheRoleKey() throws {
        let none = try encoded(AdminUserLevelChange.member(roleId: nil))
        #expect(none["level"] as? String == "member")
        #expect(none.keys.contains("accessRoleId") && none["accessRoleId"] is NSNull, "la chiave c'è anche quando è null")
        let role = try encoded(AdminUserLevelChange.member(roleId: "r1"))
        #expect(role["accessRoleId"] as? String == "r1")
        let owner = try encoded(AdminUserLevelChange.owner)
        #expect(owner.count == 1 && owner["level"] as? String == "owner")
    }

    @Test func switchesAndStatusSendOneKey() throws {
        let on = try encoded(AdminUserSwitch(on: true))
        #expect(on.count == 1 && on["on"] as? Bool == true)
        let status = try encoded(AdminUserStatusChange(status: "suspended"), snake: true)
        #expect(status.count == 1 && status["status"] as? String == "suspended")
        let specialties = try encoded(AdminUserSpecialtiesChange(specialties: ["mechanical", "hydraulic"]), snake: true)
        #expect(specialties.count == 1 && specialties["specialties"] as? [String] == ["mechanical", "hydraulic"])
    }

    @Test func addUserSendsTheLabelAndTheRoleOnlyWhenChosen() throws {
        let withRole = try encoded(AdminUsersRules.createBody(name: " Marco Bianchi ", email: " marco@example.com ",
                                                              label: "technician", level: .role("r1")), snake: true)
        #expect(withRole["full_name"] as? String == "Marco Bianchi")
        #expect(withRole["email"] as? String == "marco@example.com")
        #expect(withRole["role"] as? String == "technician", "role è l'etichetta")
        #expect(withRole["level"] as? String == "member")
        #expect(withRole["access_role_id"] as? String == "r1")
        #expect(withRole["password"] == nil)

        let owner = try encoded(AdminUsersRules.createBody(name: "O", email: "o@x.io", label: "manager", level: .owner), snake: true)
        #expect(owner["level"] as? String == "owner")
        #expect(!owner.keys.contains("access_role_id"))

        let none = try encoded(AdminUsersRules.createBody(name: "N", email: "n@x.io", label: "technician", level: .none), snake: true)
        #expect(none["level"] as? String == "member")
        #expect(!none.keys.contains("access_role_id"), "senza ruolo il server dà il predefinito, se attivo")
    }

    @Test func emailShape() {
        #expect(AdminUsersRules.isValidEmail("a@b.co"))
        #expect(AdminUsersRules.isValidEmail("  a@b.co "))
        #expect(!AdminUsersRules.isValidEmail("a@b"))
        #expect(!AdminUsersRules.isValidEmail("a b@c.de"))
        #expect(!AdminUsersRules.isValidEmail(""))
    }

    // MARK: Chi apre la sezione (§2)

    @Test func whoOpensTheSection() throws {
        #expect(AdminUsersRules.entry(nil) == .loading, "/v1/me non ha risposto: mai 'nessun accesso'")
        let members = #"{"members":{"granted":true,"actions":[]}}"#
        #expect(AdminUsersRules.entry(try access(TestEnv.accessJSON(admin: true, role: nil, sections: "{}"))) == .open)
        #expect(AdminUsersRules.entry(try access(TestEnv.accessJSON(model: "legacy", admin: true, role: nil, sections: "{}"))) == .open,
                "il titolare di un'azienda senza ruoli")
        #expect(AdminUsersRules.entry(try access(TestEnv.accessJSON(sections: members))) == .open)
        #expect(AdminUsersRules.entry(try access(TestEnv.accessJSON(sections: members, followsRole: false))) == .hidden,
                "l'app non segue il ruolo: 403 operation_forbidden")
        #expect(AdminUsersRules.entry(try access(TestEnv.accessJSON(model: "legacy", sections: members))) == .hidden)
        #expect(AdminUsersRules.entry(try access(TestEnv.accessJSON(sections: "{}"))) == .hidden)
    }

    @Test func theViewerKind() throws {
        let owner = AdminUsersViewer(userId: "me", access: try access(TestEnv.accessJSON(admin: true, role: nil, sections: "{}")))
        #expect(owner.kind == .owner && owner.canAssignShifts)
        let highJSON = TestEnv.accessJSON(role: #"{"id":"rH","name":"Manager","set":"high","enabled":true}"#,
                                          sections: #"{"members":{"granted":true,"actions":["assign_shifts"]}}"#, canManageRoles: true)
        let high = AdminUsersViewer(userId: "me", access: try access(highJSON))
        #expect(high.kind == .highHolder && high.ownRoleId == "rH" && high.canAssignShifts)
        let other = AdminUsersViewer(userId: "me", access: try access(TestEnv.accessJSON(sections: #"{"members":{"granted":true,"actions":[]}}"#)))
        #expect(other.kind == .otherHolder && !other.canAssignShifts)
        let highWithoutManage = AdminUsersViewer(userId: "me", access: try access(TestEnv.accessJSON(
            role: #"{"id":"rH","name":"Manager","set":"high","enabled":true}"#, sections: "{}")))
        #expect(highWithoutManage.kind == .otherHolder)
        #expect(AdminUsersViewer(userId: "me", access: try access(TestEnv.accessJSON(model: "legacy", admin: true, role: nil, sections: "{}"))).legacy)
    }

    // MARK: Il livello (§5.2)

    @Test func anOwnerSeesOwnerHighLowThenNoRole() throws {
        let options = try #require(AdminUsersRules.levelOptions(for: member, page: page([owner, member]), roles: [low, high],
                                                               viewer: ownerViewer))
        #expect(options.map(\.group) == [.owner, .high, .low, .none])
        #expect(options.first?.value == .owner && options.last?.value == AdminUserLevelValue.none)
        var paused = low
        paused.enabled = false
        let withPaused = try #require(AdminUsersRules.levelOptions(for: member, page: page([owner, member]), roles: [high, paused],
                                                                  viewer: ownerViewer))
        #expect(withPaused.first { $0.group == .low }?.title == String(localized: "Night shift (paused)"))
        #expect(withPaused.allSatisfy { !$0.isDisabled }, "un ruolo in pausa si può scegliere")
    }

    @Test func theOwnerCapAndTheLastOwner() throws {
        let o3 = row("o3", level: .owner)
        let atCap = try #require(AdminUsersRules.levelOptions(for: member, page: page([owner, owner2, o3, member], owners: 3),
                                                             roles: roles, viewer: ownerViewer))
        #expect(atCap.first?.isDisabled == true && atCap.first?.hint == .ownerCap)
        let anOwner = try #require(AdminUsersRules.levelOptions(for: owner2, page: page([owner, owner2, o3], owners: 3),
                                                               roles: roles, viewer: ownerViewer))
        #expect(anOwner.first?.isDisabled == false, "il tetto non spegne Owner per chi lo è già")

        let last = try #require(AdminUsersRules.levelOptions(for: owner, page: page([owner, member]), roles: roles, viewer: ownerViewer))
        #expect(last.dropFirst().allSatisfy { $0.isDisabled && $0.hint == .lastOwner })
        #expect(last.first?.isDisabled == false)
        let two = try #require(AdminUsersRules.levelOptions(for: owner, page: page([owner, owner2], owners: 2), roles: roles, viewer: ownerViewer))
        #expect(two.allSatisfy { !$0.isDisabled })
    }

    @Test func aHighHolderGetsOnlyTheLowRolesItsRoleOwns() throws {
        let target = row("t1", role: AdminUserRole(id: "l1", name: "Night shift", set: "low", enabled: true))
        let options = try #require(AdminUsersRules.levelOptions(for: target, page: page([owner, target]), roles: roles, viewer: highViewer))
        #expect(options.map(\.value) == [.role("l1"), .none])

        let foreign = row("t2", role: AdminUserRole(id: "l2", name: "Day shift", set: "low", enabled: true))
        let seen = try #require(AdminUsersRules.levelOptions(for: foreign, page: page([owner, foreign]), roles: roles, viewer: highViewer))
        #expect(seen.map(\.value) == [.role("l2"), .role("l1")], "il ruolo che non dà resta visibile, e niente No role")
        #expect(seen.map(\.isDisabled) == [true, false])
        #expect(seen.first?.title == "Day shift")

        #expect(AdminUsersRules.levelOptions(for: owner, page: page([owner]), roles: roles, viewer: highViewer) == nil)
        let lead = row("h2", role: AdminUserRole(id: "h1", name: "Planner", set: "high", enabled: true))
        #expect(AdminUsersRules.levelOptions(for: lead, page: page([owner, lead]), roles: roles, viewer: highViewer) == nil)
        #expect(AdminUsersRules.levelOptions(for: member, page: page([owner, member]), roles: roles, viewer: lowViewer) == nil)
    }

    @Test func aLegacyWorkspaceOffersOwnerAndMember() throws {
        let options = try #require(AdminUsersRules.levelOptions(for: member, page: page([owner, member]), roles: roles, viewer: legacyOwner))
        #expect(options.map(\.group) == [.owner, .none])
        #expect(options.last?.title == String(localized: "Member"))
        #expect(AdminUsersRules.levelText(member, legacy: true) == String(localized: "Member"))
        #expect(AdminUsersRules.levelText(member, legacy: false) == String(localized: "No role"))
    }

    @Test func lastActiveOwner() {
        var suspended = owner2
        suspended.status = .suspended
        #expect(AdminUsersRules.isLastActiveOwner(owner, in: [owner, suspended]))
        #expect(!AdminUsersRules.isLastActiveOwner(owner, in: [owner, owner2]))
        #expect(!AdminUsersRules.isLastActiveOwner(member, in: [owner, member]))
        var invited = owner2
        invited.status = .invited
        #expect(!AdminUsersRules.isLastActiveOwner(owner, in: [owner, invited]), "un titolare invitato conta come attivo")
    }

    @Test func demotionStartsOnTheEnabledDefaultRole() {
        let enabledDefault = AdminRole(id: "l2", name: "Day", set: .low, isDefault: true)
        let pausedDefault = AdminRole(id: "l2", name: "Day", set: .low, enabled: false, isDefault: true)
        #expect(AdminUsersRules.demotionPreselect([low, enabledDefault]) == "l2")
        #expect(AdminUsersRules.demotionPreselect([pausedDefault]) == nil)
        #expect(AdminUsersRules.demotionPreselect([low]) == nil)
    }

    @Test func whatAChoiceDoes() {
        let withRole = row("m2", role: AdminUserRole(id: "l1", name: "Night shift", set: "low", enabled: true))
        #expect(AdminUsersRules.levelStep(from: withRole, to: .role("l1"), roles: roles, viewer: ownerViewer) == .nothing)
        #expect(AdminUsersRules.levelStep(from: withRole, to: .role("l2"), roles: roles, viewer: ownerViewer)
                == .send(.member(roleId: "l2")))
        #expect(AdminUsersRules.levelStep(from: withRole, to: .none, roles: roles, viewer: ownerViewer)
                == .send(.member(roleId: nil)))
        #expect(AdminUsersRules.levelStep(from: withRole, to: .owner, roles: roles, viewer: ownerViewer)
                == .confirmPromotion(losingRole: "Night shift"))
        #expect(AdminUsersRules.levelStep(from: member, to: .owner, roles: roles, viewer: ownerViewer) == .confirmPromotion(losingRole: nil))

        let withDefault = roles + [AdminRole(id: "d", name: "Default", set: .low, isDefault: true)]
        #expect(AdminUsersRules.levelStep(from: owner2, to: .role("l1"), roles: withDefault, viewer: ownerViewer)
                == .chooseDemotionRole(preselect: "d", isSelf: false), "parte dal predefinito, qualunque voce si sia toccata")
        #expect(AdminUsersRules.levelStep(from: owner, to: .none, roles: roles, viewer: ownerViewer)
                == .chooseDemotionRole(preselect: nil, isSelf: true))
        #expect(AdminUsersRules.levelStep(from: owner2, to: .none, roles: roles, viewer: legacyOwner) == .confirmLegacyDemotion)
    }

    @Test func theLevelBadge() {
        let paused = row(role: AdminUserRole(id: "l1", name: "Night shift", set: "low", enabled: false))
        #expect(AdminUsersRules.levelBadge(paused, legacy: false) == String(localized: "Night shift · paused"))
        #expect(AdminUsersRules.levelBadge(owner, legacy: false) == String(localized: "Owner"))
    }

    // MARK: Online (§3.2)

    private let now = AdminUserPresence.date(from: "2026-11-14T09:00:00Z")!

    private func ago(_ seconds: TimeInterval) -> String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: now.addingTimeInterval(-seconds))
    }

    @Test func onlineIsATwoMinuteWindow() {
        #expect(AdminUserPresence.onlineWindow == 120)
        #expect(AdminUserPresence(AdminUserLastSeen(web: ago(119)), now: now).web)
        #expect(!AdminUserPresence(AdminUserLastSeen(web: ago(121)), now: now).web)
        #expect(AdminUserPresence(AdminUserLastSeen(app: ago(119)), now: now).app)
        #expect(!AdminUserPresence(AdminUserLastSeen(app: ago(121)), now: now).app)
    }

    @Test func theLaterStampIsLastSeen() {
        let presence = AdminUserPresence(AdminUserLastSeen(web: ago(3600), app: ago(60)), now: now)
        #expect(presence.app && !presence.web)
        #expect(presence.line == .app)
        let away = AdminUserPresence(AdminUserLastSeen(web: ago(600), app: ago(3600)), now: now)
        #expect(away.line == .lastSeen(now.addingTimeInterval(-600)))
        #expect(AdminUserPresence(AdminUserLastSeen(web: ago(10), app: ago(20)), now: now).line == .both)
        #expect(AdminUserPresence(nil, now: now).line == .never)
        #expect(AdminUserPresence(AdminUserLastSeen(), now: now).line == .never)
    }

    @Test func theOnlineLineFollowsTheClockWithoutRebuildingTheRow() {
        let seen = AdminUserLastSeen(web: ago(60))
        #expect(seen.webDate == now.addingTimeInterval(-60), "le ore si leggono una volta, alla creazione")
        #expect(seen.appDate == nil)
        let item = AdminUserListItem(row("w", lastSeen: seen), viewer: ownerViewer)
        #expect(item.onlineLine(at: now)?.isOnline == true)
        #expect(item.onlineLine(at: now.addingTimeInterval(600))?.isOnline == false, "più tardi è solo \"Last seen\"")
        #expect(AdminUserListItem(member, viewer: lowViewer).onlineLine(at: now) == nil, "solo i titolari")
    }

    @Test func junkIsNeverSeenAndStampsAreReadLeniently() {
        #expect(AdminUserPresence(AdminUserLastSeen(web: "yesterday"), now: now).line == .never)
        #expect(AdminUserPresence.date(from: "2026-11-14T08:59:30.123456+00:00") == now.addingTimeInterval(-29.876544))
        #expect(AdminUserPresence.date(from: "2026-11-14T08:59:30") == now.addingTimeInterval(-30), "senza fuso è UTC")
        #expect(AdminUserPresence.date(from: "2026-11-14T08:59:30.5") == now.addingTimeInterval(-29.5))
        #expect(AdminUserPresence.date(from: "2026-11-14T10:59:30+0200") == now.addingTimeInterval(-30))
        #expect(AdminUserPresence.date(from: "nope") == nil)
    }

    // MARK: Filtri (§3.3)

    @Test func searchAndFilters() {
        let tess = row("t", name: "Tess", email: "TESS@acme.com", role: AdminUserRole(id: "l1", name: "N", set: "low", enabled: true),
                       status: .invited, field: true, availability: .busy)
        let off = row("f", name: "Fabio", email: nil, appAccess: false, lastSeen: AdminUserLastSeen(web: ago(60)))
        let people = [owner, member, tess, off]
        func ids(_ query: String = "", _ filters: AdminUserFilters = AdminUserFilters()) -> [String] {
            filters.apply(to: people, query: query, now: now).map(\.userId)
        }
        #expect(ids("tess@") == ["t"])
        #expect(ids("FAB") == ["f"])
        #expect(ids("  ").count == 4)
        #expect(ids("", AdminUserFilters(appAccess: true, status: .invited)) == ["t"])
        #expect(ids("", AdminUserFilters(appAccess: false, status: .invited)).isEmpty)
        #expect(ids("", AdminUserFilters(level: .owner)) == ["o1"])
        #expect(ids("", AdminUserFilters(level: .hasRole)) == ["t"])
        #expect(ids("", AdminUserFilters(level: .noRole)) == ["m1", "f"])
        #expect(ids("", AdminUserFilters(roleId: "l1")) == ["t"])
        #expect(ids("", AdminUserFilters(fieldWorker: true)) == ["t"])
        #expect(ids("", AdminUserFilters(availability: .busy)) == ["t"])
        #expect(ids("", AdminUserFilters(online: true)) == ["f"])
        #expect(ids("", AdminUserFilters(online: false)) == ["o1", "m1", "t"])
    }

    // MARK: La scheda (§5, §7)

    @Test func whatTheAccessTabShows() {
        let me = AdminUsersRules.accessControls(for: owner, viewer: ownerViewer)
        #expect(me.appSwitch && me.appSwitchLockedOnSelf)
        #expect(!me.suspend && !me.reactivate && !me.remove, "mai su se stessi")
        #expect(me.fieldSwitch && me.sessions)

        let invited = row("i", status: .invited, field: true)
        let controls = AdminUsersRules.accessControls(for: invited, viewer: ownerViewer)
        #expect(controls.resendEmail && controls.specialties)
        #expect(!controls.assignWorkOrder, "solo a chi è attivo")
        #expect(controls.suspend && !controls.reactivate && controls.remove && !controls.appSwitchLockedOnSelf)

        let active = AdminUsersRules.accessControls(for: row("a", field: true), viewer: ownerViewer)
        #expect(active.assignWorkOrder && !active.resendEmail)
        let suspended = AdminUsersRules.accessControls(for: row("s", status: .suspended), viewer: ownerViewer)
        #expect(suspended.reactivate && !suspended.suspend && !suspended.specialties)

        #expect(AdminUsersRules.accessControls(for: member, viewer: highViewer) == .init(), "il ruolo alto vede solo il livello")
        let unknown = AdminUsersViewer(userId: nil, kind: .owner)
        let blind = AdminUsersRules.accessControls(for: member, viewer: unknown)
        #expect(!blind.suspend && !blind.remove, "senza sapere chi si è, niente azioni di stato")
        #expect(AdminUsersRules.showsSchedule(ownerViewer) && !AdminUsersRules.showsSchedule(lowViewer))
    }

    @Test func specialtyChoicesKeepUnknownValues() {
        let choices = AdminUsersRules.specialtyChoices(saved: ["welding", "mechanical"])
        #expect(choices.prefix(7) == ArraySlice(AdminUsersRules.specialtyCategories))
        #expect(choices.last == "welding" && choices.count == 8)
    }

    // MARK: Add user (§6.1)

    @Test func addUserLevels() {
        let defaultRole = AdminRole(id: "d", name: "Default", set: .low, isDefault: true)
        let paused = AdminRole(id: "p", name: "Paused", set: .high, enabled: false)
        let options = AdminUsersRules.addLevelOptions(page: page([owner]), roles: [low, defaultRole, high, paused], legacy: false)
        #expect(options.map(\.value) == [.owner, .role("h1"), .role("l1"), .role("d")], "niente ruoli in pausa, niente No role")
        #expect(AdminUsersRules.addPreselect(roles: [low, defaultRole], legacy: false) == .role("d"))

        let withoutDefault = AdminUsersRules.addLevelOptions(page: page([owner]), roles: [low], legacy: false)
        #expect(withoutDefault.last?.value == AdminUserLevelValue.none)
        #expect(AdminUsersRules.addPreselect(roles: [low], legacy: false) == AdminUserLevelValue.none)

        let full = AdminUsersRules.addLevelOptions(page: page([owner], owners: 3), roles: [], legacy: true)
        #expect(full.map(\.value) == [.owner, .none])
        #expect(full.first?.isDisabled == true && full.first?.hint == .ownerCap)
        #expect(full.last?.title == String(localized: "Member"))
    }

    // MARK: Il tetto (§6.4)

    @Test func theCap() {
        #expect(AdminUsersRules.capState(nil) == .open, "lettura fallita: Add user resta acceso")
        #expect(AdminUsersRules.capState(AdminUserSeatsInfo(users: 4, pendingInvites: 0, userCap: 5)) == .open)
        #expect(AdminUsersRules.capState(AdminUserSeatsInfo(users: 4, pendingInvites: 1, userCap: 5)) == .reached)
        #expect(AdminUsersRules.capState(AdminUserSeatsInfo(users: 6, pendingInvites: 0, userCap: 5)) == .over)
        #expect(AdminUsersRules.capState(AdminUserSeatsInfo(users: 9, userCap: 5, mode: "soft")) == .open)
        #expect(AdminUsersRules.capState(AdminUserSeatsInfo(users: 9, userCap: nil, mode: "contract")) == .open)
        #expect(AdminUsersRules.seatsReadout(.init(used: 5, total: 6)) == String(localized: "5 of 6 seats used"))
        #expect(AdminUsersRules.seatsReadout(.init(used: 5, total: nil)) == String(localized: "5 seats used"))
    }

    @Test func theSeatsPanelReadsMoneyAsText() throws {
        let json = #"{"users":4,"pendingInvites":1,"includedUsers":5,"userCap":5,"mode":"hard","overIncluded":false,"requiredPlan":null,"planKey":"basic_plus","overrideActive":false,"trial":false,"tierSource":"assignment","currency":"EUR","perUserPrice":null,"billedAmount":null,"next":{"planKey":"professional","price":"1200","includedUsers":15}}"#
        let info = try JSONDecoder().decode(AdminUserSeatsInfo.self, from: Data(json.utf8))
        #expect(info.taken == 5 && info.userCap == 5 && info.planKey == "basic_plus")
        #expect(info.perUserPrice == nil && info.billedAmount == nil, "nascosti, mai 0")
        #expect(info.next == .init(planKey: "professional", price: "1200", includedUsers: 15))
    }

    // MARK: Errori (§8)

    private func failure(_ status: Int, _ body: String) -> AdminUsersFailure? {
        let response = HTTPURLResponse(url: URL(string: "https://api.test/x")!, statusCode: status, httpVersion: nil, headerFields: nil)!
        do {
            try AriaHTTP.check(response, Data(body.utf8))
            return nil
        } catch {
            return AdminUsersFailure.from(error)
        }
    }

    @Test func everyCodeHasItsSentence() {
        let cases: [(Int, String, String)] = [
            (409, "owner_limit_reached", "This workspace already has 3 owners."),
            (409, "owner_protected", "The workspace needs at least one active owner."),
            (422, "role_required", "Choose a role before removing an owner."),
            (403, "escalation_denied", "Your role doesn't allow this change."),
            (404, "role_not_found", "That role no longer exists."),
            (404, "not_found", "This person is no longer in the workspace."),
            (409, "seat_limit_reached", "All the seats of your plan are in use. Upgrade to a bigger plan to add more people."),
            (409, "already_listed", "This person is already in the workspace."),
            (422, "invalid_email", "Enter a valid email address."),
            (422, "label_not_allowed", "Choose technician or manager."),
            (403, "session_ended", "Your session for this workspace was ended. Sign in again."),
            (409, "own_app_access", "Something went wrong. Try again."),
            (503, "audit_unavailable", "Something went wrong. Try again."),
            (422, "role_not_assignable", "Something went wrong. Try again."),
            (409, "not_a_field_worker", "Something went wrong. Try again."),
            (409, "mobile_state_conflict", "Something went wrong. Try again."),
            (409, "something_new", "Something went wrong. Try again."),
        ]
        for (status, code, sentence) in cases {
            let body = #"{"detail":{"code":"\#(code)","message":"server text"}}"#
            #expect(failure(status, body)?.message == String(localized: String.LocalizationValue(sentence)), "\(code)")
        }
        let denied = #"{"detail":{"code":"permission_denied","message":"No","section":"members","reason":"no_section"}}"#
        #expect(failure(403, denied)?.message == String(localized: "Your role doesn't allow this."))
        #expect(failure(403, denied)?.reloadsRights == true)
    }

    @Test func whatEachRefusalDoes() {
        #expect(failure(403, #"{"detail":{"code":"session_ended","message":"m"}}"#)?.sessionEnded == true)
        #expect(failure(404, #"{"detail":{"code":"not_found","message":"m"}}"#)?.personGone == true)
        #expect(failure(404, #"{"detail":"Member not found"}"#)?.personGone == true)
        #expect(failure(404, #"{"detail":{"code":"role_not_found","message":"m"}}"#)?.personGone == false, "un ruolo sparito non è una persona sparita")
        #expect(failure(404, #"{"detail":{"code":"role_not_found","message":"m"}}"#)?.roleMissing == true)
        #expect(failure(403, #"{"detail":{"code":"escalation_denied","message":"m"}}"#)?.reloadsRights == true)
        #expect(failure(403, #"{"detail":"Insufficient role"}"#)?.message == AdminUsersFailure.generic)
        #expect(failure(403, #"{"detail":"Insufficient role"}"#)?.closesSection == true)
        #expect(failure(422, #"{"detail":[{"msg":"bad","loc":["body","on"]}]}"#)?.message == AdminUsersFailure.generic)
        let limit = #"{"detail":{"code":"user_limit_reached","message":"This company has reached its user limit","plan_key":"basic_plus","limit":5,"pending_invites":1,"trial":false,"next":{"plan_key":"professional","included_users":15}}}"#
        #expect(failure(409, limit)?.userLimitReached == true)
        #expect(AdminUsersFailure.from(CancellationError()) == nil)
        #expect(AdminUsersFailure.from(AriaError.signedOut) == nil)
    }
}

// MARK: - Con la rete finta

extension BackendTests {
    @Suite("Users section")
    @MainActor
    struct UsersSection {
        private let server = StubServer.shared
        private static let base = "/v1/companies/c1"

        init() { TestEnv.reset() }

        private func connected(owner: Bool = true) async throws -> AriaBackend {
            let backend = try await TestEnv.signedInStore().backend
            if owner {
                await TestEnv.grant(TestEnv.accessJSON(admin: true, role: nil, sections: "{}", canManageRoles: true),
                                    to: backend, restricted: false)
            } else {
                await TestEnv.grant(TestEnv.accessJSON(sections: #"{"members":{"granted":true,"actions":[]}}"#), to: backend)
            }
            return backend
        }

        private static func page(_ people: String...) -> String {
            #"{"people":[\#(people.joined(separator: ","))],"seats":{"used":\#(people.count),"total":6},"owners":{"count":1,"max":3}}"#
        }

        private static func person(_ id: String, level: String = "member", status: String = "active") -> String {
            #"{"userId":"\#(id)","name":"Person \#(id)","email":"\#(id)@acme.test","level":"\#(level)","role":null,"status":"\#(status)","appAccess":true,"fieldWorker":false,"availability":null,"lastSeen":null}"#
        }

        @Test func theLevelGoesToTheCompanyRouteWithAnExplicitNull() async throws {
            let backend = try await connected()
            server.route("PUT \(Self.base)/members/u9/level", .json(Self.person("u9")))
            let api = AdminUsersAPI(api: backend.api, companyId: "c1")
            try await api.setLevel(userId: "u9", .member(roleId: nil))
            let call = try #require(server.calls("PUT \(Self.base)/members/u9/level").last)
            #expect(call.bodyText == #"{"accessRoleId":null,"level":"member"}"# || call.bodyText == #"{"level":"member","accessRoleId":null}"#)
        }

        @Test func theHeaderScopedRoutesAreSnakeCase() async throws {
            let backend = try await connected()
            server.route("PATCH /v1/members/u9", .json(#"{"id":"u9","email":"u9@acme.test"}"#))
            server.route("PATCH /v1/work-orders/w1", .json(#"{"id":"w1"}"#))
            server.route("POST /v1/users", .json(#"{"id":"u10","email":"n@acme.test","full_name":"New"}"#, status: 201))
            let api = AdminUsersAPI(api: backend.api, companyId: "c1")
            try await api.setStatus(userId: "u9", suspended: true)
            #expect(server.calls("PATCH /v1/members/u9").last?.json?.count == 1)
            #expect(server.calls("PATCH /v1/members/u9").last?.json?["status"] as? String == "suspended")
            try await api.assignWorkOrder(id: "w1", to: "u9", name: "Person u9")
            let assignment = try #require(server.calls("PATCH /v1/work-orders/w1").last?.json)
            #expect(assignment["assigned_to_user_id"] as? String == "u9")
            #expect(assignment["assigned_to"] as? String == "Person u9")
            let created = try await api.create(AdminUsersRules.createBody(name: "New", email: "n@acme.test", label: "technician", level: .owner))
            #expect(created.id == "u10")
            #expect(server.calls("POST /v1/users").last?.header("Company-Id") == "c1")
        }

        @Test func theOwnerReadsTheListAndTheCap() async throws {
            let backend = try await connected()
            server.route("GET \(Self.base)/users", .json(Self.page(Self.person("o1", level: "owner"), Self.person("u2"))))
            server.route("GET \(Self.base)/seats", .json(#"{"users":2,"pendingInvites":0,"userCap":2,"mode":"hard"}"#))
            server.route("GET \(Self.base)/access/roles", .json(#"{"roles":[]}"#))
            let model = AdminUsersViewModel(backend: backend)
            await model.loadIfNeeded()
            #expect(model.people.map(\.userId) == ["o1", "u2"])
            #expect(model.capState == .reached)
            #expect(!model.canAdd, "tetto pieno: Add user spento")
            #expect(model.seatsReadout == nil, "il titolare vede il pannello, non la riga")
        }

        @Test func aMemberWithMembersSeesTheReadoutAndNoCap() async throws {
            let backend = try await connected(owner: false)
            server.route("GET \(Self.base)/users", .json(Self.page(Self.person("o1", level: "owner"))))
            let model = AdminUsersViewModel(backend: backend)
            await model.loadIfNeeded()
            #expect(model.seatsReadout == String(localized: "1 of 6 seats used"))
            #expect(server.calls("GET \(Self.base)/seats").isEmpty)
            #expect(server.calls("GET \(Self.base)/access/roles").isEmpty, "senza selettore niente ruoli")
            #expect(!model.canAdd)
        }

        @Test func aForbiddenListClosesTheSection() async throws {
            let backend = try await connected()
            server.route("GET \(Self.base)/users", .json(#"{"detail":"Insufficient role"}"#, status: 403))
            server.route("GET \(Self.base)/seats", .json(#"{"users":0}"#))
            server.route("GET \(Self.base)/access/roles", .json(#"{"roles":[]}"#))
            let model = AdminUsersViewModel(backend: backend)
            await model.loadIfNeeded()
            #expect(model.isClosed)
            #expect(model.placeholder == .failed)
        }

        @Test func enteringAgainRereadsOnlyWhenTheListIsStale() async throws {
            let backend = try await connected()
            let model = await ownerModel(backend, people: Self.page(Self.person("u1", level: "owner")))
            let list = "GET \(Self.base)/users"
            let before = server.calls(list).count
            await model.loadIfNeeded()
            await model.refreshIfStale()
            #expect(server.calls(list).count == before, "dati freschi: né entrando né tornando in primo piano")
            await model.refresh()
            #expect(server.calls(list).count == before + 1, "tirare per aggiornare rilegge sempre")
        }

        @Test func aTransientFailureKeepsTheListAndTheSectionOpen() async throws {
            let backend = try await connected()
            let model = await ownerModel(backend, people: Self.page(Self.person("u1", level: "owner"), Self.person("u2")))
            server.route("GET \(Self.base)/users", .json(#"{"detail":"Internal error"}"#, status: 500))
            await model.refresh()
            #expect(!model.isClosed, "un errore di rete o un 5xx non chiude la sezione")
            #expect(model.loadFailed)
            #expect(model.people.map(\.userId) == ["u1", "u2"], "l'elenco già letto resta")
            #expect(model.placeholder == nil)
        }

        // MARK: Flussi che scrivono

        private func ownerModel(_ backend: AriaBackend, people: String) async -> AdminUsersViewModel {
            server.route("GET \(Self.base)/users", .json(people))
            server.route("GET \(Self.base)/seats", .json(#"{"users":1,"pendingInvites":0,"userCap":null,"mode":"contract"}"#))
            server.route("GET \(Self.base)/access/roles", .json(#"{"roles":[]}"#))
            let model = AdminUsersViewModel(backend: backend)
            await model.loadIfNeeded()
            return model
        }

        @Test func anEmailThatDidNotGoOutKeepsThePersonAndTheSession() async throws {
            let backend = try await connected()
            let model = await ownerModel(backend, people: Self.page(Self.person("u1", level: "owner")))
            server.route("POST /v1/users", .json(#"{"id":"u10","email":"marco@acme.test","full_name":"Marco"}"#, status: 201))
            server.route("POST /api/auth/mobile/invite-link", .json(#"{"sent":false}"#, status: 202),
                         .json(#"{"code":"UNAUTHORIZED","message":"no"}"#, status: 401))
            for attempt in 1...2 {
                let form = AdminUserAddViewModel(owner: model)
                form.name = "Marco"
                form.email = "marco@acme.test"
                #expect(await form.submit(), "aggiunto (tentativo \(attempt))")
                #expect(model.notice?.text == String(localized: "Marco was added, but the email didn't go out. Use Resend email."))
                #expect(backend.isSignedIn, "un 401 del sito non fa uscire")
            }
            let email = try #require(server.calls("POST /api/auth/mobile/invite-link").first?.json)
            #expect(email["companyId"] as? String == "c1" && email["userId"] as? String == "u10")
            let body = try #require(server.calls("POST /v1/users").last?.json)
            #expect(body["level"] as? String == "member" && body["role"] as? String == "technician")
            #expect(body["access_role_id"] == nil, "nessun ruolo predefinito: niente id")
        }

        @Test func aBadEmailNeverLeaves() async throws {
            let backend = try await connected()
            let model = await ownerModel(backend, people: Self.page(Self.person("u1", level: "owner")))
            let form = AdminUserAddViewModel(owner: model)
            form.name = "Marco"
            form.email = "marco@acme"
            #expect(!(await form.submit()))
            #expect(form.emailError == String(localized: "Enter a valid email address."))
            #expect(server.calls("POST /v1/users").isEmpty)
        }

        @Test func steppingDownRereadsTheViewersRights() async throws {
            let backend = try await connected()
            let model = await ownerModel(backend, people: Self.page(Self.person("u1", level: "owner"), Self.person("o2", level: "owner")))
            let detail = AdminUserDetailViewModel(userId: "u1", owner: model)
            #expect(detail.isSelf)
            server.route("PUT \(Self.base)/members/u1/level", .json(Self.person("u1")))
            let before = server.calls("GET /v1/me").count
            await detail.sendLevel(.member(roleId: nil))
            let call = try #require(server.calls("PUT \(Self.base)/members/u1/level").last?.json)
            #expect(call["accessRoleId"] is NSNull)
            #expect(server.calls("GET /v1/me").count > before, "un cambio su se stessi rilegge /v1/me")
            #expect(model.notice?.text == String(localized: "Person u1 now has no role."))
        }

        @Test func aRefusedLevelSaysWhyAndRereadsTheList() async throws {
            let backend = try await connected()
            let model = await ownerModel(backend, people: Self.page(Self.person("u1", level: "owner"), Self.person("u2")))
            let detail = AdminUserDetailViewModel(userId: "u2", owner: model)
            server.route("PUT \(Self.base)/members/u2/level", .json(#"{"detail":{"code":"owner_limit_reached","message":"m"}}"#, status: 409))
            let before = server.calls("GET \(Self.base)/users").count
            await detail.sendLevel(.owner)
            #expect(model.notice?.text == String(localized: "This workspace already has 3 owners."))
            #expect(model.notice?.isError == true)
            #expect(server.calls("GET \(Self.base)/users").count > before)
        }

        @Test func revokingAnInvitation() async throws {
            let backend = try await connected()
            let invitation = #"{"userId":"i1","name":"","email":"new@acme.test","level":"member","role":null,"status":"invited","lastSeen":null,"invitationId":"i1"}"#
            let model = await ownerModel(backend, people: Self.page(Self.person("u1", level: "owner"), invitation))
            let row = try #require(model.row(for: "i1"))
            server.route("DELETE \(Self.base)/invites/i1", .noContent)
            await model.revoke(row)
            #expect(server.calls("DELETE \(Self.base)/invites/i1").count == 1)
            #expect(model.notice?.text == String(localized: "The invitation to new@acme.test was revoked."))

            server.route("DELETE \(Self.base)/invites/i1", .json(#"{"detail":"Invitation not found"}"#, status: 404))
            await model.revoke(row)
            #expect(model.notice?.text == String(localized: "The invitation couldn't be revoked. Try again."))
        }

        @Test func historySendsNoDatesAndTodayIsUTC() async throws {
            let backend = try await connected()
            let model = await ownerModel(backend, people: Self.page(Self.person("u1", level: "owner"), Self.person("u2")))
            server.route("GET /v1/members/u2/shifts", .json("[]"))
            server.route("GET /v1/lookups/teams", .json(#"[{"id":"t1","name":"Alpha","memberIds":[]}]"#))
            server.route("POST /v1/member-assignments", .json(#"{"id":"a1","user_id":"u2","team_id":"t1","shift_date":"2026-11-18","shift_type":"full","updated":false}"#, status: 201))
            let shifts = AdminUserShiftsViewModel(userId: "u2", owner: model, reloadDetails: {})
            await shifts.load()
            let history = try #require(server.calls("GET /v1/members/u2/shifts").last)
            #expect((history.query ?? "").isEmpty, "la cronologia non manda date")
            await shifts.moveToday(to: AdminMemberTeamOption(id: "t1", name: "Alpha", isAdHoc: false))
            let body = try #require(server.calls("POST /v1/member-assignments").last?.json)
            var utc = Calendar(identifier: .gregorian)
            utc.timeZone = TimeZone(identifier: "UTC")!
            let parts = utc.dateComponents([.year, .month, .day], from: .now)
            #expect(body["shift_date"] as? String == String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!))
            #expect(body["team_id"] as? String == "t1" && body["user_id"] as? String == "u2")
        }

        @Test func aHiddenEntryClosesTheSection() async throws {
            let backend = try await connected(owner: false)
            await TestEnv.grant(TestEnv.accessJSON(sections: #"{"members":{"granted":true,"actions":[]}}"#, followsRole: false), to: backend)
            let model = AdminUsersViewModel(backend: backend)
            await model.loadIfNeeded()
            #expect(model.isClosed)
            #expect(server.calls("GET \(Self.base)/users").isEmpty)
            let rights = backend.rights
            #expect(!AriaSidebarSections.destinations(operatorLayout: false, rights: rights).contains(.adminUsers))
        }

        @Test func aCodedRefusalOrAMissingRouteClosesTheSection() async throws {
            for reply in [Reply.json(#"{"detail":{"code":"permission_denied","message":"No","section":"members","reason":"no_section"}}"#, status: 403),
                          Reply.json(#"{"detail":"Not Found"}"#, status: 404)] {
                let backend = try await connected()
                server.route("GET \(Self.base)/users", reply)
                server.route("GET \(Self.base)/seats", .json(#"{"users":0}"#))
                server.route("GET \(Self.base)/access/roles", .json(#"{"roles":[]}"#))
                let model = AdminUsersViewModel(backend: backend)
                await model.loadIfNeeded()
                #expect(model.isClosed)
            }
        }

        @Test func anEndedSessionMovesToTheNextCompanyOrSignsOut() async throws {
            TestEnv.stubSignIn(companies: #"[{"id":"c1","name":"Acme","myRole":"owner"},{"id":"c2","name":"Beta","myRole":"owner"}]"#)
            let backend = AriaBackend()
            try await TestEnv.requestLink(backend)
            try await backend.completeSignIn(with: AriaSignInLink(token: "t"))
            await backend.selectCompany("c1")
            await TestEnv.grant(TestEnv.accessJSON(admin: true, role: nil, sections: "{}"), to: backend, restricted: false)
            server.route("GET \(Self.base)/users", .json(#"{"detail":{"code":"session_ended","message":"m"}}"#, status: 403))
            server.route("GET \(Self.base)/seats", .json(#"{"users":0}"#))
            server.route("GET \(Self.base)/access/roles", .json(#"{"roles":[]}"#))
            let model = AdminUsersViewModel(backend: backend)
            await model.loadIfNeeded()
            #expect(model.isClosed)
            #expect(backend.activeCompanyId == "c2")

            let single = try await connected()
            let alone = AdminUsersViewModel(backend: single)
            await alone.loadIfNeeded()
            #expect(!single.isSignedIn, "nessun'altra azienda: si esce")
        }

        @Test func aFailedCapKeepsAddUser() async throws {
            let backend = try await connected()
            server.route("GET \(Self.base)/users", .json(Self.page(Self.person("o1", level: "owner"))))
            server.route("GET \(Self.base)/seats", .json(#"{"detail":"boom"}"#, status: 500))
            server.route("GET \(Self.base)/access/roles", .json(#"{"roles":[]}"#))
            let model = AdminUsersViewModel(backend: backend)
            await model.loadIfNeeded()
            #expect(model.seatsFailed && model.canAdd)
        }
    }
}
