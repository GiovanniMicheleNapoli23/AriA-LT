//
//  AriaSettingsAvatar.swift
//  AriaLite
//
//  Created by Giovanni Michele on 20/11/26.
//
//  Le iniziali in un cerchio color accento: nella riga del profilo e in cima alla pagina dell'account.
//

import SwiftUI

struct AriaSettingsAvatar: View {
    let initials: String
    let side: CGFloat
    /// Lo stile del testo, in proporzione al cerchio: `.headline` nella riga, `.title` nella pagina dell'account.
    var textStyle: Font.TextStyle = .headline

    var body: some View {
        Text(verbatim: initials)
            .font(.system(textStyle, design: .rounded, weight: .semibold))
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .foregroundStyle(Color.liteAccent)
            .frame(width: side, height: side)
            .background(Color.liteAccent.opacity(0.14), in: Circle())
            .accessibilityHidden(true)
    }
}
