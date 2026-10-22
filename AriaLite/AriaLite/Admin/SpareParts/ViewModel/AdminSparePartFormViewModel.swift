//
//  AdminSparePartFormViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il modulo di un ricambio: nuovo (POST /v1/spare-parts, nello stabilimento attivo) o modifica
//  (PATCH con i soli campi cambiati; un campo svuotato si manda come null). I campi sono testo come
//  li scrive l'utente: numeri e liste si leggono e si controllano qui, al salvataggio.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminSparePartFormViewModel: Identifiable {
    enum Mode {
        case create
        case edit(AdminSparePart)
    }

    let mode: Mode
    let owner: AdminSparePartsViewModel
    /// Il ricambio salvato, per chi ha aperto il modulo (il dettaglio).
    private let onSaved: ((AdminSparePart) -> Void)?

    // MARK: - Campi

    var code = ""
    var name = ""
    var category: AdminSparePartCategory?
    var status = AdminSparePartStatus.newPartDefault
    var description = ""
    var manufacturer = ""
    var partNumber = ""
    /// Tag degli asset separati da virgole o a capo.
    var assetTags = ""
    var stockQuantity = "0"
    var minQuantity = ""
    var unit = ""
    var unitPrice = ""
    var location = ""
    var barcode = ""
    var nonStock = false
    var vendorId: String?

    private(set) var isSaving = false
    private(set) var errorMessage: String?
    /// Il prezzo come era scritto all'apertura: riletto dal testo potrebbe non tornare identico al centesimo.
    private var originalPriceText = ""

    init(mode: Mode, owner: AdminSparePartsViewModel, onSaved: ((AdminSparePart) -> Void)? = nil) {
        self.mode = mode
        self.owner = owner
        self.onSaved = onSaved
        if case .edit(let part) = mode { fill(from: part) }
    }

    private func fill(from part: AdminSparePart) {
        code = part.code
        name = part.name
        category = part.category
        status = part.status ?? .newPartDefault
        description = part.description ?? ""
        manufacturer = part.manufacturer ?? ""
        partNumber = part.partNumber ?? ""
        assetTags = part.compatibleAssetTags.joined(separator: ", ")
        stockQuantity = "\(part.stockQuantity)"
        minQuantity = part.minQuantity.map { "\($0)" } ?? ""
        unit = part.unit ?? ""
        unitPrice = part.unitPrice.map(Self.priceText) ?? ""
        originalPriceText = unitPrice
        location = part.location ?? ""
        barcode = part.barcode ?? ""
        nonStock = part.nonStock
        vendorId = part.vendorId
    }

    // MARK: - Presentazione

    var isEditing: Bool { if case .edit = mode { true } else { false } }

    var title: String { isEditing ? String(localized: "Edit spare part") : String(localized: "New spare part") }

    var vendors: AdminSparePartVendorsViewModel { owner.vendors }

    /// Le categorie da scegliere; quella sconosciuta arrivata dal server resta solo se è quella del ricambio.
    var categoryChoices: [AdminSparePartCategory] {
        category == .unknown ? AdminSparePartCategory.selectable + [.unknown] : AdminSparePartCategory.selectable
    }

    var statusChoices: [AdminSparePartStatus] {
        status == .unknown ? AdminSparePartStatus.selectable + [.unknown] : AdminSparePartStatus.selectable
    }

    /// Il fornitore scelto non è nell'elenco (fornitore eliminato o di un altro stabilimento): resta scelto.
    var hasUnlistedVendor: Bool {
        guard let vendorId else { return false }
        return !vendors.vendors.contains { $0.id == vendorId }
    }

    var canSave: Bool { !isSaving && !trimmed(code).isEmpty && !trimmed(name).isEmpty }

    /// Qualcosa è cambiato: chiudere con un trascinamento perderebbe le modifiche.
    var hasChanges: Bool {
        switch mode {
        case .create: !trimmed(code).isEmpty || !trimmed(name).isEmpty
        // Un campo non valido è comunque una modifica da non perdere.
        case .edit(let part): (try? values()).map { !patch(from: part, $0).isEmpty } ?? true
        }
    }

    func loadVendors() async { await vendors.loadIfNeeded() }

    // MARK: - Lettura dei campi

    private struct Values {
        var code: String
        var name: String
        var description: String?
        var manufacturer: String?
        var partNumber: String?
        var assetTags: [String]
        var stockQuantity: Int
        var minQuantity: Int?
        var unit: String?
        var unitPrice: Double?
        var location: String?
        var barcode: String?
    }

    private struct InvalidField: Error {
        let message: String
    }

    private func values() throws -> Values {
        let code = trimmed(code), name = trimmed(name)
        guard !code.isEmpty else { throw InvalidField(message: String(localized: "Code is required.")) }
        guard !name.isEmpty else { throw InvalidField(message: String(localized: "Name is required.")) }
        let stock = trimmed(stockQuantity)
        guard stock.isEmpty || Int(stock).map({ $0 >= 0 }) == true else {
            throw InvalidField(message: String(localized: "Stock quantity must be a whole number, 0 or more."))
        }
        let minimum = trimmed(minQuantity)
        guard minimum.isEmpty || Int(minimum).map({ $0 >= 0 }) == true else {
            throw InvalidField(message: String(localized: "Minimum quantity must be a whole number, 0 or more."))
        }
        let price = trimmed(unitPrice)
        let priceValue = Self.parseDecimal(price)
        guard price.isEmpty || priceValue.map({ $0 >= 0 }) == true else {
            throw InvalidField(message: String(localized: "Unit price must be a number, 0 or more."))
        }
        return Values(code: code, name: name, description: optional(description), manufacturer: optional(manufacturer),
                      partNumber: optional(partNumber), assetTags: Self.tags(from: assetTags),
                      stockQuantity: Int(stock) ?? 0, minQuantity: Int(minimum), unit: optional(unit),
                      unitPrice: price.isEmpty ? nil : priceValue, location: optional(location),
                      barcode: optional(barcode))
    }

    private func trimmed(_ text: String) -> String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func optional(_ text: String) -> String? {
        let value = trimmed(text)
        return value.isEmpty ? nil : value
    }

    /// Virgola o punto come separatore decimale.
    static func parseDecimal(_ text: String) -> Double? {
        Double(text.replacingOccurrences(of: ",", with: ".")).flatMap { $0.isFinite ? $0 : nil }
    }

    static func priceText(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...4)).grouping(.never))
    }

    /// "AB-1, AB-2\nAB-3" → ["AB-1", "AB-2", "AB-3"], senza doppioni.
    static func tags(from text: String) -> [String] {
        var seen = Set<String>()
        return text.split(whereSeparator: { $0 == "," || $0.isNewline })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    // MARK: - Body

    private func createBody(_ values: Values, plantId: String) -> AdminSparePartCreate {
        AdminSparePartCreate(
            code: values.code, name: values.name,
            category: category.flatMap { $0 == .unknown ? nil : $0.rawValue },
            status: status == .unknown ? nil : status.rawValue,
            description: values.description, manufacturer: values.manufacturer, partNumber: values.partNumber,
            compatibleAssetTags: values.assetTags.isEmpty ? nil : values.assetTags,
            stockQuantity: values.stockQuantity, minQuantity: values.minQuantity, unit: values.unit,
            unitPrice: values.unitPrice, location: values.location, barcode: values.barcode,
            nonStock: nonStock, plantId: plantId, vendorId: vendorId
        )
    }

    /// Solo i campi diversi dal ricambio di partenza. Una categoria o uno stato sconosciuti non si rimandano.
    private func patch(from part: AdminSparePart, _ values: Values) -> AdminSparePartUpdate {
        var update = AdminSparePartUpdate()
        func text(_ field: AdminSparePartUpdate.Field, _ old: String?, _ new: String?) {
            if old != new { update.fields[field] = new.map(AriaJSON.string) ?? .null }
        }
        text(.code, part.code, values.code)
        text(.name, part.name, values.name)
        text(.description, part.description, values.description)
        text(.manufacturer, part.manufacturer, values.manufacturer)
        text(.partNumber, part.partNumber, values.partNumber)
        text(.unit, part.unit, values.unit)
        text(.location, part.location, values.location)
        text(.barcode, part.barcode, values.barcode)
        text(.vendorId, part.vendorId, vendorId)
        if category != part.category, category != .unknown {
            update.fields[.category] = category.map { .string($0.rawValue) } ?? .null
        }
        if status != (part.status ?? .newPartDefault), status != .unknown {
            update.fields[.status] = .string(status.rawValue)
        }
        if values.assetTags != part.compatibleAssetTags {
            update.fields[.compatibleAssetTags] = .array(values.assetTags.map(AriaJSON.string))
        }
        if values.stockQuantity != part.stockQuantity {
            update.fields[.stockQuantity] = .number(Double(values.stockQuantity))
        }
        if values.minQuantity != part.minQuantity {
            update.fields[.minQuantity] = values.minQuantity.map { .number(Double($0)) } ?? .null
        }
        if unitPrice != originalPriceText, values.unitPrice != part.unitPrice {
            update.fields[.unitPrice] = values.unitPrice.map(AriaJSON.number) ?? .null
        }
        if nonStock != part.nonStock { update.fields[.nonStock] = .bool(nonStock) }
        return update
    }

    // MARK: - Salvataggio

    /// `true` se salvato (o niente da salvare): il modulo si può chiudere.
    func save() async -> Bool {
        guard !isSaving else { return false }
        errorMessage = nil
        let values: Values
        do { values = try self.values() } catch {
            errorMessage = (error as? InvalidField)?.message ?? error.localizedDescription
            return false
        }
        let api = AdminSparePartsAPI(api: owner.backend.api)
        isSaving = true
        defer { isSaving = false }
        do {
            switch mode {
            case .create:
                guard let plantId = owner.backend.activePlantId else {
                    errorMessage = String(localized: "Select a plant before adding spare parts.")
                    return false
                }
                let created = try await api.create(createBody(values, plantId: plantId))
                owner.didCreate(created)
                onSaved?(created)
            case .edit(let part):
                let update = patch(from: part, values)
                guard !update.isEmpty else { return true }
                let saved = try await api.update(id: part.id, update)
                owner.didSave(saved)
                onSaved?(saved)
            }
            return true
        } catch {
            if let failure = AdminSparePartsFailure.from(error, action: .write, backend: owner.backend) {
                errorMessage = failure.message
            }
            return false
        }
    }
}
