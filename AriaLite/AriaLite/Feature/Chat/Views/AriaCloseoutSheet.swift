//
//  AriaCloseoutSheet.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Chiude l'intervento fatto in chat e lo archivia come work order in ARIA (e MaintainX se collegato),
//  col report allegato. Due fasi come la web: anteprima senza scrivere niente, poi conferma.
//  Solo il report (senza ordine) va con POST …/report sulla sessione di chat.
//
//  L'operatore ha meno scelte di un membro della web (guida, sezione 6): niente "sposta gli altri" (non vede
//  gli ordini dei colleghi) e come assegnatario solo sé stesso; lasciarlo vuoto tiene la preselezione.
//  La logica sta in AriaCloseoutViewModel.
//

import SwiftUI

struct AriaCloseoutSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model: AriaCloseoutViewModel

    /// Il foglio nasce per una scelta: un'altra scelta è un altro foglio (`sheet(item:)`).
    init(chat: AriaAgentChat, choice: AriaCloseoutChoice) {
        _model = State(initialValue: AriaCloseoutViewModel(chat: chat, choice: choice))
    }

    var body: some View {
        NavigationStack {
            Form {
                if let result = model.result {
                    outcome("ARIA", result.aria)
                    outcome("MaintainX", result.maintainx)
                    if result.reportArchived == true {
                        reportSection(filename: result.filename, sizeBytes: result.sizeBytes, downloadUrl: result.downloadUrl)
                    }
                } else if let archive = model.archive {
                    reportSection(filename: archive.filename, sizeBytes: archive.sizeBytes, downloadUrl: archive.downloadUrl)
                } else if let proposal = model.proposal {
                    AriaCloseoutForm(model: model, proposal: proposal)
                } else if model.isReportOnly {
                    Section {
                        Text("The intervention report will be archived with this chat.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } else if model.isLoadingPreview {
                    HStack { Spacer(); ProgressView(); Spacer() }
                        .accessibilityIdentifier("closeout.loading")
                }
                if let error = model.error {
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
                    Button(model.isDone ? "Done" : "Cancel") { dismiss() }
                        .accessibilityIdentifier("closeout.dismiss")
                }
                if !model.isDone {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Confirm") { Task { await model.confirm() } }
                            .disabled(!model.canConfirm)
                            .accessibilityIdentifier("closeout.confirm")
                    }
                }
            }
            .task { await model.loadPreview() }
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
}

/// Il modulo dell'ordine, precompilato dalla proposta del server.
private struct AriaCloseoutForm: View {
    @Bindable var model: AriaCloseoutViewModel
    let proposal: AriaCloseoutProposal

    var body: some View {
        Section("Work order") {
            TextField("Title", text: text(\.title))
                .accessibilityIdentifier("closeout.title")
            Picker("Priority", selection: $model.priority) {
                Text("High").tag("high")
                Text("Medium").tag("medium")
                Text("Low").tag("low")
            }
            if let options = model.categoryOptions {
                Picker("Category", selection: text(\.category)) {
                    Text(verbatim: "—").tag("")
                    ForEach(options, id: \.self) { Text($0).tag($0) }
                }
            } else {
                TextField("Category", text: text(\.category))
            }
            if let locations = model.locationOptions {
                Picker("Location", selection: text(\.location)) {
                    Text(verbatim: "—").tag("")
                    ForEach(locations, id: \.self) { Text($0).tag($0) }
                }
            }
            assignee
            if let targets = model.targetsText {
                LabeledContent("Written to", value: targets)
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
        if let conflicts = model.conflicts {
            Section("Already scheduled that day") {
                ForEach(conflicts) { Text("\($0.system ?? "") · \($0.title)") }
                Picker("What to do", selection: $model.conflictChoice) {
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
    private var assignee: some View {
        if model.isOperator {
            if model.canAssignToMe {
                if let name = model.proposedAssigneeName {
                    LabeledContent("Proposed assignee", value: name)
                }
                Toggle("Assign to me", isOn: $model.assignedToMe)
                    .accessibilityIdentifier("closeout.assignToMe")
            }
        } else if !model.assigneeCandidates.isEmpty {
            Picker("Assignee", selection: text(\.assigneeId)) {
                Text("Unassigned").tag("")
                ForEach(model.assigneeCandidates) { Text($0.name ?? $0.id).tag($0.id) }
            }
        }
    }

    private func text(_ key: WritableKeyPath<AriaCloseoutRequest, String?>) -> Binding<String> {
        Binding(get: { model.text(key) }, set: { model.setText(key, $0) })
    }
}
