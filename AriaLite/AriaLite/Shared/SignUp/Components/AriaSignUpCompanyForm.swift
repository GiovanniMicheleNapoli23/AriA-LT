//
//  AriaSignUpCompanyForm.swift
//  AriaLite
//
//  Created by Giovanni Michele on 11/11/26.
//
//  Il passo Azienda, con i campi e i testi della sezione "Azienda" della web: nome, indirizzo del workspace
//  (`aria.app/…`, con l'esito del controllo), sito web aziendale verificato (AriaSignUpWebsiteField), settore
//  obbligatorio (con "Altro" il proprio testo) e dimensione facoltativa.
//

import SwiftUI

struct AriaSignUpCompanyForm: View {
    @Bindable var model: AriaSignUpViewModel
    @FocusState private var focus: Field?
    @FocusState private var websiteFocused: Bool
    @ScaledMetric(relativeTo: .body) private var iconWidth: CGFloat = 20

    private enum Field { case name, slug, otherIndustry }

    var body: some View {
        VStack(spacing: 16) {
            if model.companyOnServer {
                // Già sul server: si vede, non si cambia più (come la web, "Il tuo workspace è già stato creato").
                let saved = model.savedCompany
                AriaSignUpSavedCard(icon: "building.2", title: saved?.name ?? String(localized: "Your company"),
                                    detail: (saved?.slug).flatMap { $0.isEmpty ? nil : "aria.app/\($0)" },
                                    note: "Your workspace is already created.")
            } else {
                fields
            }

            LoginPrimaryButton(title: "Continue", isEnabled: model.canCreateCompany, isBusy: model.isSaving) {
                focus = nil
                websiteFocused = false
                Task { await model.continueFromStep() }
            }
        }
        .animation(.snappy(duration: 0.25), value: model.slugState)
    }

    @ViewBuilder
    private var fields: some View {
            VStack(alignment: .leading, spacing: 8) {
                VStack(spacing: 0) {
                    nameRow
                    divider
                    slugRow
                }
                .ariaSignUpCard()
                AriaSignUpSlugCaption(model: model)
                    .padding(.horizontal, 4)
            }

            AriaSignUpWebsiteField(model: model, focus: $websiteFocused)

            VStack(spacing: 0) {
                LoginCardRow(icon: "gearshape.2") {
                    AriaSignUpChoicePicker(title: "Industry", placeholder: "Industry", selection: $model.industry,
                                           options: AriaCompanyIndustry.allCases) { $0.title }
                }
                if model.industry == .other {
                    divider
                    LoginCardRow(icon: "pencil") {
                        TextField("Your industry", text: $model.otherIndustry)
                            .submitLabel(.done)
                            .focused($focus, equals: .otherIndustry)
                            .onSubmit { focus = nil }
                    }
                    .transition(.opacity)
                }
                divider
                LoginCardRow(icon: "person.3") {
                    AriaSignUpChoicePicker(title: "Size", placeholder: "Size (optional)", selection: $model.size,
                                           options: AriaCompanySize.allCases, verbatim: \.title)
                }
            }
            .ariaSignUpCard()
            .animation(.snappy(duration: 0.25), value: model.industry)
            .onChange(of: model.industry) { _, industry in
                if industry == .other { focus = .otherIndustry }
            }
    }

    private var divider: some View {
        Divider().padding(.leading, 28 + iconWidth)
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
            HStack(spacing: 0) {
                Text(verbatim: "aria.app/")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                TextField("Workspace address", text: $model.slug)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.asciiCapable)
                    .submitLabel(.next)
                    .focused($focus, equals: .slug)
                    .onSubmit { websiteFocused = true }
            }
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
                .accessibilityHidden(true)
        case .taken:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
                .accessibilityHidden(true)
        case .failed:
            Image(systemName: "exclamationmark.circle")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        case .idle:
            EmptyView()
        }
    }
}
