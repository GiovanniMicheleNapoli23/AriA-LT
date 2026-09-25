//
//  AriaConnectionSheet.swift
//  AriaLite
//
//  Collegamento al backend Aria: login con codice via email, azienda e stabilimento.
//  In DEBUG anche server personalizzati e token incollato.
//

import SwiftUI

struct AriaConnectionSheet: View {
    let backend: AriaBackend
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var code = ""
    @State private var codeSent = false
    @State private var busy = false
    @State private var error: String?
    #if DEBUG
    @State private var server = ""
    @State private var web = ""
    @State private var devToken = ""
    #endif

    var body: some View {
        NavigationStack {
            Form {
                if backend.isSignedIn {
                    connectedSections
                } else {
                    signInSection
                    #if DEBUG
                    developerSection
                    #endif
                }

                if let message = error ?? backend.lastError {
                    Section {
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Aria server")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await backend.bootstrapIfNeeded() }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: Collegato

    @ViewBuilder
    private var connectedSections: some View {
        Section {
            LabeledContent("Server", value: backend.serverURL.host() ?? backend.serverURL.absoluteString)
            LabeledContent("Status") {
                Label(backend.isReady ? "Online" : "No plant", systemImage: "circle.fill")
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(backend.isReady ? .green : .orange)
                    .font(.subheadline)
            }
        }

        Section {
            if backend.isLoading && backend.companies.isEmpty {
                ProgressView()
            } else {
                Picker("Company", selection: Binding(
                    get: { backend.activeCompanyId ?? "" },
                    set: { id in Task { await backend.selectCompany(id) } }
                )) {
                    ForEach(backend.companies) { Text($0.name).tag($0.id) }
                }
                Picker("Plant", selection: Binding(
                    get: { backend.activePlantId ?? "" },
                    set: { id in Task { await backend.selectPlant(id) } }
                )) {
                    ForEach(backend.plants) { Text($0.name).tag($0.id) }
                }
                .disabled(backend.plants.isEmpty)
            }
        } footer: {
            Text("Aria answers using the data of the selected plant.")
        }

        Section {
            Button("Disconnect", role: .destructive) {
                Task { await backend.signOut() }
            }
        }
    }

    // MARK: Login

    private var signInSection: some View {
        Section {
            TextField("Work email", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .disabled(codeSent)
            if codeSent {
                TextField("6-digit code", text: $code)
                    .textContentType(.oneTimeCode)
                    .keyboardType(.numberPad)
            }
            Button {
                Task { await submit() }
            } label: {
                HStack {
                    Text(codeSent ? "Sign in" : "Send code")
                    if busy { Spacer(); ProgressView() }
                }
            }
            .disabled(busy || email.isEmpty || (codeSent && code.count < 6))
            if codeSent {
                Button("Use a different email") {
                    codeSent = false
                    code = ""
                }
                .font(.footnote)
            }
        } header: {
            Text("Sign in to Aria")
        } footer: {
            Text(codeSent
                 ? "We sent a code to your email. It is valid for 10 minutes."
                 : "We will send you a sign-in code by email.")
        }
    }

    private func submit() async {
        busy = true
        defer { busy = false }
        do {
            if codeSent {
                try await backend.verify(email: email, code: code)
            } else {
                try await backend.startLogin(email: email)
                codeSent = true
            }
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: Sviluppo

    #if DEBUG
    private var developerSection: some View {
        Section {
            TextField(AriaConfig.productionAPI.absoluteString, text: $server)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField(AriaConfig.productionWeb.absoluteString, text: $web)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("Use these servers") {
                func parse(_ raw: String) -> URL? {
                    let url = URL(string: raw.trimmingCharacters(in: .whitespaces))
                    return url?.scheme == nil ? nil : url
                }
                backend.setServers(api: parse(server), web: parse(web))
                server = backend.serverURL.absoluteString
                web = backend.webURL.absoluteString
            }
            .onAppear {
                server = backend.serverURL.absoluteString
                web = backend.webURL.absoluteString
            }
            TextField("Access token (JWT)", text: $devToken, axis: .vertical)
                .lineLimit(1...3)
                .font(.system(.footnote, design: .monospaced))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("Use token") {
                Task {
                    do {
                        try await backend.useDeveloperToken(devToken)
                        devToken = ""
                        error = nil
                    } catch {
                        self.error = error.localizedDescription
                    }
                }
            }
            .disabled(devToken.isEmpty)
        } header: {
            Text(verbatim: "Developer")
        } footer: {
            Text(verbatim: "API (FastAPI) and web app (login). Token: GET /api/aria/token on the web app.")
        }
    }
    #endif
}
