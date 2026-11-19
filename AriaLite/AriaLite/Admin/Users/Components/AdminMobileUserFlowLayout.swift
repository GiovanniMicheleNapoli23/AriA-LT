//
//  AdminMobileUserFlowLayout.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Dispone le etichette (le specialità) su più righe, andando a capo quando non c'è più posto.
//  Niente scorrimento orizzontale: segue la larghezza e il Dynamic Type.
//

import SwiftUI

struct AdminMobileUserFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(width: proposal.width ?? .infinity, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        // Si dispone con la stessa larghezza della misura: `bounds` è la larghezza del contenuto, arrotondata ai
        // pixel, e con quella l'ultima etichetta di una riga piena poteva andare a capo fuori dall'altezza
        // misurata, sopra la vista sotto.
        let result = arrange(width: proposal.width ?? bounds.width, subviews: subviews)
        for (index, frame) in result.frames.enumerated() {
            // Con la misura presa: un'etichetta lunga resta nella larghezza (e tronca) invece di uscire.
            subviews[index].place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                                  proposal: ProposedViewSize(frame.size))
        }
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        var frames: [CGRect] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for subview in subviews {
            var size = subview.sizeThatFits(ProposedViewSize(width: width, height: nil))
            size.width = min(size.width, width)
            // Mezzo punto di tolleranza: un arrotondamento non manda a capo un'etichetta che ci sta.
            if x > 0, x + size.width > width + 0.5 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            maxX = max(maxX, x - spacing)
        }
        return (CGSize(width: maxX, height: y + rowHeight), frames)
    }
}
