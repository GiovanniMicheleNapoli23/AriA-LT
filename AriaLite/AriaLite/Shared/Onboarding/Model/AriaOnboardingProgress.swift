//
//  AriaOnboardingProgress.swift
//  AriaLite
//
//  Created by Giovanni Michele on 10/11/26.
//
//  Se la presentazione si è già vista su questo telefono: dopo la prima volta (finita, saltata o con un accesso)
//  non torna più da sola, si rivede dal profilo. I test UI la saltano con l'argomento `-AriaOnboardingSeen YES`.
//

import Foundation

struct AriaOnboardingProgress {
    static let seenKey = "AriaOnboardingSeen"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var isSeen: Bool { defaults.bool(forKey: Self.seenKey) }

    func markSeen() {
        defaults.set(true, forKey: Self.seenKey)
    }
}
