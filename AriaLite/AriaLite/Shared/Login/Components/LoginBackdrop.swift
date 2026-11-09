//
//  LoginBackdrop.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Lo sfondo del login e della schermata di sblocco: bianco quasi puro con due aloni appena
//  percettibili, lilla dietro la sfera e navy in basso.
//

import SwiftUI

struct LoginBackdrop: View {
    var body: some View {
        ZStack {
            Color.liteBackground
            RadialGradient(colors: [Color(red: 0.62, green: 0.52, blue: 0.78).opacity(0.16), .clear],
                           center: UnitPoint(x: 0.5, y: 0.28), startRadius: 0, endRadius: 320)
            RadialGradient(colors: [Color.liteAccent.opacity(0.06), .clear],
                           center: .bottom, startRadius: 0, endRadius: 460)
        }
        .ignoresSafeArea()
    }
}
