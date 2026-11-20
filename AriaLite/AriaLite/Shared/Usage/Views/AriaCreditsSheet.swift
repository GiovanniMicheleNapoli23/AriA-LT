//
//  AriaCreditsSheet.swift
//  AriaLite
//
//  Created by Giovanni Michele on 20/11/26.
//
//  I crediti nel loro foglio, dal menu "···" della chat. Dalle impostazioni la stessa pagina si apre con un push.
//

import SwiftUI

struct AriaCreditsSheet: View {
    let model: AriaCreditsViewModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            AriaCreditsView(model: model)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
