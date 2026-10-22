//
//  LoginCardRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Una riga della card del login, come nelle Impostazioni di sistema: icona a sinistra, poi il campo.
//

import SwiftUI

struct LoginCardRow<Content: View>: View {
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .frame(width: 20)
            content
                .font(.system(size: 17))
                .foregroundStyle(Color.liteText)
        }
        .padding(.horizontal, 16)
        .frame(height: 54)
    }
}
