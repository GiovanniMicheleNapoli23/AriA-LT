//
//  AdminPlantActiveBadge.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il badge "Current": lo stabilimento in uso nell'app (quello della chat).
//

import SwiftUI

struct AdminPlantActiveBadge: View {
    var body: some View {
        Text("Current")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Color.liteAccent)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.liteAccent.opacity(0.15), in: Capsule())
    }
}
