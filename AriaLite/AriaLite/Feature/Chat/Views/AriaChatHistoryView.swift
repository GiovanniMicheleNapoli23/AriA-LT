//
//  AriaChatHistoryView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 25/09/26.
//
//  La sezione "Chat" della sidebar (chat-history-sheet della web): conversazioni
//  raggruppate per data, cerca per titolo, fissa, rinomina, elimina, apri.
//

import SwiftUI

struct AriaChatHistoryView: View {
    let chat: AriaAgentChat
    let store: AriaSessionStore
    let backend: AriaBackend
    let onOpen: (AriaSessionSummary) -> Void
    let onNewChat: () -> Void
    let onConnect: () -> Void

    @State private var query = ""
    @State private var renaming: AriaSessionSummary?

    private var visible: [AriaSessionSummary] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return store.visible }
        return store.visible.filter { ($0.title ?? "").localizedCaseInsensitiveContains(q) }
    }

    private var groups: [(title: LocalizedStringKey, items: [AriaSessionSummary])] {
        let calendar = Calendar.current
        var today: [AriaSessionSummary] = [], yesterday: [AriaSessionSummary] = []
        var week: [AriaSessionSummary] = [], older: [AriaSessionSummary] = []
        for session in visible {
            guard let date = session.lastActivity else { older.append(session); continue }
            if calendar.isDateInToday(date) { today.append(session) }
            else if calendar.isDateInYesterday(date) { yesterday.append(session) }
            else if date > .now.addingTimeInterval(-7 * 86_400) { week.append(session) }
            else { older.append(session) }
        }
        return [("Today", today), ("Yesterday", yesterday), ("Last week", week), ("Older", older)].filter { !$0.items.isEmpty }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(groups, id: \.items.first?.id) { group in
                    Section(group.title) {
                        ForEach(group.items) { session in row(session) }
                    }
                }
                if !store.reachedEnd && !store.sessions.isEmpty && query.isEmpty {
                    Button("Load more") { Task { await store.load(more: true) } }
                        .disabled(store.isLoading)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .liteBackground()
            .overlay { placeholder }
            .searchable(text: $query, prompt: "Search conversations")
            .refreshable { await store.load() }
            .navigationTitle("Chats")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { AriaSidebarButton() }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("New chat", systemImage: "square.and.pencil", action: onNewChat)
                }
            }
            .task { await store.load() }
            .modifier(AriaRenameSessionAlert(session: $renaming, store: store))
        }
    }

    @ViewBuilder
    private var placeholder: some View {
        if !backend.isReady {
            ContentUnavailableView {
                Label("Not connected", systemImage: "bolt.horizontal.circle")
            } description: {
                Text("Connect to the Aria server to see your conversations.")
            } actions: {
                Button("Connect", action: onConnect)
                    .buttonStyle(.borderedProminent)
                    .tint(Color.liteAccent)
            }
        } else if store.isLoading && store.sessions.isEmpty {
            ProgressView()
        } else if let error = store.error, store.sessions.isEmpty {
            ContentUnavailableView("Couldn't load conversations", systemImage: "exclamationmark.triangle", description: Text(error))
        } else if visible.isEmpty && !store.isLoading {
            if query.isEmpty {
                ContentUnavailableView("No conversations", systemImage: "bubble.left.and.bubble.right")
            } else {
                ContentUnavailableView.search(text: query)
            }
        }
    }

    private func row(_ session: AriaSessionSummary) -> some View {
        Button { onOpen(session) } label: {
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                Image(systemName: store.isPinned(session) ? "pin" : "bubble.left")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 3) {
                    Text(session.displayTitle)
                        .font(.system(size: 16, weight: session.sessionId == chat.sessionId ? .semibold : .regular))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    if let date = session.lastActivity {
                        Text(date, format: .relative(presentation: .named))
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .listRowBackground(Color.clear)
        .ariaSessionMenu(session, store: store, chat: chat) { renaming = session }
        .swipeActions {
            Button("Delete", systemImage: "trash", role: .destructive) {
                Task { await store.delete(session, closing: chat) }
            }
            Button("Rename", systemImage: "pencil") { renaming = session }
                .tint(.orange)
        }
    }
}

// MARK: - Closeout

/// Chiude l'intervento fatto in chat e lo archivia come work order in ARIA (e MaintainX se collegato),
/// col report allegato. Due fasi come la web: anteprima senza scrivere niente, poi conferma.
/// Solo il report (senza ordine) va con POST …/report sulla sessione di chat.
///
/// L'operatore ha meno scelte di un membro della web (guida, sezione 6): niente "sposta gli altri" (non vede
/// gli ordini dei colleghi) e come assegnatario solo sé stesso; lasciarlo vuoto tiene la preselezione.
struct AriaCloseoutSheet: View {
    let chat: AriaAgentChat
    let choice: AriaCloseoutChoice
    @Environment(\.dismiss) private var dismiss

    @State private var proposal: AriaCloseoutProposal?
    @State private var request = AriaCloseoutRequest()
    @State private var result: AriaCloseoutResult?
    @State private var archive: AriaReportArchive?
    @State private var busy = false
    @State private var error: String?
    /// I valori accettati che il server ha mandato con un 422 (`detail.valid`), per campo: i picker si rifanno da qui.
    @State private var validChoices: [String: [String]] = [:]

    private var isDone: Bool { result != nil || archive != nil }

    var body: some View {
        NavigationStack {
            Form {
                if let result {
                    outcome("ARIA", result.aria)
                    outcome("MaintainX", result.maintainx)
                    if result.reportArchived == true {
                        reportSection(filename: result.filename, sizeBytes: result.sizeBytes, downloadUrl: result.downloadUrl)
                    }
                } else if let archive {
                    reportSection(filename: archive.filename, sizeBytes: archive.sizeBytes, downloadUrl: archive.downloadUrl)
                } else if let proposal {
                    form(proposal)
                } else if !choice.workOrder {
                    Section {
                        Text("The intervention report will be archived with this chat.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } else if error == nil {
                    HStack { Spacer(); ProgressView(); Spacer() }
                        .accessibilityIdentifier("closeout.loading")
                }
                if let error {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red).font(.footnote)
                            .accessibilityIdentifier("closeout.error")
                    }
                }
            }
            .navigationTitle("Close out intervention")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isDone ? "Done" : "Cancel") { dismiss() }
                        .accessibilityIdentifier("closeout.dismiss")
                }
                if !isDone {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Confirm") { Task { await confirm() } }
                            .disabled(busy || !chat.canCloseOut || (choice.workOrder && proposal == nil))
                            .accessibilityIdentifier("closeout.confirm")
                    }
                }
            }
            .task { await loadPreview() }
        }
    }

    @ViewBuilder
    private func form(_ proposal: AriaCloseoutProposal) -> some View {
        Section("Work order") {
            TextField("Title", text: text(\.title))
                .accessibilityIdentifier("closeout.title")
            Picker("Priority", selection: Binding(get: { request.priority ?? "medium" }, set: { request.priority = $0 })) {
                Text("High").tag("high")
                Text("Medium").tag("medium")
                Text("Low").tag("low")
            }
            if let options = validChoices["category"] ?? proposal.categoryOptions, !options.isEmpty {
                Picker("Category", selection: text(\.category)) {
                    Text(verbatim: "—").tag("")
                    ForEach(options, id: \.self) { Text($0).tag($0) }
                }
            } else {
                TextField("Category", text: text(\.category))
            }
            if let locations = validChoices["location"] ?? proposal.locationOptions?.map(\.name), !locations.isEmpty {
                Picker("Location", selection: text(\.location)) {
                    Text(verbatim: "—").tag("")
                    ForEach(locations, id: \.self) { Text($0).tag($0) }
                }
            }
            assignee(proposal)
            if let targets = proposal.targets, !targets.isEmpty {
                LabeledContent("Written to", value: targets.map { $0 == "aria" ? "ARIA" : $0 == "maintainx" ? "MaintainX" : $0 }.joined(separator: " + "))
            }
        }
        if let description = proposal.description, !description.isEmpty {
            Section("Description") { Text(description).font(.footnote) }
        }
        TextField("Notes", text: text(\.notes), axis: .vertical)
            .lineLimit(2...5)
        if let unresolved = proposal.unresolved, !unresolved.isEmpty {
            Section("To fix") {
                ForEach(unresolved.keys.sorted(), id: \.self) { key in
                    Text("\(key): “\(unresolved[key]?.value ?? "")” doesn't exist in MaintainX")
                        .foregroundStyle(.orange)
                }
            }
        }
        // Un operatore non vede gli ordini dei colleghi (la lista arriva vuota) e non può spostarli.
        if !chat.isOperator, let conflicts = proposal.conflicts, !conflicts.isEmpty {
            Section("Already scheduled that day") {
                ForEach(conflicts) { Text("\($0.system ?? "") · \($0.title)") }
                Picker("What to do", selection: Binding(get: { request.conflictChoice ?? "file" }, set: { request.conflictChoice = $0 })) {
                    Text("Keep everything").tag("file")
                    Text("Move the others").tag("shift")
                }
                .accessibilityIdentifier("closeout.conflictChoice")
            }
        }
    }

    /// Un membro sceglie tra i candidati; l'operatore può solo prendere il lavoro per sé, altrimenti resta
    /// la preselezione della proposta.
    @ViewBuilder
    private func assignee(_ proposal: AriaCloseoutProposal) -> some View {
        let candidates = proposal.assignee?.candidates ?? []
        if chat.isOperator {
            if let me = chat.operatorId {
                let preselected = proposal.assignee?.selected
                if let preselected, preselected != me,
                   let name = candidates.first(where: { $0.id == preselected })?.name {
                    LabeledContent("Proposed assignee", value: name)
                }
                Toggle("Assign to me", isOn: Binding(get: { request.assigneeId == me },
                                                     set: { request.assigneeId = $0 ? me : nil }))
                    .accessibilityIdentifier("closeout.assignToMe")
            }
        } else if !candidates.isEmpty {
            Picker("Assignee", selection: text(\.assigneeId)) {
                Text("Unassigned").tag("")
                ForEach(candidates) { Text($0.name ?? $0.id).tag($0.id) }
            }
        }
    }

    @ViewBuilder
    private func outcome(_ name: String, _ outcome: AriaExternalWriteOutcome?) -> some View {
        Section(name) {
            if let outcome {
                LabeledContent("Result", value: outcome.status)
                    .accessibilityIdentifier("closeout.result.\(name)")
                if let title = outcome.title { Text(title) }
                if let url = outcome.url.flatMap(URL.init(string:)).flatMap(AriaURLPolicy.external) {
                    Link("Open", destination: url)
                }
                if let error = outcome.error { Text(error).foregroundStyle(.red) }
            } else {
                Text("Not requested").foregroundStyle(.secondary)
            }
        }
    }

    /// Il report archiviato. Il link scade presto: si apre adesso, non si salva.
    private func reportSection(filename: String?, sizeBytes: Int?, downloadUrl: String?) -> some View {
        Section("Report") {
            Label(filename ?? String(localized: "Intervention report"), systemImage: "doc.richtext")
                .accessibilityIdentifier("closeout.reportFile")
            if let sizeBytes {
                LabeledContent("Size", value: Int64(sizeBytes).formatted(.byteCount(style: .file)))
            }
            if let url = downloadUrl.flatMap(URL.init(string:)).flatMap(AriaURLPolicy.external) {
                Link("Open report", destination: url)
            }
        }
    }

    private func text(_ key: WritableKeyPath<AriaCloseoutRequest, String?>) -> Binding<String> {
        Binding(get: { request[keyPath: key] ?? "" }, set: { request[keyPath: key] = $0 })
    }

    private func base() -> AriaCloseoutRequest {
        var body = AriaCloseoutRequest(workOrder: choice.workOrder, report: choice.report)
        body.assigneeId = choice.assigneeId
        body.priority = choice.priority
        body.dueDate = choice.dueDate
        return body
    }

    private func loadPreview() async {
        // Solo il report non ha niente da approvare: si archivia alla conferma.
        guard choice.workOrder else { request = base(); return }
        do {
            let preview = try await chat.closeout(base())
            guard let p = preview.proposal else {
                error = String(localized: "The server didn't return a proposal.")
                return
            }
            proposal = p
            var body = base()
            body.title = p.title
            body.priority = choice.priority ?? p.priority
            body.category = p.category
            body.dueDate = choice.dueDate ?? p.dueDate
            body.assigneeId = choice.assigneeId ?? p.assignee?.selected
            if chat.isOperator, body.assigneeId != chat.operatorId { body.assigneeId = nil }
            body.startDate = p.startDate
            body.recurrenceType = p.recurrenceType
            body.recurrenceInterval = p.recurrenceInterval
            request = body
        } catch {
            show(error)
        }
    }

    private func confirm() async {
        busy = true
        defer { busy = false }
        do {
            if choice.workOrder {
                var body = request
                body.confirm = true
                for key in [\AriaCloseoutRequest.category, \.location, \.assigneeId, \.notes] where body[keyPath: key] == "" {
                    body[keyPath: key] = nil
                }
                // Riprovare dopo un errore a metà non crea un secondo ordine: il server rende quello già fatto.
                let written = try await chat.closeout(body)
                result = written
                chat.appendCloseoutSummary(written)
            } else {
                archive = try await chat.archiveReport()
            }
            error = nil
        } catch {
            show(error)
        }
    }

    private func show(_ error: any Error) {
        switch error as? AriaError {
        case .invalidChoice(let field, let valid, let message)?:
            // Categoria o location che MaintainX non ha: niente è stato scritto, si sceglie dalla lista vera.
            validChoices[field] = valid
            if field == "category", let value = request.category, !valid.contains(value) { request.category = nil }
            if field == "location", let value = request.location, !valid.contains(value) { request.location = nil }
            self.error = message
        case .http(404, _)?:
            self.error = String(localized: "There's no procedure to close out in this chat.")
        default:
            self.error = error.localizedDescription
        }
    }
}
