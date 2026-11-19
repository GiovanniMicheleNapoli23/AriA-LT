//
//  AdminUsageKPIBuilder+Extra.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  La tessera "Extra credits" e la riga che ha sotto (contratto 3.4, "first match"): prova, nessun piano, extra non
//  addebitati, extra in addebito, nessun extra. Gli euro e il prezzo li legge solo un titolare che vede i soldi.
//

import Foundation

nonisolated extension AdminUsageKPIBuilder {
    /// Quale tessera di extra si scrive: del ciclo (finora), di un ciclo chiuso (finale) o di oggi.
    nonisolated enum ExtraKind: Sendable {
        case cycle, closed, today
    }

    static func extra(_ f: AdminUsageFacts, label: String, id: AdminUsageKPI.ID, value: Decimal?, amount: Decimal?,
                      kind: ExtraKind, notBilledAtZero: Bool) -> AdminUsageKPI {
        guard let value else { return AdminUsageKPI(id: id, label: label, value: "—", unit: "") }
        var tile = AdminUsageKPI(id: id, label: label, value: f.credits(value), unit: unit)
        let positive = value > 0
        if f.noPlan {
            // Mai addebitato; la riga "nessun piano" è del titolare.
            tile.sub = positive ? (f.owner ? String(localized: "Not billed: no plan assigned") : memberLine(kind)) : noneLine(kind)
        } else if f.capZero, notBilledAtZero || positive {
            // `extra_credits_billable` falso su un piano a pagamento è un tetto di 0 euro: lo dice il server.
            if f.textOwner {
                let cap = f.money(0)
                tile.sub = String(localized: "Not billed: limit \(cap)")
            } else {
                tile.sub = positive ? memberLine(kind) : noneLine(kind)
            }
        } else if positive {
            if f.textOwner, let amount, let price = f.priceText {
                let total = f.amount(amount)
                switch kind {
                case .cycle: tile.sub = String(localized: "\(total) so far · \(price) each")
                case .closed: tile.sub = String(localized: "\(total) at \(price) each")
                case .today: tile.sub = String(localized: "\(total) today · \(price) each")
                }
            } else {
                tile.sub = memberLine(kind)
            }
            tile.isExtra = true
        } else if f.textOwner, let price = f.priceText {
            tile.sub = String(localized: "\(price) per extra credit")
        } else {
            tile.sub = noneLine(kind)
        }
        return tile
    }

    private static func memberLine(_ kind: ExtraKind) -> String {
        kind == .today
            ? String(localized: "past today's included credits")
            : String(localized: "past the included credits")
    }

    private static func noneLine(_ kind: ExtraKind) -> String {
        kind == .today ? String(localized: "None so far today") : String(localized: "None so far this cycle")
    }
}
