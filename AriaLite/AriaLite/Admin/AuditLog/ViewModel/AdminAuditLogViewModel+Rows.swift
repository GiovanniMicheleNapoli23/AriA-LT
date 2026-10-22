//
//  AdminAuditLogViewModel+Rows.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Dalle modifiche alle righe della lista (raggruppate per giorno) e al dettaglio di una modifica.
//

import Foundation

extension AdminAuditLogViewModel {
    /// Le righe visibili, raggruppate per giorno, nell'ordine del server (dal più recente).
    var sections: [AdminAuditLogDaySection] {
        let calendar = Calendar.current
        var result: [AdminAuditLogDaySection] = []
        for entry in visibleEntries {
            let day = entry.createdAt.map { calendar.startOfDay(for: $0) }
            let row = rowItem(for: entry)
            if let index = result.firstIndex(where: { $0.day == day }) {
                result[index].rows.append(row)
            } else {
                result.append(AdminAuditLogDaySection(day: day, title: AdminAuditLogText.dayTitle(day), rows: [row]))
            }
        }
        return result
    }

    func rowItem(for entry: AdminAuditLogEntry) -> AdminAuditLogRowItem {
        let name = entry.displayName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? entry.entityId
        return AdminAuditLogRowItem(
            id: entry.id,
            icon: AdminAuditLogText.icon(entry.action),
            tone: AdminAuditLogText.tone(entry.action),
            sentence: AdminAuditLogText.sentence(
                actor: actorName(for: entry), action: entry.action,
                entity: AdminAuditLogText.entity(type: entry.entityType, name: name)),
            time: entry.createdAt.map(AdminAuditLogText.relative))
    }

    /// Il dettaglio di una modifica: tutti i campi che il server dà, e le modifiche ai campi.
    func detail(id: String) -> AdminAuditLogDetail? {
        guard let entry = entry(id: id) else { return nil }
        return detail(for: entry)
    }

    private func detail(for entry: AdminAuditLogEntry) -> AdminAuditLogDetail {
        let row = rowItem(for: entry)
        var fields: [AdminAuditLogField] = [
            AdminAuditLogField(label: String(localized: "Action"), value: AdminAuditLogText.actionLabel(entry.action)),
            AdminAuditLogField(label: String(localized: "Type"),
                               value: AdminAuditLogText.entityTypeLabel(entry.entityType)),
        ]
        appendField(&fields, String(localized: "Name"), entry.displayName)
        appendField(&fields, String(localized: "Item ID"), entry.entityId)
        fields.append(AdminAuditLogField(label: String(localized: "Made by"), value: actorName(for: entry)))
        appendField(&fields, String(localized: "User ID"), entry.userId)
        appendField(&fields, String(localized: "Date"), entry.createdAt.map {
            $0.formatted(date: .long, time: .standard)
        })
        appendField(&fields, String(localized: "Record ID"), entry.id)

        let changes = entry.changes.map { change in
            AdminAuditLogChangeItem(
                field: AdminAuditLogText.humanize(change.field),
                old: AdminAuditLogText.valueText(change.old) ?? "—",
                new: AdminAuditLogText.valueText(change.new) ?? "—")
        }
        return AdminAuditLogDetail(
            title: row.sentence,
            icon: row.icon,
            tone: row.tone,
            fields: fields,
            changes: changes,
            note: entry.changesNote)
    }

    /// Un campo si mostra solo se il server lo manda.
    private func appendField(_ fields: inout [AdminAuditLogField], _ label: String, _ value: String?) {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return }
        fields.append(AdminAuditLogField(label: label, value: value))
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
