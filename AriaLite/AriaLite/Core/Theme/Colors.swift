//
//  Colors.swift
//  AriaLite
//
//  Created by Giovanni Michele on 20/03/26.
//

import SwiftUI

extension Color {
    // MARK: - Brand Colors (Aria — nuovo logo navy)
    static let liteBackground = Color(red: 0.98, green: 0.98, blue: 0.99)  // bianco quasi puro
    static let liteAccent = Color(red: 0.08, green: 0.14, blue: 0.25)  // #141F3F navy scuro del logo
    static let liteSurface = Color(red: 1.00, green: 1.00, blue: 1.00)  // bianco puro
    static let liteBorder = Color(red: 0.08, green: 0.14, blue: 0.25).opacity(0.12)
    static let liteText = Color(red: 0.08, green: 0.14, blue: 0.25)  // stesso navy per coerenza
}
