//
//  AdminAgentStudioHexColor.swift
//  AriaLite
//
//  Created by Giovanni Michele on 26/10/26.
//
//  Un colore da 0xRRGGBB, quelli dei tipi di nodo della web; in scuro si schiarisce per restare leggibile.
//

import SwiftUI
import UIKit

extension Color {
    /// In chiaro è il colore della web; in scuro è mescolato col bianco, se no il blu e il viola spariscono sul nero.
    init(adminAgentStudioHex hex: UInt32) {
        let red = CGFloat((hex >> 16) & 0xFF) / 255
        let green = CGFloat((hex >> 8) & 0xFF) / 255
        let blue = CGFloat(hex & 0xFF) / 255
        self.init(uiColor: UIColor { traits in
            guard traits.userInterfaceStyle == .dark else { return UIColor(red: red, green: green, blue: blue, alpha: 1) }
            let lift: CGFloat = 0.32
            return UIColor(red: red + (1 - red) * lift, green: green + (1 - green) * lift, blue: blue + (1 - blue) * lift, alpha: 1)
        })
    }
}
