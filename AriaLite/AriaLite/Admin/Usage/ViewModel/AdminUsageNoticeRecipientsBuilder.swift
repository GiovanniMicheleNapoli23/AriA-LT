//
//  AdminUsageNoticeRecipientsBuilder.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  La scheda "Usage notices" (contratto 5.3, `notice-recipients.tsx` della web). I titolari sono sempre avvisati (membri
//  con `default`); chi si aggiunge è `added`. L'elenco degli aggiunti arriva dai membri della pagina più la bozza locale
//  fino a che il salvataggio non si chiude. Un membro che se n'è andato lo dice solo il 422: si segna "Inactive" e non si
//  salva niente finché non si toglie.
//

import Foundation

nonisolated enum AdminUsageNoticeRecipientsBuilder {
    /// Gli id aggiunti: la bozza locale se c'è, altrimenti quelli segnati `added` dal server.
    static func ids(members: [AriaNoticeRecipients.Member], draft: [String]?) -> [String] {
        draft ?? members.filter(\.isAdded).map(\.userId)
    }

    static func card(members: [AriaNoticeRecipients.Member], ids: [String], refused: [AdminUsageRefusedPerson],
                     emailEnabled: Bool, locale: Locale) -> AdminUsageNoticeRecipientsCard {
        let byId = Dictionary(members.map { ($0.userId, $0) }, uniquingKeysWith: { first, _ in first })
        let refusedIds = Set(refused.map(\.id))
        let former = AdminUsagePersonName.formerMember.text ?? ""
        let inactiveChip = String(localized: "usage.notices.inactive", defaultValue: "Inactive")

        let always = members.filter(\.isDefault)
            .sorted { lhs, rhs in
                let (a, b) = (rank(lhs.role), rank(rhs.role))
                if a != b { return a < b }
                return (lhs.displayName ?? "").compare(rhs.displayName ?? "", locale: locale) == .orderedAscending
            }
            .map { member in
                let name = member.displayName ?? former
                return AdminUsageNoticeRecipientsCard.Person(id: member.userId, name: name, role: roleLabel(member.role),
                                                             inactiveChip: nil, removeLabel: "")
            }

        let also = ids.map { id -> AdminUsageNoticeRecipientsCard.Person in
            if let member = byId[id] {
                let name = member.displayName ?? former
                return AdminUsageNoticeRecipientsCard.Person(
                    id: id, name: name, role: roleLabel(member.role),
                    inactiveChip: refusedIds.contains(id) ? inactiveChip : nil, removeLabel: removeLabel(name))
            }
            // Non è fra i membri attivi: se n'è andato (il server l'ha rifiutato). Il nome è quello di prima.
            let name = refused.first { $0.id == id }?.name ?? former
            return AdminUsageNoticeRecipientsCard.Person(id: id, name: name, role: roleLabel("member"),
                                                         inactiveChip: inactiveChip, removeLabel: removeLabel(name))
        }

        let inactiveNotes = refused.filter { ids.contains($0.id) }.map { person -> String in
            let name = person.name
            return String(localized: "\(name) is no longer an active member and can't receive notices. Remove them to save again.")
        }

        return AdminUsageNoticeRecipientsCard(
            title: String(localized: "usage.notices.title", defaultValue: "Usage notices"),
            description: String(localized: "Who else hears your company's usage notices."),
            alwaysTitle: String(localized: "Always notified"),
            alwaysHint: String(localized: "usage.notices.alwaysHint", defaultValue: "Owners"),
            always: always,
            alsoTitle: String(localized: "Also notify"),
            alsoHint: String(localized: "Members get notices without EUR amounts"),
            also: also,
            alsoEmpty: String(localized: "No one else yet."),
            addLabel: String(localized: "Add a member"),
            delivery: emailEnabled
                ? String(localized: "Notices arrive in the app and by email.")
                : String(localized: "Notices arrive in the app. Email delivery is coming soon."),
            deliveryIsEmail: emailEnabled,
            inactiveNotes: inactiveNotes)
    }

    /// I membri attivi che non sono né sempre avvisati né già scelti, cercati per nome o email. Vuoto: "Every active member is already notified."
    static func candidates(members: [AriaNoticeRecipients.Member], ids: [String], query: String) -> [AdminUsageNoticeRecipientsCard.Candidate] {
        let chosen = Set(ids)
        return members
            .filter { !$0.isDefault && !chosen.contains($0.userId) && matches($0, query: query) }
            .map { AdminUsageNoticeRecipientsCard.Candidate(id: $0.userId, name: $0.displayName ?? "", role: roleLabel($0.role)) }
    }

    /// Ci sono membri da aggiungere (senza la ricerca): se no la lista dice "Every active member is already notified.".
    static func hasCandidates(members: [AriaNoticeRecipients.Member], ids: [String]) -> Bool {
        !candidates(members: members, ids: ids, query: "").isEmpty
    }

    /// Nome o email contengono la ricerca, senza badare alle maiuscole. Una ricerca vuota li prende tutti.
    static func matches(_ member: AriaNoticeRecipients.Member, query: String) -> Bool {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return true }
        return (member.displayName ?? "").lowercased().contains(needle) || (member.email ?? "").lowercased().contains(needle)
    }

    /// "Owner" per un titolare, "Member" per tutti gli altri.
    static func roleLabel(_ role: String?) -> String {
        role == "owner"
            ? String(localized: "usage.notices.roleOwner", defaultValue: "Owner")
            : String(localized: "usage.notices.roleMember", defaultValue: "Member")
    }

    private static func rank(_ role: String?) -> Int {
        switch role {
        case "owner": 0
        case "admin": 1
        default: 2
        }
    }

    private static func removeLabel(_ name: String) -> String {
        String(localized: "Remove \(name)")
    }
}
