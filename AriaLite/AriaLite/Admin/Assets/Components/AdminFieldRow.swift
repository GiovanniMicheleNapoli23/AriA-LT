//
//  AdminFieldRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Una riga "titolo → valore" della scheda di un asset. Con il testo molto grande il valore va sotto.
//

import SwiftUI

struct AdminFieldRow: View {
    let field: AdminAssetField
    var showsDivider = true

    var body: some View {
        VStack(spacing: 0) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) {
                    Text(field.title).foregroundStyle(.secondary)
                    Spacer(minLength: 12)
                    Text(field.value)
                        .multilineTextAlignment(.trailing)
                        .textSelection(.enabled)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(field.title).foregroundStyle(.secondary)
                    Text(field.value).textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(.subheadline)
            .padding(.vertical, 10)
            if showsDivider { Divider() }
        }
    }
}
