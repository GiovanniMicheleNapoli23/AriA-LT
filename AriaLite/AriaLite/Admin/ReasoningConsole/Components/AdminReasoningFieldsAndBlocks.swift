//
//  AdminReasoningFieldsAndBlocks.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il contenuto di un oggetto della trace: prima i valori brevi (titolo → valore), poi i blocchi JSON chiusi.
//

import SwiftUI

struct AdminReasoningFieldsAndBlocks: View {
    let fields: [AdminAssetField]
    let blocks: [AdminReasoningJSONBlock]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !fields.isEmpty {
                VStack(spacing: 0) {
                    ForEach(fields) { field in
                        AdminFieldRow(field: field, showsDivider: field != fields.last)
                    }
                }
            }
            ForEach(blocks) { block in
                AdminReasoningJSONBlockView(block: block)
            }
            if fields.isEmpty && blocks.isEmpty {
                AdminSectionNotice(text: String(localized: "Nothing recorded."))
            }
        }
    }
}
