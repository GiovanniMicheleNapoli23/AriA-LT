//
//  AdminCraftedPaperStyle.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  I colori della pagina del rapporto. La carta resta bianca anche in scuro, quindi qui i colori sono
//  fissi (PAPER_* della web): quelli del tema finirebbero in nero su bianco, o bianco su bianco.
//

import SwiftUI

enum AdminCraftedPaperStyle {
    static let paper = Color.white
    static let ink = Color(red: 0.11, green: 0.12, blue: 0.14)
    static let line = Color(red: 0.78, green: 0.80, blue: 0.83)
    /// Un paragrafo che si legge diverso dal rapporto scritto dal backend: fondo e barretta a sinistra.
    static let editedFill = Color(red: 0.925, green: 0.992, blue: 0.961)
    static let editedBar = Color(red: 0.063, green: 0.725, blue: 0.506)
    static let addedFill = Color(red: 0.82, green: 0.98, blue: 0.90)
    static let addedInk = Color(red: 0.024, green: 0.306, blue: 0.231)
    static let removedFill = Color(red: 1.0, green: 0.89, blue: 0.89)
    static let removedInk = Color(red: 0.60, green: 0.106, blue: 0.106)
    /// Un paragrafo che si può toccare per modificarlo, e quello aperto alla tastiera.
    static let editableFill = Color(red: 0.94, green: 0.976, blue: 1.0)
    static let editableRing = Color(red: 0.49, green: 0.83, blue: 0.99)

    /// Le parole aggiunte su verde, quelle tolte su rosso e barrate.
    static func attributed(_ segments: [AdminCraftedTextDiff.Segment]) -> AttributedString {
        var result = AttributedString()
        for segment in segments {
            var part = AttributedString(segment.text)
            switch segment.type {
            case .same:
                break
            case .added:
                part.backgroundColor = addedFill
                part.foregroundColor = addedInk
            case .removed:
                part.backgroundColor = removedFill
                part.foregroundColor = removedInk
                part.strikethroughStyle = .single
            }
            result.append(part)
        }
        return result
    }
}
