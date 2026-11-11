//
//  AdminAssetHealthList.swift
//  AriaLite
//
//  Created by Giovanni Michele on 10/11/26.
//
//  Un elenco breve della scheda di salute (fattori di rischio, raccomandazioni): titolo e una riga per voce.
//

import SwiftUI

struct AdminAssetHealthList: View {
    let title: LocalizedStringKey
    let items: [String]
    let systemImage: String
    var tint: Color = .secondary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                Label {
                    Text(verbatim: item)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: systemImage).foregroundStyle(tint)
                }
                .labelStyle(.titleAndIcon)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
