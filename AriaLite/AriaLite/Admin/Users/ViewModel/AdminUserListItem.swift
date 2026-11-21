//
//  AdminUserListItem.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Una riga dell'elenco già decisa (§3.2): nome, badge di livello, stato e disponibilità, la riga "online" (solo per
//  i titolari) e cosa si può fare. La vista la disegna e basta. Pura: righe, chi guarda e l'ora in ingresso.
//

import Foundation

nonisolated struct AdminUserListItem: Identifiable, Equatable, Sendable {
    enum Tone: Equatable, Sendable {
        case accent
        case positive
        case neutral
    }

    struct Badge: Equatable, Sendable, Identifiable {
        let text: String
        let tone: Tone
        var id: String { text }
    }

    let row: AdminUserRow
    let badges: [Badge]
    /// Le ultime volte che si è visto, già lette: la riga "online" (solo titolari) si calcola da qui, all'ora che serve.
    let seen: AdminUserLastSeen?
    /// Solo i titolari vedono la riga "Online now · web", "Last seen …", "Not signed in yet".
    let showsOnlineLine: Bool
    /// Una persona sospesa è più spenta.
    let isMuted: Bool
    /// L'icona dell'app (non c'è su un invito per email, dove i campi sono solo i valori di partenza).
    let showsAppMark: Bool
    /// Revoke: solo i titolari, solo su un invito per email.
    let canRevoke: Bool

    var id: String { row.userId }
    var opens: Bool { row.opens }
    var name: String { row.displayName }
    var email: String? { row.email }

    /// La riga "online" a quell'ora.
    struct OnlineLine: Equatable, Sendable {
        let text: String
        let isOnline: Bool
    }

    init(_ row: AdminUserRow, viewer: AdminUsersViewer) {
        self.row = row
        let owner = viewer.isOwner
        var badges = [Badge(text: AdminUsersRules.levelBadge(row, legacy: viewer.legacy),
                            tone: row.isOwner || row.role?.enabled == true ? .accent : .neutral),
                      Badge(text: row.status.listTitle, tone: row.status == .active ? .positive : .neutral)]
        if owner, !row.isInvitation, let availability = row.availability {
            badges.append(Badge(text: availability.listTitle, tone: availability == .available ? .positive : .neutral))
        }
        self.badges = badges
        seen = row.lastSeen
        showsOnlineLine = owner
        isMuted = row.status == .suspended
        showsAppMark = !row.isInvitation
        canRevoke = owner && row.isInvitation
    }

    /// "Online now · …", "Last seen …" o "Not signed in yet" all'ora `now`; `nil` per chi non è titolare.
    func onlineLine(at now: Date) -> OnlineLine? {
        guard showsOnlineLine else { return nil }
        let line = AdminUserPresence(seen, now: now).line
        return OnlineLine(text: Self.text(for: line), isOnline: line.isOnline)
    }

    private static func text(for line: AdminUserPresence.Line) -> String {
        switch line {
        case .both: String(localized: "Online now · web and app")
        case .web: String(localized: "Online now · web")
        case .app: String(localized: "Online now · app")
        case .lastSeen(let date): String(localized: "Last seen \(date.formatted(.relative(presentation: .named)))")
        case .never: String(localized: "Not signed in yet")
        }
    }
}
