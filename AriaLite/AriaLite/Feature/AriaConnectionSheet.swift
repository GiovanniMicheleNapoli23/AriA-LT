//
//  AriaConnectionSheet.swift
//  AriaLite
//
//  Collegamento al backend Aria: login con link via email (come la web), azienda e stabilimento.
//  In DEBUG anche server personalizzati e token incollato.
//

import SwiftUI
import UniformTypeIdentifiers

struct AriaConnectionSheet: View {
    let backend: AriaBackend
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var captcha: String?
    @State private var captchaAttempt = 0
    @State private var pastedLink = ""
    /// Un link vale una volta sola: se è già fallito non lo si rimanda al server.
    @State private var failedLink: URL?
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

    @ViewBuilder
    private var signInSection: some View {
        if let sentTo = backend.pendingLinkEmail {
            Section {
                LabeledContent("Sent to", value: sentTo)
                // Un link copiato arriva come URL (Mail, Safari) o come testo: accettiamo entrambi.
                PasteButton(supportedContentTypes: [.url, .plainText]) { providers in
                    Task { @MainActor in await signIn(pasted: await Self.text(from: providers)) }
                }
                .disabled(busy)
                TextField("Or paste the link here", text: $pastedLink, axis: .vertical)
                    .lineLimit(1...3)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .disabled(busy)
                    .onChange(of: pastedLink) { _, text in
                        if backend.magicLink(in: text) != nil { Task { await signIn(pasted: text) } }
                    }
                if busy { ProgressView() }
                Button("Send a new link") {
                    backend.cancelPendingLink()
                    pastedLink = ""
                }
                .font(.footnote)
            } header: {
                Text("Check your email")
            } footer: {
                Text("In the email, press and hold the sign-in button, choose Copy Link and paste it here. Don't open it in the browser: the link works once and expires in 10 minutes.")
            }
        } else {
            Section {
                TextField("Work email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                AriaTurnstileView(siteKey: backend.api.config.turnstileSiteKey, origin: backend.webURL) { token in
                    captcha = token
                }
                .id(captchaAttempt)
                .frame(height: 65)
                .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                Button {
                    Task { await sendLink() }
                } label: {
                    HStack {
                        Text("Send sign-in link")
                        if busy { Spacer(); ProgressView() }
                    }
                }
                .disabled(busy || email.isEmpty || captcha == nil)
            } header: {
                Text("Sign in to Aria")
            } footer: {
                Text("As on the web app, we will email you a sign-in link.")
            }
        }
    }

    private func sendLink() async {
        guard let captcha else { return }
        busy = true
        defer {
            busy = false
            // Il token Turnstile vale una volta sola: se ne genera uno nuovo.
            self.captcha = nil
            captchaAttempt += 1
        }
        do {
            try await backend.sendMagicLink(email: email, captcha: captcha)
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func signIn(pasted text: String) async {
        guard !busy else { return }
        guard let link = backend.magicLink(in: text) else {
            error = String(localized: "This is not an Aria sign-in link. Copy the link from the email and try again.")
            return
        }
        guard link != failedLink else { return }
        busy = true
        defer { busy = false }
        do {
            try await backend.completeSignIn(with: link)
            pastedLink = ""
            error = nil
        } catch {
            failedLink = link
            self.error = error.localizedDescription
        }
    }

    private static func text(from providers: [NSItemProvider]) async -> String {
        var parts: [String] = []
        for provider in providers {
            if provider.canLoadObject(ofClass: URL.self) {
                let url = await withCheckedContinuation { continuation in
                    _ = provider.loadObject(ofClass: URL.self) { url, _ in continuation.resume(returning: url) }
                }
                if let url { parts.append(url.absoluteString) }
            } else if provider.canLoadObject(ofClass: String.self) {
                let text = await withCheckedContinuation { continuation in
                    _ = provider.loadObject(ofClass: String.self) { text, _ in continuation.resume(returning: text) }
                }
                if let text { parts.append(text) }
            }
        }
        return parts.joined(separator: " ")
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
