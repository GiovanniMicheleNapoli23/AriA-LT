//
//  AriaSignUpChoicePicker.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Il menu di una scelta dell'iscrizione (ruolo, settore, dimensione) dentro una riga della card: grigio finché non
//  si è scelto, con il segnaposto come prima voce.
//

import SwiftUI

struct AriaSignUpChoicePicker<Option: Identifiable & Hashable>: View {
    let title: LocalizedStringKey
    let placeholder: LocalizedStringKey
    @Binding var selection: Option?
    let options: [Option]
    let label: (Option) -> Text

    init(title: LocalizedStringKey, placeholder: LocalizedStringKey, selection: Binding<Option?>, options: [Option],
         label: @escaping (Option) -> LocalizedStringResource) {
        self.title = title
        self.placeholder = placeholder
        _selection = selection
        self.options = options
        self.label = { Text(label($0)) }
    }

    init(title: LocalizedStringKey, placeholder: LocalizedStringKey, selection: Binding<Option?>, options: [Option],
         verbatim label: @escaping (Option) -> String) {
        self.title = title
        self.placeholder = placeholder
        _selection = selection
        self.options = options
        self.label = { Text(verbatim: label($0)) }
    }

    var body: some View {
        Picker(title, selection: $selection) {
            Text(placeholder).tag(Option?.none)
            ForEach(options) { option in
                label(option).tag(Optional(option))
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .tint(selection == nil ? Color.secondary : Color.liteText)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
