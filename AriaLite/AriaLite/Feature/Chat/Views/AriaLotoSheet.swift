//
//  AriaLotoSheet.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La conferma LOTO prima di continuare una procedura (loto-confirm-dialog della web).
//

import SwiftUI

/// loto-confirm-dialog della web: blocca finché l'operatore non risponde.
struct AriaLotoSheet: View {
    let interrupt: AriaInterrupt
    var onDecide: (AriaResumeDecision) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Intestazione e avviso scorrono insieme: sul telefono basso (o in orizzontale) l'avviso resta leggibile.
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 10) {
                        Image(systemName: "lock.shield.fill")
                            .font(.title)
                            .foregroundStyle(.red)
                        Text("Safety confirmation required")
                            .font(.title3.weight(.bold))
                    }
                    if let alarm = interrupt.alarmCode, !alarm.isEmpty {
                        AriaBadge(text: "\(String(localized: "Alarm")): \(alarm)", tint: .red)
                    }
                    AriaMarkdownView(text: AriaAgentMessage.stripElicitBlock(interrupt.warning ?? ""))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            VStack(spacing: 10) {
                Button {
                    onDecide(.loto(confirmed: true))
                } label: {
                    Text("I have performed LOTO").frame(maxWidth: .infinity).padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                Button {
                    onDecide(.loto(confirmed: false))
                } label: {
                    Text("Not yet").frame(maxWidth: .infinity).padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(24)
        // A metà altezza l'avviso LOTO (da leggere prima di confermare) aveva due righe: si apre intero.
        .presentationDetents([.large])
        .interactiveDismissDisabled()
    }
}
