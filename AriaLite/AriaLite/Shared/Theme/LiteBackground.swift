//
//  LiteBackground.swift
//  AriaLite
//
//  Created by Giovanni Michele on 20/03/26.
//

import Foundation
import SwiftUI

// MARK: - LiteBackgroundModifier

 struct LiteBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    Color.liteBackground.ignoresSafeArea()

                    RadialGradient(
                        colors: [Color.liteAccent.opacity(0.07), .clear],
                        center: .topTrailing,
                        startRadius: 0,
                        endRadius: 420
                    )
                    .ignoresSafeArea()
                }
            }
    }
}

// MARK: - View Extension

extension View {
    func liteBackground() -> some View {
        modifier(LiteBackgroundModifier())
    }
}
