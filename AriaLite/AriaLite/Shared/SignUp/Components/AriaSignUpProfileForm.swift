//
//  AriaSignUpProfileForm.swift
//  AriaLite
//
//  Created by Giovanni Michele on 11/11/26.
//
//  Il passo Profilo: nome, ruolo (con "Altro" il proprio testo) e telefono facoltativo in una card come quella del
//  login, poi "Continua". Campi e testi della sezione "Tu" della web.
//

import SwiftUI

struct AriaSignUpProfileForm: View {
    @Bindable var model: AriaSignUpViewModel
    @FocusState private var focus: Field?
    @ScaledMetric(relativeTo: .body) private var iconWidth: CGFloat = 20

    private enum Field { case name, otherRole, phone }

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 0) {
                LoginCardRow(icon: "person") {
                    TextField("Name", text: $model.name, prompt: Text("John Doe"))
                        .textContentType(.name)
                        .submitLabel(.next)
                        .focused($focus, equals: .name)
                        .onSubmit { focus = model.jobRole == .other ? .otherRole : .phone }
                }
                divider
                LoginCardRow(icon: "briefcase") {
                    AriaSignUpChoicePicker(title: "Role", placeholder: "Select role…", selection: $model.jobRole,
                                           options: AriaJobRole.allCases) { $0.title }
                }
                if model.jobRole == .other {
                    divider
                    LoginCardRow(icon: "pencil") {
                        TextField("Your role", text: $model.otherJobRole)
                            .textContentType(.jobTitle)
                            .submitLabel(.next)
                            .focused($focus, equals: .otherRole)
                            .onSubmit { focus = .phone }
                    }
                    .transition(.opacity)
                }
                divider
                LoginCardRow(icon: "phone") {
                    TextField("Phone", text: $model.phone, prompt: Text("Phone (optional)"))
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                        .focused($focus, equals: .phone)
                }
            }
            .ariaSignUpCard()
            .animation(.snappy(duration: 0.25), value: model.jobRole)
            .onChange(of: model.jobRole) { _, role in
                // Scelto "Altro", il cursore va subito nel suo campo (come la web).
                if role == .other { focus = .otherRole }
            }

            LoginPrimaryButton(title: "Continue", isEnabled: model.canSaveProfile, isBusy: model.isSaving) {
                focus = nil
                Task { await model.continueFromStep() }
            }
        }
    }

    private var divider: some View {
        Divider().padding(.leading, 28 + iconWidth)
    }
}
