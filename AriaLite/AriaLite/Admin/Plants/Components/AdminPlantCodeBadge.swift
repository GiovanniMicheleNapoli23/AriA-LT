//
//  AdminPlantCodeBadge.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il codice dello stabilimento in monospaziato, dentro una capsula.
//

import SwiftUI

struct AdminPlantCodeBadge: View {
    let code: String

    var body: some View {
        Text(verbatim: code)
            .font(.caption.monospaced().weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.quaternary, in: Capsule())
            .accessibilityLabel(Text("Code \(code)"))
    }
}
