//
//  AdminCategoryColor.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Colore di una categoria: lettura tollerante del testo esadecimale (#RGB, #RRGGBB, #RRGGBBAA, con o senza #)
//  e conversione da SwiftUI Color a #RRGGBB per il salvataggio.
//

import SwiftUI

nonisolated enum AdminCategoryColor {
    /// Il colore del testo, o `nil` se non è un esadecimale valido (la riga usa il colore di ripiego).
    static func color(from hex: String?) -> Color? {
        guard let parts = components(from: hex) else { return nil }
        return Color(red: parts.red, green: parts.green, blue: parts.blue, opacity: parts.alpha)
    }

    /// `#RRGGBB` in maiuscolo, dal colore scelto nel selettore.
    static func hex(from color: Color) -> String {
        let resolved = color.resolve(in: EnvironmentValues())
        func byte(_ value: Float) -> Int { Int((min(max(value, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", byte(resolved.red), byte(resolved.green), byte(resolved.blue))
    }

    /// Le componenti 0…1, o `nil` se la stringa non è un esadecimale di 3, 6 o 8 cifre.
    static func components(from hex: String?) -> (red: Double, green: Double, blue: Double, alpha: Double)? {
        guard var text = hex?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        if text.hasPrefix("#") { text.removeFirst() }
        guard text.allSatisfy(\.isHexDigit) else { return nil }
        let digits: [Character]
        switch text.count {
        case 3: digits = text.flatMap { [$0, $0] } + ["F", "F"]
        case 6: digits = Array(text) + ["F", "F"]
        case 8: digits = Array(text)
        default: return nil
        }
        func value(_ pair: ArraySlice<Character>) -> Double {
            Double(Int(String(pair), radix: 16) ?? 0) / 255
        }
        return (value(digits[0..<2]), value(digits[2..<4]), value(digits[4..<6]), value(digits[6..<8]))
    }
}
