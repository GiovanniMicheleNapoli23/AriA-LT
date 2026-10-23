//
//  AdminCraftedAriaEditor+Run.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Una richiesta di modifica da cima a fondo (askAriaToEdit della web). Un documento lungo parte in più
//  richieste sotto il limite del firewall, fino a 6 insieme, ciascuna in una sessione sua (la prima nella
//  principale; le altre si archiviano a lavoro finito). Se un'istruzione non si può eseguire parte per
//  parte (un riassunto di tutto), le parti si leggono una dopo l'altra in un'unica conversazione nuova e
//  l'istruzione arriva con l'ultima.
//

import Foundation

/// Lo stato condiviso dai lavoratori di una richiesta: cosa hanno risposto, a che punto sono, perché si sono fermati.
@MainActor
final class AdminCraftedAriaRun {
    let plan: AdminCraftedAriaPlan
    var answers: [AdminCraftedAriaAnswer?]
    var next = 0
    var done = 0
    var failure: (any Error)?
    var needsWhole = false
    /// Un guasto, o una parte che non basta da sola: gli altri lavoratori si fermano.
    var stopped = false

    init(plan: AdminCraftedAriaPlan) {
        self.plan = plan
        answers = Array(repeating: nil, count: plan.parts.count)
    }

    /// Tutte le modifiche arrivate, con i pezzi rimessi nei loro blocchi.
    var changes: [AdminCraftedAriaChange] {
        AdminCraftedAriaSplitter.join(answers.flatMap { $0?.changes ?? [] }, pieces: plan.pieces)
    }
}

/// Ciò che non cambia da una parte all'altra.
nonisolated struct AdminCraftedAriaJob: Sendable {
    let instruction: String
    let focus: String?
    let fields: AdminCraftedAriaFields
    /// "✎ titolo — istruzione": il nome della conversazione nella cronologia della chat.
    let name: String
}

extension AdminCraftedAriaEditor {
    /// Parti chieste insieme: un rapporto intero in un colpo, senza sommergere l'agente.
    private static let concurrency = 6

    func perform(instruction: String, title: String, blocks: [AdminCraftedAriaBlock], focus: String?,
                 locale: String?, continuing: String?) async throws -> AdminCraftedAriaProposal {
        let context = await backend.api.context.snapshot()
        guard let plantId = plantId ?? context.plantId, !plantId.isEmpty else { throw AriaError.missingPlant }
        let sessionId = continuing ?? AriaNanoID.make()
        let fields = AdminCraftedAriaFields(plantId: plantId, companyId: companyId ?? context.companyId,
                                            sessionId: sessionId, locale: locale ?? context.locale)
        let plan = try AdminCraftedAriaPlan.make(instruction: instruction, blocks: blocks, focus: focus, fields: fields,
                                                 limit: backend.api.config.maxBodyBytes)
        let total = plan.parts.count
        let job = AdminCraftedAriaJob(instruction: instruction, focus: focus, fields: fields,
                                      name: "✎ \(title) — \(instruction)")
        let run = AdminCraftedAriaRun(plan: plan)
        setProgress(done: 0, total: total, whole: false)

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<min(Self.concurrency, total) {
                group.addTask { await self.work(run, job) }
            }
        }
        // Letto intero, la conversazione principale è quella della lettura intera, non questa.
        if continuing == nil {
            fileSession(sessionId, title: run.needsWhole ? "\(job.name) (1/\(total))" : job.name, extra: run.needsWhole)
        }
        try Task.checkCancellation()
        if let failure = run.failure { throw failure }

        if !run.needsWhole {
            var notes: [String] = []
            for case let note? in run.answers.map({ $0?.note }) where !notes.contains(note) { notes.append(note) }
            return AdminCraftedAriaProposal(changes: run.changes, note: notes.isEmpty ? nil : notes.joined(separator: " "),
                                            sessionId: sessionId)
        }
        return try await readWhole(plan, job)
    }

    // MARK: Parti in parallelo

    private func work(_ run: AdminCraftedAriaRun, _ job: AdminCraftedAriaJob) async {
        while run.next < run.plan.parts.count, !run.stopped, !Task.isCancelled {
            let index = run.next
            run.next += 1
            await runPart(index, run, job)
        }
    }

    private func runPart(_ index: Int, _ run: AdminCraftedAriaRun, _ job: AdminCraftedAriaJob) async {
        let total = run.plan.parts.count
        var fields = job.fields
        // Una conversazione non prende due turni insieme: la prima parte sta nella principale, le altre in una nuova.
        if index > 0 { fields.sessionId = AriaNanoID.make() }
        defer {
            if index > 0 { fileSession(fields.sessionId, title: "\(job.name) (\(index + 1)/\(total))", extra: true) }
        }
        let blocks = run.plan.parts[index]
        let input = AdminCraftedAriaPrompt.edit(instruction: job.instruction, blocks: blocks, focus: job.focus,
                                                part: .init(n: index + 1, total: total))
        do {
            let answer = try await askOnce(input, blocks: blocks, fields: fields, run: run)
            if run.stopped || Task.isCancelled { return }
            if answer.needsWhole, total > 1 {
                run.needsWhole = true
                run.stopped = true
                return
            }
            run.answers[index] = answer
            run.done += 1
            setProgress(done: run.done, total: total, whole: false)
            changesHandler?(run.changes)
        } catch {
            // Una parte che fallisce ferma le altre: una proposta coi buchi non è da offrire.
            if !run.stopped, !Task.isCancelled {
                run.failure = error
                run.stopped = true
            }
        }
    }

    // MARK: Lettura intera

    /// Niente di quello che è venuto dalle parti vale: risponde la lettura intera.
    private func readWhole(_ plan: AdminCraftedAriaPlan, _ job: AdminCraftedAriaJob) async throws -> AdminCraftedAriaProposal {
        changesHandler?([])
        let total = plan.parts.count
        var fields = job.fields
        fields.sessionId = AriaNanoID.make()
        let wholeSession = fields.sessionId
        setProgress(done: 0, total: total, whole: true)
        defer { fileSession(wholeSession, title: job.name, extra: false) }
        for index in 0..<(total - 1) {
            let input = AdminCraftedAriaPrompt.read(blocks: plan.parts[index], part: .init(n: index + 1, total: total))
            try await readOnce(input, fields: fields)
            setProgress(done: index + 1, total: total, whole: true)
        }
        let input = AdminCraftedAriaPrompt.edit(instruction: job.instruction, blocks: plan.parts[total - 1], focus: job.focus,
                                                part: .init(n: total, total: total, whole: true))
        try await checkRoom(wholeSession, input: input)
        let answer = try await askOnce(input, blocks: plan.parts.flatMap { $0 }, fields: fields, run: nil)
        setProgress(done: total, total: total, whole: true)
        return AdminCraftedAriaProposal(changes: AdminCraftedAriaSplitter.join(answer.changes, pieces: plan.pieces),
                                        note: answer.note, sessionId: wholeSession)
    }
}
