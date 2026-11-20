//
//  AriaAppearance.swift
//  AriaLite
//
//  Created by Giovanni Michele on 20/11/26.
//
//  L'aspetto dell'app scelto dal profilo: chiaro, scuro o come il telefono. Si ricorda sul telefono e vale per
//  tutte le finestre, fogli e avvisi compresi.
//

import SwiftUI
import UIKit

nonisolated enum AriaAppearance: String, CaseIterable, Identifiable, Sendable {
    case light, dark, system

    /// La chiave in UserDefaults (`@AppStorage`): la leggono l'app e il profilo.
    static let storageKey = "aria.appearance"

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .light: "Light"
        case .dark: "Dark"
        case .system: "System"
        }
    }

    var systemImage: String {
        switch self {
        case .light: "sun.max"
        case .dark: "moon"
        case .system: "circle.lefthalf.filled"
        }
    }

    var interfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .light: .light
        case .dark: .dark
        case .system: .unspecified
        }
    }

    /// Sulle finestre e non con `preferredColorScheme`: tornando a "System" da scuro o chiaro `nil` non sempre
    /// rimette l'aspetto del telefono, e i fogli già aperti non seguirebbero.
    @MainActor
    func apply() {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows { window.overrideUserInterfaceStyle = interfaceStyle }
        }
    }
}
