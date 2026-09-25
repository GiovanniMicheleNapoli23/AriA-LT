//
//  AriAEngine.swift
//  AriaLite
//
//  Created by Giovanni Michele on 31/03/26.
//

import SwiftUI


// MARK: - Floating Button con personalità
struct AIFloatingButton: View {
    @Binding var showChat: Bool
    @State private var isPressed = false
    @State private var isGlowing = false
    @State private var rotation: Double = 0
    @State private var bounce = false

    var body: some View {
        Button {
            triggerHaptic()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                bounce.toggle()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                showChat = true
            }
        } label: {
            ZStack {
                // Glow esterno pulsante
                Circle()
                    .fill(Color.accentColor.opacity(0.3))
                    .frame(width: 72, height: 72)
                    .blur(radius: isGlowing ? 12 : 6)
                    .scaleEffect(isGlowing ? 1.2 : 0.9)
                    .animation(
                        .easeInOut(duration: 1.6).repeatForever(autoreverses: true),
                        value: isGlowing
                    )

                // Contenitore — rende evidente che è un bottone tappabile
                Circle()
                    .fill(Color.liteSurface)
                    .frame(width: 60, height: 60)
                    .overlay(
                        Circle()
                            .strokeBorder(Color.liteAccent.opacity(0.35), lineWidth: 1.5)
                    )
                    .shadow(color: Color.accentColor.opacity(0.45), radius: 10, x: 0, y: 5)
                    .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)

                // Logo AriA — sfera liquid glass
                AriaOrb()
                    .frame(width: 46, height: 46)
                    .rotationEffect(.degrees(rotation))
                    .scaleEffect(isPressed ? 0.85 : 1.0)
            }
            .scaleEffect(bounce ? 1.15 : 1.0)
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.92 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isPressed)
        ._onButtonGesture(pressing: { pressing in
            isPressed = pressing
            if pressing {
                withAnimation(.easeInOut(duration: 0.3)) {
                    rotation = 20
                }
            } else {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.4)) {
                    rotation = 0
                }
            }
        }, perform: {})
        .onAppear {
            isGlowing = true
        }
        .accessibilityLabel("Open AI Assistant")
    }

    private func triggerHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}

#Preview {
    AIFloatingButton(showChat: .constant(true))
}
