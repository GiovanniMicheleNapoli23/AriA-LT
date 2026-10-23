//
//  AdminCraftedArtifactCompareContent.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Il corpo di un confronto fra versioni: per ogni risposta di Aria il testo con le parole aggiunte e
//  tolte e le tabelle riga per riga. La barra con i comandi sta fissa in alto, fuori da qui.
//

import SwiftUI

struct AdminCraftedArtifactCompareContent: View {
    let blocks: [AdminCraftedCompareBlock]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(blocks) { block in
                VStack(alignment: .leading, spacing: 16) {
                    if let segments = block.segments {
                        AdminCraftedDiffText(segments: segments)
                    }
                    ForEach(block.tables) { AdminCraftedTableDiffGrid(table: $0) }
                }
            }
        }
    }
}
