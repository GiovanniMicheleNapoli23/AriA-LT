//
//  AriaChatOptionsSheet.swift
//  AriaLite
//
//  Created by Giovanni Michele on 26/09/26.
//
//  Il menu "···" della chat: la procedura della sessione (il "Task & Event Rail" della web).
//  Lo step corrente è la scheda in evidenza, con i suoi task sempre visibili e il prossimo da fare
//  evidenziato; gli step precedenti sono righe compatte con il loro esito, da aprire al bisogno.
//  In fondo la lingua di dettatura (anche dal tocco lungo sul microfono della barra), il report in Word e le
//  azioni sulla sessione (chiusura intervento, fine procedura). La memoria della conversazione sta nella barra.
//  La logica sta in AriaChatOptionsViewModel.
//

import SwiftUI

struct AriaChatOptionsSheet: View {
    /// Chiusura intervento: la presenta chi apre il foglio, dopo averlo chiuso.
    private let onCloseOut: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @AppStorage(AriaDictation.languageKey) private var dictationLanguage = AriaDictation.automatic
    @State private var model: AriaChatOptionsViewModel

    init(chat: AriaAgentChat, onCloseOut: (() -> Void)?) {
        _model = State(initialValue: AriaChatOptionsViewModel(chat: chat, offersCloseOut: onCloseOut != nil))
        self.onCloseOut = onCloseOut
    }

    var body: some View {
        NavigationStack {
            List {
                if let current = model.currentStep {
                    Section("Current step") {
                        AriaCurrentStepCard(list: current.list, messageId: current.messageId, chat: model.chat)
                            .listRowInsets(EdgeInsets(top: 14, leading: 14, bottom: 8, trailing: 14))
                            .accessibilityElement(children: .contain)
                            .accessibilityIdentifier("options.currentStep")
                    }
                    if !model.previousSteps.isEmpty {
                        Section("Previous steps") {
                            ForEach(model.previousSteps, id: \.messageId) { step in
                                AriaPastStepRow(list: step.list, messageId: step.messageId, chat: model.chat)
                            }
                        }
                    }
                } else {
                    Section {
                        ContentUnavailableView("No procedure yet", systemImage: "list.bullet.clipboard",
                                               description: Text("The steps Aria gives you in this chat will appear here."))
                            .accessibilityIdentifier("options.noProcedure")
                    }
                }

                Section("Microphone") {
                    Picker(selection: $dictationLanguage) {
                        Text("Automatic").tag(AriaDictation.automatic)
                        ForEach(AriaDictation.languages) { language in
                            Text(verbatim: language.label).tag(language.code)
                        }
                    } label: {
                        Label("Dictation language", systemImage: "mic")
                    }
                    .pickerStyle(.navigationLink)
                }

                if model.canDownloadReport { reportSection }

                if model.showsSessionActions {
                    Section {
                        if let onCloseOut, model.canCloseOut {
                            Button("Close out intervention", systemImage: "checkmark.seal") {
                                dismiss()
                                onCloseOut()
                            }
                            .disabled(!model.isCloseOutEnabled)
                            .accessibilityIdentifier("options.closeOut")
                        }
                        if model.canEndProcedure {
                            Button("End procedure", systemImage: "door.left.hand.closed", role: .destructive) {
                                model.askToEndProcedure()
                            }
                            .disabled(!model.isEndProcedureEnabled)
                        }
                    }
                }
            }
            .navigationTitle("Procedure")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("End the procedure?", isPresented: $model.confirmingEnd) {
                Button("End procedure", role: .destructive) {
                    dismiss()
                    model.endProcedure()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Aria will ask you to confirm before closing it.")
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var reportSection: some View {
        Section {
            if let report = model.report {
                ShareLink(item: report.url) {
                    Label("Share report", systemImage: "square.and.arrow.up")
                }
                .accessibilityIdentifier("options.reportShare")
            } else {
                Button {
                    Task { await model.prepareReport() }
                } label: {
                    HStack {
                        Label("Intervention report (Word)", systemImage: "doc.richtext")
                        Spacer()
                        if model.preparingReport { ProgressView() }
                    }
                }
                .disabled(!model.canPrepareReport)
                .accessibilityIdentifier("options.report")
            }
        } footer: {
            if let reportError = model.reportError {
                Text(reportError).foregroundStyle(.red).accessibilityIdentifier("options.reportError")
            }
        }
    }
}
