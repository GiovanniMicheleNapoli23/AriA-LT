//
//  AdminScenarioClosureRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La scheda di una procedura chiusa senza riparazione: allarme, titolo, a che passo si è fermata,
//  chi l'ha chiusa e quando, con lo stato dell'avviso.
//

import SwiftUI

struct AdminScenarioClosureRow: View {
    let closure: AdminScenarioClosure

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    if let code = closure.alarmCode {
                        Text(code)
                            .font(.caption.weight(.bold).monospaced())
                            .foregroundStyle(Color.liteAccent)
                    }
                    Text(closure.displayTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                }
                Spacer(minLength: 8)
                if let status = closure.status {
                    AdminScenarioBadge(text: AdminScenarioClosureStatus.label(for: status),
                                       tone: AdminScenarioLabel.closureTone(status))
                }
            }
            if let step = closure.stepNumber {
                Text("Stopped at step \(step)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            if let line = closure.metaLine {
                Text(line)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
    }
}
