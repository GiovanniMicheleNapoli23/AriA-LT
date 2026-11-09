//
//  AdminCraftedCompareBar.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  La barra fissa in alto durante un confronto: quale versione, di chi e quando, la legenda, la scelta fra
//  "vs originale" e "vs precedente" (dalla v3), Ripristina e chiudi. Uguale per un artifact e per un report:
//  riceve solo il suo AdminCraftedCompareHeader.
//

import SwiftUI

struct AdminCraftedCompareBar: View {
    let header: AdminCraftedCompareHeader
    let onAgainst: (AdminCraftedCompareAgainst) -> Void
    let onRestore: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(AdminCraftedVersionMeta.label(header.number)).font(.headline)
                    Text(header.byline).font(.footnote).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill").font(.title3).foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close comparison")
            }
            if header.number > 1 {
                if header.unchanged {
                    Text("No changes").font(.caption).foregroundStyle(.secondary)
                } else {
                    AdminCraftedDiffLegend()
                }
            }
            if header.canPickAgainst {
                Picker("Versions", selection: Binding(get: { header.against }, set: onAgainst)) {
                    Text("vs original").tag(AdminCraftedCompareAgainst.original)
                    Text(header.previousLabel).tag(AdminCraftedCompareAgainst.previous)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            if header.canRestore {
                Button(action: onRestore) {
                    Label("Restore this version", systemImage: "arrow.counterclockwise")
                }
                .ariaGlassButtonStyle()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .ariaReadableWidth()
        .background(.bar)
    }
}
