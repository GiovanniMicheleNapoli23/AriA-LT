//
//  AriaConnectionSheet.swift
//  AriaLite
//
//  Created by Giovanni Michele on 20/11/26.
//
//  Il collegamento al server Aria nel suo foglio (dalla shell e dalla chat). Dalle impostazioni lo stesso modulo si
//  apre con un push.
//

import SwiftUI

struct AriaConnectionSheet: View {
    let backend: AriaBackend

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            AriaConnectionForm(backend: backend)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
        .presentationDetents([.medium, .large])
    }
}
