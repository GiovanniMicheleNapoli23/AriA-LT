//
//  AdminExtractionItem+Fields.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I campi principali che il dettaglio permette di correggere, per ciascun tipo, con le chiavi di
//  AssetUpdate, AlarmUpdate, MaintenancePlanUpdate e SparePartUpdate.
//

import Foundation

extension AdminExtractionItem {
    var editableFields: [AdminExtractionField] {
        switch self {
        case .asset(let a): Self.fields(asset: a)
        case .alarm(let a): Self.fields(alarm: a)
        case .plan(let p): Self.fields(plan: p)
        case .part(let p): Self.fields(part: p)
        }
    }

    private static func fields(asset a: AdminAsset) -> [AdminExtractionField] {
        let types = AdminAssetType.allCases.map { AdminExtractionChoice(value: $0.rawValue, label: $0.label) }
        return [
            .init(key: "name", label: String(localized: "Name"), editor: .text, value: a.name, isRequired: true),
            .init(key: "asset_type", label: String(localized: "Type"), editor: .choice(with(types, current: a.assetType, label: AdminAssetType.label(for:))),
                  value: a.assetType ?? "", isRequired: true),
            .init(key: "zone", label: String(localized: "Zone"), editor: .text, value: a.zone ?? ""),
            .init(key: "manufacturer", label: String(localized: "Manufacturer"), editor: .text, value: a.manufacturer ?? ""),
            .init(key: "model", label: String(localized: "Model"), editor: .text, value: a.model ?? ""),
            .init(key: "serial_number", label: String(localized: "Serial number"), editor: .text, value: a.serialNumber ?? ""),
            .init(key: "power_kw", label: String(localized: "Power (kW)"), editor: .decimal, value: AdminExtractionField.text(a.powerKw)),
            .init(key: "description", label: String(localized: "Description"), editor: .multiline, value: a.description ?? ""),
            .init(key: "notes", label: String(localized: "Notes"), editor: .multiline, value: a.notes ?? ""),
        ]
    }

    private static func fields(alarm a: AdminExtractionAlarm) -> [AdminExtractionField] {
        [
            .init(key: "code", label: String(localized: "Code"), editor: .text, value: a.code, isRequired: true),
            .init(key: "description", label: String(localized: "Description"), editor: .multiline, value: a.description ?? "", isRequired: true),
            .init(key: "asset_tag", label: String(localized: "Asset tag"), editor: .text, value: a.assetTag ?? ""),
            .init(key: "category", label: String(localized: "Category"), editor: .text, value: a.category ?? ""),
            .init(key: "zone", label: String(localized: "Zone"), editor: .text, value: a.zone ?? ""),
            .init(key: "hmi_page", label: String(localized: "HMI page"), editor: .text, value: a.hmiPage ?? ""),
            .init(key: "typical_causes", label: String(localized: "Typical causes"), editor: .list, value: a.typicalCauses.joined(separator: "\n")),
            .init(key: "resolution_steps", label: String(localized: "Resolution steps"), editor: .list, value: a.resolutionSteps.joined(separator: "\n")),
        ]
    }

    private static func fields(plan p: AdminExtractionMaintenancePlan) -> [AdminExtractionField] {
        let frequencies = AdminExtractionPlanFrequency.allCases.map { AdminExtractionChoice(value: $0.rawValue, label: $0.label) }
        return [
            .init(key: "name", label: String(localized: "Name"), editor: .text, value: p.name, isRequired: true),
            .init(key: "frequency", label: String(localized: "Frequency"),
                  editor: .choice(with(frequencies, current: p.frequency, label: AdminExtractionPlanFrequency.label(for:))),
                  value: p.frequency ?? "", isRequired: true),
            .init(key: "asset_tag", label: String(localized: "Asset tag"), editor: .text, value: p.assetTag ?? ""),
            .init(key: "category", label: String(localized: "Category"), editor: .text, value: p.category ?? ""),
            .init(key: "zone", label: String(localized: "Zone"), editor: .text, value: p.zone ?? ""),
            .init(key: "estimated_duration_min", label: String(localized: "Duration (min)"), editor: .integer,
                  value: p.estimatedDurationMin.map(String.init) ?? ""),
            .init(key: "description", label: String(localized: "Description"), editor: .multiline, value: p.description ?? ""),
            .init(key: "tasks", label: String(localized: "Tasks"), editor: .list, value: p.tasks.joined(separator: "\n")),
            .init(key: "spare_parts", label: String(localized: "Spare parts"), editor: .list, value: p.spareParts.joined(separator: "\n")),
        ]
    }

    private static func fields(part p: AdminSparePart) -> [AdminExtractionField] {
        let categories = AdminSparePartCategory.selectable.map { AdminExtractionChoice(value: $0.rawValue, label: $0.localized) }
        let category = p.category.flatMap { $0 == .unknown ? nil : $0.rawValue } ?? ""
        return [
            .init(key: "code", label: String(localized: "Code"), editor: .text, value: p.code, isRequired: true),
            .init(key: "name", label: String(localized: "Name"), editor: .text, value: p.name, isRequired: true),
            .init(key: "category", label: String(localized: "Category"), editor: .choice(categories), value: category),
            .init(key: "manufacturer", label: String(localized: "Manufacturer"), editor: .text, value: p.manufacturer ?? ""),
            .init(key: "part_number", label: String(localized: "Part number"), editor: .text, value: p.partNumber ?? ""),
            .init(key: "unit", label: String(localized: "Unit"), editor: .text, value: p.unit ?? ""),
            .init(key: "unit_price", label: String(localized: "Unit price"), editor: .decimal, value: AdminExtractionField.text(p.unitPrice)),
            .init(key: "min_quantity", label: String(localized: "Minimum stock"), editor: .integer, value: p.minQuantity.map(String.init) ?? ""),
            .init(key: "location", label: String(localized: "Location"), editor: .text, value: p.location ?? ""),
            .init(key: "description", label: String(localized: "Description"), editor: .multiline, value: p.description ?? ""),
            .init(key: "compatible_asset_tags", label: String(localized: "Compatible assets"), editor: .list,
                  value: p.compatibleAssetTags.joined(separator: "\n")),
        ]
    }

    /// Le scelte note più il valore attuale, se il backend ne ha uno nuovo.
    private static func with(_ choices: [AdminExtractionChoice], current: String?, label: (String) -> String) -> [AdminExtractionChoice] {
        guard let current, !choices.contains(where: { $0.value == current }) else { return choices }
        return choices + [AdminExtractionChoice(value: current, label: label(current))]
    }
}
