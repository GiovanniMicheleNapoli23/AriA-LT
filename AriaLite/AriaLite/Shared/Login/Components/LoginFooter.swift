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
    @ScaledMetric(relativeTo: .caption) private var iconSide: CGFloat = 16

    var body: some View {
        HStack(spacing: 8) {
            Image("AriaLite")
                .resizable()
                .scaledToFit()
                .frame(width: iconSide, height: iconSide)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            Text(verbatim: "Sinaura · v\(version)")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.bottom, 12)
    }
}
