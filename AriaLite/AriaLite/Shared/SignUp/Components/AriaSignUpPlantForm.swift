//
//  AriaSignUpPlantForm.swift
//  AriaLite
//
//  Created by Giovanni Michele on 12/11/26.
//
//  Il passo Stabilimento: nome e codice obbligatori (come il modulo della sezione Plants), luogo facoltativo.
//

import SwiftUI

struct AriaSignUpPlantForm: View {
    @Bindable var model: AriaSignUpViewModel
    @FocusState private var focus: Field?
    @ScaledMetric(relativeTo: .body) private var iconWidth: CGFloat = 20

    private enum Field { case name, code, location }

    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                VStack(spacing: 0) {
                    LoginCardRow(icon: "building") {
                        TextField("Site name", text: $model.plantName)
                            .submitLabel(.next)
                            .focused($focus, equals: .name)
                            .onSubmit { focus = .code }
                    }
                    Divider().padding(.leading, 28 + iconWidth)
                    LoginCardRow(icon: "number") {
                        TextField("Code", text: $model.plantCode)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .submitLabel(.next)
                            .focused($focus, equals: .code)
                            .onSubmit { focus = .location }
                    }
                    Divider().padding(.leading, 28 + iconWidth)
                    LoginCardRow(icon: "mappin.and.ellipse") {
                        TextField("Location (optional)", text: $model.plantLocation)
                            .textContentType(.fullStreetAddress)
                            .submitLabel(.done)
                            .focused($focus, equals: .location)
                            .onSubmit { focus = nil }
                    }
                }
                .ariaSignUpCard()
                Text("A short code your team recognises, e.g. MAIN or NAPLES-1.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 4)
            }

            LoginPrimaryButton(title: "Create site", isEnabled: model.canCreatePlant, isBusy: model.isSaving) {
                focus = nil
                Task { await model.createPlant() }
            }
        }
    }
}
