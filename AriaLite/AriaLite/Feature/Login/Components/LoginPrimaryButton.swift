//
//  LoginPrimaryButton.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il pulsante del login: pieno, con la rotella mentre si aspetta il server.
//

import SwiftUI

struct LoginPrimaryButton: View {
    let title: LocalizedStringKey
    let isEnabled: Bool
    let isBusy: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if isBusy {
                    ProgressView().tint(Color.liteOnAccent)
                } else {
                    Text(title)
                        .font(.headline)
                }
            }
            .foregroundStyle(Color.liteOnAccent)
            // 54pt a testo "Large"; coi testi grandi cresce quanto il titolo, non di più.
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 54)
            .background(Color.liteAccent.opacity(isEnabled || isBusy ? 1 : 0.3),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Color.liteAccent.opacity(isEnabled ? 0.25 : 0), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .animation(.easeInOut(duration: 0.2), value: isEnabled)
    }
}
