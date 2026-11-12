//
//  AriaSignUpCompanyForm.swift
//  AriaLite
//
//  Created by Giovanni Michele on 11/11/26.
//
//  Il passo Azienda: nome e nome breve (con l'esito del controllo), poi settore e dimensione facoltativi.
//

import SwiftUI

struct AriaSignUpCompanyForm: View {
    @Bindable var model: AriaSignUpViewModel
    @FocusState private var focus: Field?
    @ScaledMetric(relativeTo: .body) private var iconWidth: CGFloat = 20

    private enum Field { case name, slug }

    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                VStack(spacing: 0) {
                    nameRow
                    Divider().padding(.leading, 28 + iconWidth)
                    slugRow
                }
                .ariaSignUpCard()
                slugCaption
                    .padding(.horizontal, 4)
            }

            VStack(spacing: 0) {
                LoginCardRow(icon: "gearshape.2") {
                    Picker("Industry", selection: $model.industry) {
                        Text("Industry (optional)").tag(AriaCompanyIndustry?.none)
                        ForEach(AriaCompanyIndustry.allCases) { industry in
                            Text(industry.title).tag(Optional(industry))
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .tint(model.industry == nil ? Color.secondary : Color.liteText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                Divider().padding(.leading, 28 + iconWidth)
                LoginCardRow(icon: "person.3") {
                    Picker("Size", selection: $model.size) {
                        Text("Size (optional)").tag(AriaCompanySize?.none)
                        ForEach(AriaCompanySize.allCases) { size in
                            Text(size.title).tag(Optional(size))
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .tint(model.size == nil ? Color.secondary : Color.liteText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .ariaSignUpCard()

            LoginPrimaryButton(title: "Create company", isEnabled: model.canCreateCompany, isBusy: model.isSaving) {
                focus = nil
                Task { await model.createCompany() }
            }
        }
        .animation(.snappy(duration: 0.25), value: model.slugState)
    }

    private var nameRow: some View {
        LoginCardRow(icon: "building.2") {
            TextField("Company name", text: $model.companyName)
                .textContentType(.organizationName)
                .submitLabel(.next)
                .focused($focus, equals: .name)
                .onSubmit { focus = .slug }
        }
    }

    private var slugRow: some View {
        LoginCardRow(icon: "link") {
            TextField("Short name", text: $model.slug)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.asciiCapable)
                .submitLabel(.done)
                .focused($focus, equals: .slug)
                .onSubmit { focus = nil }
            slugIndicator
        }
    }

    /// L'esito del controllo, piccolo, a destra del campo.
    @ViewBuilder
    private var slugIndicator: some View {
        switch model.slugState {
        case .checking:
            ProgressView()
                .controlSize(.small)
        case .available:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.liteAccent)
                .accessibilityLabel("Available")
        case .taken:
            // Il testo sotto la card dice già che è preso.
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
                .accessibilityHidden(true)
        case .idle, .failed:
            EmptyView()
        }
    }

    @ViewBuilder
    private var slugCaption: some View {
        switch model.slugState {
        case .taken:
            Text("This short name is already taken.")
                .font(.caption)
                .foregroundStyle(.red)
        case .failed:
            HStack(spacing: 8) {
                Text("Couldn't check the short name.")
                    .foregroundStyle(.secondary)
                Button("Retry") { model.retrySlugCheck() }
                    .foregroundStyle(Color.liteAccent)
                    .fontWeight(.medium)
            }
            .font(.caption)
        case .idle, .checking, .available:
            if model.normalizedSlug.isEmpty {
                Text("At least 2 letters or numbers.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                Text("Your company's short name in addresses: \(model.normalizedSlug)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
