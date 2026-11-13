//
//  AdminRolesToast+View.swift
//  AriaLite
//
//  Created by Giovanni Michele on 12/11/26.
//
//  L'avviso in alto di Roles & Rights: legge il toast del view model, anche dentro gli sheet.
//

import SwiftUI

extension View {
    /// Conferma o rifiuto del server, in alto. Va messo anche dentro ogni sheet, che copre quello della radice.
    func adminRolesToast(_ owner: AdminRolesViewModel) -> some View {
        let toast = owner.toast
        return ariaTopToast(text: toast?.text,
                            systemImage: toast?.isError == true ? "exclamationmark.triangle.fill" : "checkmark.circle.fill",
                            isError: toast?.isError == true)
    }
}
