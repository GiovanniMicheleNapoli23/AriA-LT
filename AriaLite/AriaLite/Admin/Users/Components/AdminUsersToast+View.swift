//
//  AdminUsersToast+View.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  L'avviso in alto della sezione Users (AdminUsersViewModel.show). Va messo anche dentro ogni sheet, che copre
//  quello della radice.
//

import SwiftUI

extension View {
    func adminUsersToast(_ owner: AdminUsersViewModel) -> some View {
        let notice = owner.notice
        return ariaTopToast(text: notice?.text,
                            systemImage: notice?.isError == true ? "exclamationmark.triangle.fill" : "checkmark.circle.fill",
                            isError: notice?.isError == true)
    }
}
