//
//  AdminMarketplaceSectionFlow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Un layout a capo automatico: i chip vanno su più righe invece di scorrere in orizzontale.
//

import SwiftUI

struct AdminMarketplaceSectionFlow: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(width: proposal.width ?? .infinity, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let frames = arrange(width: bounds.width, subviews: subviews).frames
        for (subview, frame) in zip(subviews, frames) {
            subview.place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                          proposal: ProposedViewSize(frame.size))
        }
    }

    /// Dispone gli elementi da sinistra a destra e va a capo quando la riga è piena. Un elemento più largo
    /// dello spazio resta intero: lo stringe la proposta, e il suo testo va a capo da sé.
    private func arrange(width: CGFloat, subviews: Subviews) -> (frames: [CGRect], size: CGSize) {
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var usedWidth: CGFloat = 0
        let proposedWidth: CGFloat? = width.isFinite ? width : nil
        for subview in subviews {
            let size = subview.sizeThatFits(ProposedViewSize(width: proposedWidth, height: nil))
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            usedWidth = max(usedWidth, x - spacing)
        }
        return (frames, CGSize(width: usedWidth, height: y + rowHeight))
    }
}
