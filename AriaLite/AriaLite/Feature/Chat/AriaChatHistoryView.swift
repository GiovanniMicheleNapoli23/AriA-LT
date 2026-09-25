//
//  AriaChatHistoryView.swift
//  AriaLite
//
//  Storico delle conversazioni (chat-history-sheet della web): raggruppate per
//  data, cerca per titolo, rinomina, elimina, apri. Pagine da 60.
//

import SwiftUI

struct AriaChatHistoryView: View {
    let chat: AriaAgentChat
    let backend: AriaBackend
    @Environment(\.dismiss) private var dismiss

    @State private var sessions: [AriaSessionSummary] = []
    @State private var query = ""
    @State private var isLoading = false
    @State private var reachedEnd = false
    @State private var error: String?
    @State private var renaming: AriaSessionSummary?
    @State private var newTitle = ""

    private static let pageSize = 60
    private var api: AriaChatAPI { AriaChatAPI(api: backend.api) }

    private var visible: [AriaSessionSummary] {
        let list = sessions.filter { !$0.sessionId.hasPrefix("__briefing-") }
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return list }
        return list.filter { ($0.title ?? "").localizedCaseInsensitiveContains(q) }
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
                if !reachedEnd && !sessions.isEmpty && query.isEmpty {
                    Button("Load more") { Task { await load(more: true) } }
                        .disabled(isLoading)
                }
            }
            .overlay {
                if isLoading && sessions.isEmpty {
                    ProgressView()
                } else if let error, sessions.isEmpty {
                    ContentUnavailableView("Couldn't load conversations", systemImage: "exclamationmark.triangle", description: Text(error))
                } else if visible.isEmpty && !isLoading {
                    ContentUnavailableView("No conversations", systemImage: "bubble.left.and.bubble.right")
                }
            }
            .searchable(text: $query, prompt: "Search conversations")
            .refreshable { await load(more: false) }
            .navigationTitle("Conversations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .topBarLeading) {
                    Button("New chat", systemImage: "square.and.pencil") {
                        chat.newConversation()
                        dismiss()
                    }
                }
            }
            .task { await load(more: false) }
            .alert("Rename conversation", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
                TextField("Title", text: $newTitle)
                Button("Cancel", role: .cancel) {}
                Button("Save") { if let session = renaming { Task { await rename(session) } } }
            }
        }
    }

    private func row(_ session: AriaSessionSummary) -> some View {
        Button {
            Task { await chat.open(sessionId: session.sessionId) }
            dismiss()
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(session.title?.isEmpty == false ? session.title! : String(localized: "Untitled conversation"))
                    .font(.system(size: 15, weight: session.sessionId == chat.sessionId ? .semibold : .regular))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                if let date = session.lastActivity {
                    Text(date, format: .relative(presentation: .named))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .swipeActions {
            Button("Delete", systemImage: "trash", role: .destructive) { Task { await delete(session) } }
            Button("Rename", systemImage: "pencil") {
                newTitle = session.title ?? ""
                renaming = session
            }
            .tint(.orange)
        }
    }

    private func load(more: Bool) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let offset = more ? sessions.count : 0
            let page = try await api.sessions(limit: Self.pageSize, offset: offset)
            var seen = Set((more ? sessions : []).map(\.sessionId))
            let fresh = page.filter { seen.insert($0.sessionId).inserted }
            sessions = (more ? sessions : []) + fresh
            reachedEnd = page.count < Self.pageSize
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func rename(_ session: AriaSessionSummary) async {
        let title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        do {
            try await api.rename(sessionId: session.sessionId, title: title)
            await load(more: false)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func delete(_ session: AriaSessionSummary) async {
        do {
            try await api.delete(sessionId: session.sessionId)
            sessions.removeAll { $0.sessionId == session.sessionId }
            if session.sessionId == chat.sessionId { chat.newConversation() }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Closeout

/// Chiude l'intervento fatto in chat e lo archivia come work order in ARIA (e MaintainX se collegato).
/// Due fasi come la web: anteprima senza scrivere niente, poi conferma.
struct AriaCloseoutSheet: View {
    let chat: AriaAgentChat
    let choice: AriaCloseoutChoice
    @Environment(\.dismiss) private var dismiss

    @State private var proposal: AriaCloseoutProposal?
    @State private var request = AriaCloseoutRequest()
    @State private var result: AriaCloseoutResult?
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                if let result {
                    outcome("ARIA", result.aria)
                    outcome("MaintainX", result.maintainx)
                } else if let proposal {
                    form(proposal)
                } else if error == nil {
                    HStack { Spacer(); ProgressView(); Spacer() }
                }
                if let error {
                    Section { Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red).font(.footnote) }
                }
            }
            .navigationTitle("Close out intervention")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(result == nil ? "Cancel" : "Done") { dismiss() }
                }
                if result == nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Confirm") { Task { await confirm() } }
                            .disabled(busy || (choice.workOrder && proposal == nil))
                    }
                }
            }
            .task { await loadPreview() }
        }
    }

    @ViewBuilder
    private func form(_ proposal: AriaCloseoutProposal) -> some View {
        Section("Work order") {
            TextField("Title", text: Binding(get: { request.title ?? "" }, set: { request.title = $0 }))
            Picker("Priority", selection: Binding(get: { request.priority ?? "medium" }, set: { request.priority = $0 })) {
                Text("High").tag("high")
                Text("Medium").tag("medium")
                Text("Low").tag("low")
            }
            if let options = proposal.categoryOptions, !options.isEmpty {
                Picker("Category", selection: Binding(get: { request.category ?? "" }, set: { request.category = $0 })) {
                    Text(verbatim: "—").tag("")
                    ForEach(options, id: \.self) { Text($0).tag($0) }
                }
            } else {
                TextField("Category", text: Binding(get: { request.category ?? "" }, set: { request.category = $0 }))
            }
            if let locations = proposal.locationOptions, !locations.isEmpty {
                Picker("Location", selection: Binding(get: { request.location ?? "" }, set: { request.location = $0 })) {
                    Text(verbatim: "—").tag("")
                    ForEach(locations) { Text($0.name).tag($0.name) }
                }
            }
            if let candidates = proposal.assignee?.candidates, !candidates.isEmpty {
                Picker("Assignee", selection: Binding(get: { request.assigneeId ?? "" }, set: { request.assigneeId = $0 })) {
                    Text("Unassigned").tag("")
                    ForEach(candidates) { Text($0.name).tag($0.id) }
                }
            }
            if let targets = proposal.targets, !targets.isEmpty {
                LabeledContent("Written to", value: targets.map { $0 == "aria" ? "ARIA" : $0 == "maintainx" ? "MaintainX" : $0 }.joined(separator: " + "))
            }
        }
        if let description = proposal.description, !description.isEmpty {
            Section("Description") { Text(description).font(.footnote) }
        }
        TextField("Notes", text: Binding(get: { request.notes ?? "" }, set: { request.notes = $0 }), axis: .vertical)
            .lineLimit(2...5)
        if let unresolved = proposal.unresolved, !unresolved.isEmpty {
            Section("To fix") {
                ForEach(unresolved.keys.sorted(), id: \.self) { key in
                    Text("\(key): “\(unresolved[key]?.value ?? "")” doesn't exist in MaintainX")
                        .foregroundStyle(.orange)
                }
            }
        }
        if let conflicts = proposal.conflicts, !conflicts.isEmpty {
            Section("Already scheduled that day") {
                ForEach(conflicts) { Text("\($0.system ?? "") · \($0.title)") }
                Picker("What to do", selection: Binding(get: { request.conflictChoice ?? "file" }, set: { request.conflictChoice = $0 })) {
                    Text("Keep everything").tag("file")
                    Text("Move the others").tag("shift")
                }
            }
        }
    }

    @ViewBuilder
    private func outcome(_ name: String, _ outcome: AriaExternalWriteOutcome?) -> some View {
        Section(name) {
            if let outcome {
                LabeledContent("Result", value: outcome.status)
                if let title = outcome.title { Text(title) }
                if let url = outcome.url.flatMap(URL.init(string:)), url.scheme != nil {
                    Link("Open", destination: url)
                }
                if let error = outcome.error { Text(error).foregroundStyle(.red) }
            } else {
                Text("Not requested").foregroundStyle(.secondary)
            }
        }
    }

    private func base() -> AriaCloseoutRequest {
        var body = AriaCloseoutRequest(workOrder: choice.workOrder, report: choice.report)
        body.assigneeId = choice.assigneeId
        body.priority = choice.priority
        body.dueDate = choice.dueDate
        return body
    }

    private func loadPreview() async {
        // Solo il report non ha niente da approvare: si archivia subito alla conferma.
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
            body.startDate = p.startDate
            body.recurrenceType = p.recurrenceType
            body.recurrenceInterval = p.recurrenceInterval
            request = body
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func confirm() async {
        busy = true
        defer { busy = false }
        var body = request
        body.confirm = true
        for key in [\AriaCloseoutRequest.category, \.location, \.assigneeId, \.notes] where body[keyPath: key] == "" {
            body[keyPath: key] = nil
        }
        do {
            let written = try await chat.closeout(body)
            result = written
            chat.appendCloseoutSummary(written)
            error = nil
        } catch {
            // 422 = categoria o location che non esiste in MaintainX: niente è stato scritto.
            self.error = error.localizedDescription
        }
    }
}
