//
//  AdminKnowledgeGraphIndex+Fields.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La scheda di un'entità nel dettaglio: le righe "titolo → valore" (solo quelle presenti) e i
//  testi lunghi (descrizione, cause, passi di risoluzione, attività).
//

import Foundation

extension AdminKnowledgeGraphIndex {
    private typealias K = AdminKnowledgeGraphKey

    func fields(of ref: Ref) -> [AdminAssetField] {
        let pairs: [(String, String?)]
        switch ref.kind {
        case .asset:
            guard let asset = assets[ref.key] else { return [] }
            pairs = [
                (String(localized: "Type"), asset.typeLabel), (String(localized: "Zone"), asset.zone),
                (String(localized: "Status"), asset.statusLabel), (String(localized: "Manufacturer"), asset.manufacturer),
                (String(localized: "Model"), asset.model), (String(localized: "Serial number"), asset.serialNumber),
                (String(localized: "Power"), asset.powerKw.map { "\($0.formatted()) kW" }),
                (String(localized: "Drive"), Self.line([asset.driveTag, asset.driveType])),
                (String(localized: "Plant"), plantName(asset.plantId)),
            ]
        case .alarm:
            guard let alarm = alarms[ref.key] else { return [] }
            pairs = [
                (String(localized: "Asset"), alarm.assetTag), (String(localized: "Category"), K.humanized(alarm.category)),
                (String(localized: "Zone"), alarm.zone), (String(localized: "HMI page"), alarm.hmiPage),
                (String(localized: "Status"), K.humanized(alarm.status)),
                (String(localized: "Confidence"), alarm.confidence.map { $0.formatted(.percent.precision(.fractionLength(0))) }),
            ]
        case .maintenancePlan:
            guard let plan = plans[ref.key] else { return [] }
            pairs = [
                (String(localized: "Frequency"), K.humanized(plan.frequency)),
                (String(localized: "Every"), plan.frequencyHours.map { String(localized: "\($0.formatted()) h") }),
                (String(localized: "Estimated duration"), plan.estimatedDurationMin.map { String(localized: "\($0) min") }),
                (String(localized: "Asset"), plan.assetTag), (String(localized: "Category"), K.humanized(plan.category)),
                (String(localized: "Zone"), plan.zone),
                (String(localized: "Last done"), Self.day(plan.lastDoneAt)), (String(localized: "Next due"), Self.day(plan.nextDueAt)),
                (String(localized: "Status"), K.humanized(plan.status)), (String(localized: "Plant"), plantName(plan.plantId)),
            ]
        case .sparePart:
            guard let part = parts[ref.key] else { return [] }
            pairs = [
                (String(localized: "Code"), part.code.isEmpty ? nil : part.code), (String(localized: "Part number"), part.partNumber),
                (String(localized: "Category"), part.category?.localized), (String(localized: "Manufacturer"), part.manufacturer),
                (String(localized: "Stock"), part.nonStock ? String(localized: "Non-stock item") : "\(part.stockQuantity)\(part.unit.map { " \($0)" } ?? "")"),
                (String(localized: "Minimum"), part.minQuantity.map(String.init)), (String(localized: "Location"), part.location),
                (String(localized: "Status"), part.status?.localized), (String(localized: "Plant"), plantName(part.plantId)),
            ]
        case .workOrder:
            guard let order = workOrders[ref.key] else { return [] }
            pairs = [
                (String(localized: "Status"), K.humanized(order.status)), (String(localized: "Priority"), K.humanized(order.priority)),
                (String(localized: "Type"), K.humanized(order.type)), (String(localized: "Category"), K.humanized(order.category)),
                (String(localized: "Asset"), order.assetTag), (String(localized: "Alarm"), order.alarmCode),
                (String(localized: "Zone"), order.zone), (String(localized: "Due"), Self.day(order.dueDate)),
                (String(localized: "Completed"), Self.day(order.completedAt)), (String(localized: "Created"), Self.day(order.createdAt)),
                (String(localized: "Plant"), plantName(order.plantId)),
            ]
        case .document:
            guard let document = documents[ref.key] else { return [] }
            pairs = [
                (String(localized: "Source"), K.humanized(document.sourceType)), (String(localized: "File"), document.fileName),
                (String(localized: "Size"), document.sizeBytes.map { Int64($0).formatted(.byteCount(style: .file)) }),
                (String(localized: "Pages"), document.pageCount.map(String.init)), (String(localized: "Language"), document.language),
                (String(localized: "Ingestion"), K.humanized(document.ingestionState)),
                (String(localized: "Extraction"), K.humanized(document.extractionState)),
                (String(localized: "Tags"), document.tags.isEmpty ? nil : document.tags.joined(separator: ", ")),
                (String(localized: "Updated"), Self.day(document.updatedAt ?? document.createdAt)),
            ]
        case .plant:
            guard let plant = plants[ref.key] else { return [] }
            pairs = [(String(localized: "Code"), plant.code), (String(localized: "Location"), plant.location)]
        }
        return pairs.compactMap { title, value in
            guard let value, !value.isEmpty else { return nil }
            return AdminAssetField(title: title, value: value)
        }
    }

    func texts(of ref: Ref) -> [AdminKnowledgeGraphTextBlock] {
        let blocks: [(String, String, [String])]
        switch ref.kind {
        case .asset:
            let asset = assets[ref.key]
            blocks = [(String(localized: "Description"), "text.alignleft", [asset?.description].compactMap { $0 }),
                      (String(localized: "Notes"), "note.text", [asset?.notes].compactMap { $0 })]
        case .alarm:
            let alarm = alarms[ref.key]
            blocks = [(String(localized: "Description"), "text.alignleft", [alarm?.description].compactMap { $0 }),
                      (String(localized: "Typical causes"), "questionmark.circle", alarm?.typicalCauses ?? []),
                      (String(localized: "Resolution steps"), "list.number", alarm?.resolutionSteps ?? [])]
        case .maintenancePlan:
            let plan = plans[ref.key]
            blocks = [(String(localized: "Description"), "text.alignleft", [plan?.description].compactMap { $0 }),
                      (String(localized: "Tasks"), "checklist", plan?.tasks ?? [])]
        case .sparePart:
            blocks = [(String(localized: "Description"), "text.alignleft", [parts[ref.key]?.description].compactMap { $0 })]
        case .workOrder:
            blocks = [(String(localized: "Description"), "text.alignleft", [workOrders[ref.key]?.description].compactMap { $0 })]
        case .document:
            let document = documents[ref.key]
            blocks = [(String(localized: "Description"), "text.alignleft", [document?.description].compactMap { $0 }),
                      (String(localized: "Last error"), "exclamationmark.triangle", [document?.lastError].compactMap { $0 })]
        case .plant:
            blocks = []
        }
        return blocks.filter { !$0.2.isEmpty }.map { AdminKnowledgeGraphTextBlock(title: $0.0, systemImage: $0.1, lines: $0.2) }
    }

    private func plantName(_ plantId: String?) -> String? {
        guard let plantId else { return nil }
        return AdminKnowledgeGraphKey.normalized(plantId).flatMap { plants[$0]?.name } ?? plantId
    }

    private static func day(_ date: Date?) -> String? { date?.formatted(date: .abbreviated, time: .omitted) }
}
