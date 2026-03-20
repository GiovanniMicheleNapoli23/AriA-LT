//
//  Models.swift
//  AriaLite
//
//  Created by Giovanni Michele on 19/03/26.
//

import Foundation


struct PhotoAttachment: Identifiable, Codable {
    let id: UUID
    let filename: String
    var base64Data: String?
    let capturedAt: Date
    var checklistItemID: UUID?  
}


// Nota testuale aggiunta dal tecnico su un singolo ChecklistItem
struct FieldNote: Identifiable, Codable {
    let id: UUID
    let checklistItemID: UUID
    var text: String
    let createdAt: Date
}

struct ChecklistItem: Identifiable, Codable {
    let id: UUID
    var text: String
    var description: String?   
    var isCompleted: Bool
}


struct ProcedureDocument: Identifiable, Codable {
    let id: UUID
    let title: String
    let notes: String?
    let photos: [String]
}

struct WorkOrder: Identifiable, Codable {
    let id: UUID
    let assignedUserID: UUID
    let title: String
    var checklist: [ChecklistItem]
    let documents: [ProcedureDocument]
}

// Payload finale inviato al server
struct WorkOrderReport: Codable {
    let workOrderID: UUID
    let technicianID: UUID
    let technicianName: String
    let submittedAt: Date
    let checklistItems: [ReportChecklistItem]
    let fieldNotes: [FieldNote]
    let photos: [PhotoAttachment]
}

struct ReportChecklistItem: Codable {
    let id: UUID
    let text: String
    let isCompleted: Bool
}

// SICUREZZA: password mai in chiaro nel modello
struct User: Identifiable, Equatable, Codable {
    let id: UUID
    let username: String
    let name: String
    // password gestita solo durante autenticazione, non persiste nel modello
}

enum SubmissionStatus: Equatable {
    case idle
    case sending
    case success
    case failure(String)
}
