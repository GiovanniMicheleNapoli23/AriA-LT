//
//  LoginShake.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Scuote orizzontalmente la card quando il link o l'email non vanno.
//

import SwiftUI

struct LoginShake: GeometryEffect {
    var amount: CGFloat
    var animatableData: CGFloat {
        get { amount }
        set { amount = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 8 * sin(amount * .pi * 4), y: 0))
    }
}
