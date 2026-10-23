//
//  AdminCraftedEditableTextBlock.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Il testo di una risposta di Aria aperto alla modifica, nel Markdown in cui l'ha scritta (quello che si
//  vede è quello che si è scritto). Il campo cresce con il testo: scorre la pagina, non il campo.
//

import SwiftUI

struct AdminCraftedEditableTextBlock: View {
    @Binding var text: String

    var body: some View {
        TextField("Text", text: $text, axis: .vertical)
            .font(.callout)
            .lineSpacing(4)
            .lineLimit(6...)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.liteAccent.opacity(0.14), lineWidth: 1))
    }
}
