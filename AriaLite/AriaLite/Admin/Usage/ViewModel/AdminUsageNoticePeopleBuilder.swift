//
//  AdminUsageNoticePeopleBuilder.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Il foglio "Sent to" di un avviso: ruoli (Owners, Members) e persone nominate. Le persone nominate sostituiscono i ruoli e
//  la lista "Usage notices", per questo avviso soltanto (`PeoplePicker` della web). Chi è stato scelto e non è più un membro
//  attivo (la lettura lo tiene) resta in cima, spuntato e "Inactive", fino a che non lo si toglie.
//

import Foundation

nonisolated enum AdminUsageNoticePeopleBuilder {
    /// - `recipients`: i ruoli e le persone scelte per l'avviso, come li mostra la scheda.
    /// - `nameOf`: il nome di una persona che non è fra i membri attivi.
    static func list(recipients: AdminUsageNoticeSettingsCard.Recipients, members: [AriaNoticeRecipients.Member],
                     query: String, locale: Locale, nameOf: (String) -> AdminUsagePersonName) -> AdminUsageNoticePeopleList {
        let chosen = Set(recipients.userIds)
        let active = Set(members.map(\.userId))
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let inactive = String(localized: "usage.notices.inactive", defaultValue: "Inactive")

        let former = recipients.userIds.filter { !active.contains($0) }.compactMap { id -> AdminUsageNoticePeopleList.Person? in
            let name = nameOf(id).text ?? "…"
            guard needle.isEmpty || name.lowercased().contains(needle) else { return nil }
            return .init(id: id, name: name, chip: inactive, isInactive: true, isOn: true)
        }
        let people = members.filter { AdminUsageNoticeRecipientsBuilder.matches($0, query: query) }.map { member in
            AdminUsageNoticePeopleList.Person(
                id: member.userId, name: member.displayName ?? "", chip: AdminUsageNoticeRecipientsBuilder.roleLabel(member.role),
                isInactive: false, isOn: chosen.contains(member.userId))
        }
        let roles = AdminUsageNoticeSettingsBuilder.roles.map { role in
            AdminUsageNoticePeopleList.Role(
                role: role, title: AdminUsageNoticeSettingsBuilder.rolesText([role], locale: locale),
                isOn: recipients.roles.contains(role))
        }
        return AdminUsageNoticePeopleList(roles: roles, rolesDisabled: !recipients.userIds.isEmpty, former: former, people: people)
    }
}
