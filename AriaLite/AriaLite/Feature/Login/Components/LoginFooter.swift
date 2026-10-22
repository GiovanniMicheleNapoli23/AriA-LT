//
//  LoginFooter.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il piè di pagina del login: icona dell'app, Sinaura e la versione.
//

import SwiftUI

struct LoginFooter: View {
    let version: String

    var body: some View {
        HStack(spacing: 8) {
            Image("AriaLite")
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            Text(verbatim: "Sinaura · v\(version)")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
        }
        .padding(.bottom, 12)
    }
}
