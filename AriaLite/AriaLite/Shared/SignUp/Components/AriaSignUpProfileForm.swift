//
//  AriaSignUpProfileForm.swift
//  AriaLite
//
//  Created by Giovanni Michele on 11/11/26.
//
//  Il passo Profilo: nome, ruolo e telefono in una card come quella del login, poi "Continue".
//

import SwiftUI

struct AriaSignUpProfileForm: View {
    @Bindable var model: AriaSignUpViewModel
    @FocusState private var focus: Field?
    @ScaledMetric(relativeTo: .body) private var iconWidth: CGFloat = 20

    private enum Field { case name, phone }

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 0) {
                LoginCardRow(icon: "person") {
                    TextField("Full name", text: $model.name)
                        .textContentType(.name)
                        .submitLabel(.next)
                        .focused($focus, equals: .name)
                        .onSubmit { focus = .phone }
                }
                Divider().padding(.leading, 28 + iconWidth)
                LoginCardRow(icon: "briefcase") {
                    Picker("Job role", selection: $model.jobRole) {
                        Text("Choose your role").tag(AriaJobRole?.none)
                        ForEach(AriaJobRole.allCases) { role in
                            Text(role.title).tag(Optional(role))
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .tint(model.jobRole == nil ? Color.secondary : Color.liteText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                Divider().padding(.leading, 28 + iconWidth)
                LoginCardRow(icon: "phone") {
                    TextField("Phone (optional)", text: $model.phone)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                        .focused($focus, equals: .phone)
                }
            }
            .ariaSignUpCard()

            LoginPrimaryButton(title: "Continue", isEnabled: model.canSaveProfile, isBusy: model.isSaving) {
                focus = nil
                Task { await model.saveProfile() }
            }
        }
    }
}
