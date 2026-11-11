//
//  AriaTopToast.swift
//  AriaLite
//
//  Created by Giovanni Michele on 10/11/26.
//
//  Un piccolo avviso di vetro che scende dall'alto (sotto la barra di navigazione) e se ne va da solo:
//  per confermare qualcosa che è andato bene, come "Applied to the plan". Quando sparisce lo decide chi
//  lo mostra (il view model); qui solo l'aspetto, l'entrata e l'aptica.
//

import SwiftUI

extension View {
    /// Mostra `title` in alto finché `isPresented` è vero.
    func ariaTopToast(_ title: LocalizedStringResource, systemImage: String, isPresented: Bool) -> some View {
        overlay(alignment: .top) {
            if isPresented {
                AriaTopToast(title: title, systemImage: systemImage)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.snappy(duration: 0.3), value: isPresented)
        .sensoryFeedback(.success, trigger: isPresented) { _, shown in shown }
    }
}

private struct AriaTopToast: View {
    let title: LocalizedStringResource
    let systemImage: String

    var body: some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: systemImage).foregroundStyle(Color.liteAccent)
        }
        .font(.subheadline.weight(.semibold))
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .ariaGlass(in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
        .onAppear { AccessibilityNotification.Announcement(String(localized: title)).post() }
    }
}
