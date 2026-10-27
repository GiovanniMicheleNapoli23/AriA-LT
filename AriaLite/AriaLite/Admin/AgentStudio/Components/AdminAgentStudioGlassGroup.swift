//
//  AdminAgentStudioGlassGroup.swift
//  AriaLite
//
//  Created by Giovanni Michele on 27/10/26.
//
//  Il contenitore di vetro che raccoglie le righe di una sezione del dettaglio workflow. Non mette
//  padding: lo danno le righe, così i tocchi arrivano fino ai bordi.
//

import SwiftUI

struct AdminAgentStudioGlassGroup<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
    }
}
