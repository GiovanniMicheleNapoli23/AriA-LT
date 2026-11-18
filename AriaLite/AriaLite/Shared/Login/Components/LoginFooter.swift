//
//  LoginFooter.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il piè di pagina del login: solo la versione dell'app.
//

import SwiftUI

struct LoginFooter: View {
    let version: String

    var body: some View {
        Text(verbatim: "v\(version)")
            .font(.caption)
            .foregroundStyle(.tertiary)
            .padding(.bottom, 12)
    }
}
