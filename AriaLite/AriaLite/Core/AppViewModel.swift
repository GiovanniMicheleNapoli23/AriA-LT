//
//  AppViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 19/03/26.
//

import Foundation

@Observable
class AppViewModel {
    var loggedInUser: User? = nil
    var checklistCompletions: [UUID: [UUID: Bool]] = [:]
    var fieldNotes: [UUID: [UUID: FieldNote]] = [:]
    var photoAttachments: [UUID: [PhotoAttachment]] = [:]
    var submissionStatus: SubmissionStatus = .idle
    var submittedWorkOrders: Set<UUID> = []
    var searchText: String = ""

    // MARK: - Auth
    func login(username: String, password: String) -> Bool {
        guard let user = mockUsers.first(where: {
            $0.username == username && password == mockPasswords[$0.id]
        }) else { return false }
        loggedInUser = user
        return true
    }

    func logout() {
        loggedInUser = nil
        checklistCompletions = [:]
        fieldNotes = [:]
        photoAttachments = [:]
        submissionStatus = .idle
    }

    // MARK: - WorkOrders
    var filteredWorkOrders: [WorkOrder] {
        guard let user = loggedInUser else { return [] }
        let assigned = mockWorkOrders.filter { $0.assignedUserID == user.id }
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return assigned }
        return assigned.filter { $0.title.lowercased().contains(query) }
    }

    var todayWorkOrders: [WorkOrder] {
        filteredWorkOrders.filter {
            Calendar.current.isDateInToday($0.scheduledDate)
        }
    }

    var pastWorkOrdersByDay: [(key: String, value: [WorkOrder])] {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let past = filteredWorkOrders.filter { $0.scheduledDate < startOfToday }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "it_IT")

        let grouped = Dictionary(grouping: past) { formatter.string(from: $0.scheduledDate) }

        return grouped.sorted { lhs, rhs in
            let d1 = formatter.date(from: lhs.key) ?? .distantPast
            let d2 = formatter.date(from: rhs.key) ?? .distantPast
            return d1 > d2
        }
    }

    // MARK: - Checklist
    func toggleItem(workOrderID: UUID, itemID: UUID, current: Bool) {
        if checklistCompletions[workOrderID] == nil {
            checklistCompletions[workOrderID] = [:]
        }
        checklistCompletions[workOrderID]?[itemID] = !current
    }

    func isItemCompleted(_ item: ChecklistItem, in workOrderID: UUID) -> Bool {
        checklistCompletions[workOrderID]?[item.id] ?? item.isCompleted
    }

    // MARK: - Field Notes
    func upsertNote(workOrderID: UUID, itemID: UUID, text: String) {
        if fieldNotes[workOrderID] == nil { fieldNotes[workOrderID] = [:] }
        let note = FieldNote(
            id: fieldNotes[workOrderID]?[itemID]?.id ?? UUID(),
            checklistItemID: itemID,
            text: text,
            createdAt: Date()
        )
        fieldNotes[workOrderID]?[itemID] = note
    }

    // MARK: - Photos
    func addPhoto(_ photo: PhotoAttachment, to workOrderID: UUID) {
        if photoAttachments[workOrderID] == nil { photoAttachments[workOrderID] = [] }
        photoAttachments[workOrderID]?.append(photo)
    }

    func removePhoto(id: UUID, from workOrderID: UUID) {
        photoAttachments[workOrderID]?.removeAll { $0.id == id }
    }

    // MARK: - Submit
    func submitReport(for workOrder: WorkOrder) async {
        guard let user = loggedInUser else { return }
        submissionStatus = .sending

        let items = workOrder.checklist.map {
            ReportChecklistItem(
                id: $0.id,
                text: $0.text,
                isCompleted: isItemCompleted($0, in: workOrder.id)
            )
        }
        let notes = Array((fieldNotes[workOrder.id] ?? [:]).values)
        let photos = photoAttachments[workOrder.id] ?? []

        let report = WorkOrderReport(
            workOrderID: workOrder.id,
            technicianID: user.id,
            technicianName: user.name,
            submittedAt: Date(),
            checklistItems: items,
            fieldNotes: notes,
            photos: photos
        )

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601
            _ = try encoder.encode(report)
            try await Task.sleep(for: .seconds(0.5))
            submittedWorkOrders.insert(workOrder.id)
            submissionStatus = .success
        } catch {
            submissionStatus = .failure(error.localizedDescription)
        }
    }
}

