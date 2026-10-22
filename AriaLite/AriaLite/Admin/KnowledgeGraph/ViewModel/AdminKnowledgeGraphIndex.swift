//
//  AdminKnowledgeGraphIndex.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il grafo ricavato dalle liste: ogni entità diventa un nodo, i campi che si riferiscono ad altre
//  (asset_tag, alarm_code, maintenance_plan_id, compatible_asset_tags, plant_id, tag dei documenti)
//  diventano archi. Si costruisce una volta per caricamento; le domande dopo sono dizionari.
//

import Foundation

struct AdminKnowledgeGraphIndex {
    typealias Kind = AdminKnowledgeGraphKind
    typealias Ref = AdminKnowledgeGraphRef
    /// chiave di partenza → chiavi collegate.
    typealias Edges = [String: [String]]

    let data: AdminKnowledgeGraphData

    var assets: [String: AdminAsset] = [:]
    var alarms: [String: AdminKnowledgeGraphAlarm] = [:]
    var plans: [String: AdminKnowledgeGraphMaintenancePlan] = [:]
    var parts: [String: AdminSparePart] = [:]
    var workOrders: [String: AdminKnowledgeGraphWorkOrder] = [:]
    var documents: [String: AdminKnowledgeGraphDocument] = [:]
    var plants: [String: AriaPlant] = [:]

    var alarmsByAsset: Edges = [:]
    var alarmsByCode: Edges = [:]
    var plansByAsset: Edges = [:]
    var partsByAsset: Edges = [:]
    var workOrdersByAsset: Edges = [:]
    var documentsByAsset: Edges = [:]
    var workOrdersByAlarmCode: Edges = [:]
    var workOrdersByPlan: Edges = [:]
    var partsByPlan: Edges = [:]
    var plansByPart: Edges = [:]
    /// Per tipo: stabilimento → entità che vi appartengono.
    var byPlant: [Kind: Edges] = [:]

    /// I nodi già pronti, per tipo (ordinati) e per riferimento.
    private(set) var nodesByKind: [Kind: [AdminKnowledgeGraphNode]] = [:]
    private(set) var nodeByRef: [Ref: AdminKnowledgeGraphNode] = [:]
    /// Quanti archi risolti (entrambe le estremità presenti) ci sono nel grafo.
    private(set) var linkCount = 0

    init(data: AdminKnowledgeGraphData = .init()) {
        self.data = data
        index(data)
        buildNodes()
    }

    // MARK: Costruzione

    private mutating func index(_ data: AdminKnowledgeGraphData) {
        typealias K = AdminKnowledgeGraphKey
        assets = Self.keyed(data.assets, K.asset)
        alarms = Self.keyed(data.alarms, K.alarm)
        plans = Self.keyed(data.plans, K.plan)
        parts = Self.keyed(data.parts, K.part)
        workOrders = Self.keyed(data.workOrders, K.workOrder)
        documents = Self.keyed(data.documents.filter { !$0.isDeleted }, K.document)
        plants = Self.keyed(data.plants, K.plant)

        for (key, alarm) in alarms {
            if Self.link(&alarmsByAsset, from: alarm.assetTag, to: key, ifIn: assets) { linkCount += 1 }
            Self.add(&alarmsByCode, K.normalized(alarm.code), key)
        }
        // Ricambi richiamabili per codice, id, codice costruttore o nome (i piani li scrivono a mano).
        var partByReference: [String: String] = [:]
        for (key, part) in parts {
            for reference in [part.code, part.partNumber, part.id, part.name] {
                if let normalized = K.normalized(reference), partByReference[normalized] == nil { partByReference[normalized] = key }
            }
            for tag in Set(part.compatibleAssetTags.compactMap(K.normalized)) {
                if Self.link(&partsByAsset, from: tag, to: key, ifIn: assets) { linkCount += 1 }
            }
            plantLink(.sparePart, part.plantId, key)
        }
        for (key, plan) in plans {
            for tag in plan.allAssetTags { if Self.link(&plansByAsset, from: tag, to: key, ifIn: assets) { linkCount += 1 } }
            for reference in plan.spareParts {
                guard let partKey = K.normalized(reference).flatMap({ partByReference[$0] }),
                      !(partsByPlan[key]?.contains(partKey) ?? false) else { continue }
                Self.add(&partsByPlan, key, partKey)
                Self.add(&plansByPart, partKey, key)
                linkCount += 1
            }
            plantLink(.maintenancePlan, plan.plantId, key)
        }
        for (key, order) in workOrders {
            if Self.link(&workOrdersByAsset, from: order.assetTag, to: key, ifIn: assets) { linkCount += 1 }
            if let code = K.normalized(order.alarmCode) {
                Self.add(&workOrdersByAlarmCode, code, key)
                if alarmsByCode[code] != nil { linkCount += 1 }
            }
            if Self.link(&workOrdersByPlan, from: order.maintenancePlanId, to: key, ifIn: plans) { linkCount += 1 }
            plantLink(.workOrder, order.plantId, key)
        }
        for (key, document) in documents {
            for tag in Set(document.tags.compactMap(K.normalized)) {
                if Self.link(&documentsByAsset, from: tag, to: key, ifIn: assets) { linkCount += 1 }
            }
        }
        for (key, asset) in assets { plantLink(.asset, asset.plantId, key) }
    }

    /// Un arco `from → to`, solo se `from` esiste davvero fra le entità `targets` (`true` = arco aggiunto).
    private static func link<T>(_ edges: inout Edges, from raw: String?, to key: String, ifIn targets: [String: T]) -> Bool {
        guard let from = AdminKnowledgeGraphKey.normalized(raw), targets[from] != nil else { return false }
        add(&edges, from, key)
        return true
    }

    private mutating func plantLink(_ kind: Kind, _ plantId: String?, _ key: String) {
        guard let plant = AdminKnowledgeGraphKey.normalized(plantId), plants[plant] != nil else { return }
        Self.add(&byPlant[kind, default: [:]], plant, key)
        linkCount += 1
    }

    private static func add(_ edges: inout Edges, _ from: String?, _ to: String) {
        guard let from else { return }
        edges[from, default: []].append(to)
    }

    private static func keyed<T>(_ items: [T], _ key: (T) -> String) -> [String: T] {
        Dictionary(items.map { (key($0), $0) }, uniquingKeysWith: { first, _ in first })
    }

    private mutating func buildNodes() {
        var all: [Kind: [AdminKnowledgeGraphNode]] = [:]
        all[.asset] = assets.map { node(asset: $1, key: $0) }
        all[.alarm] = alarms.map { node(alarm: $1, key: $0) }
        all[.maintenancePlan] = plans.map { node(plan: $1, key: $0) }
        all[.sparePart] = parts.map { node(part: $1, key: $0) }
        all[.workOrder] = workOrders.map { node(workOrder: $1, key: $0) }
        all[.document] = documents.map { node(document: $1, key: $0) }
        all[.plant] = plants.map { node(plant: $1, key: $0) }
        for (kind, nodes) in all {
            nodesByKind[kind] = sorted(nodes, of: kind)
            for node in nodes { nodeByRef[node.ref] = node }
        }
    }

    /// Ordini e documenti dal più recente; il resto in ordine alfabetico.
    private func sorted(_ nodes: [AdminKnowledgeGraphNode], of kind: Kind) -> [AdminKnowledgeGraphNode] {
        switch kind {
        case .workOrder:
            nodes.sorted { (workOrders[$0.ref.key]?.createdAt ?? .distantPast) > (workOrders[$1.ref.key]?.createdAt ?? .distantPast) }
        case .document:
            nodes.sorted { (documents[$0.ref.key]?.updatedAt ?? .distantPast) > (documents[$1.ref.key]?.updatedAt ?? .distantPast) }
        default:
            nodes.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        }
    }

    // MARK: Domande

    func nodes(of kind: Kind) -> [AdminKnowledgeGraphNode] { nodesByKind[kind] ?? [] }

    func node(for ref: Ref) -> AdminKnowledgeGraphNode? { nodeByRef[ref] }

    var entityCount: Int { nodeByRef.count }

    /// Le entità collegate a `ref`, raggruppate per tipo nell'ordine della panoramica; gruppi vuoti esclusi.
    func relations(of ref: Ref) -> [AdminKnowledgeGraphRelationGroup] {
        var keys: [Kind: [String]] = [:]
        let key = ref.key
        typealias K = AdminKnowledgeGraphKey
        switch ref.kind {
        case .asset:
            keys[.plant] = assets[key].flatMap { K.normalized($0.plantId) }.map { [$0] }
            keys[.alarm] = alarmsByAsset[key]
            keys[.maintenancePlan] = plansByAsset[key]
            keys[.sparePart] = partsByAsset[key]
            keys[.workOrder] = workOrdersByAsset[key]
            keys[.document] = documentsByAsset[key]
        case .alarm:
            guard let alarm = alarms[key] else { break }
            keys[.asset] = K.normalized(alarm.assetTag).map { [$0] }
            keys[.workOrder] = K.normalized(alarm.code).flatMap { workOrdersByAlarmCode[$0] }
        case .maintenancePlan:
            guard let plan = plans[key] else { break }
            keys[.plant] = K.normalized(plan.plantId).map { [$0] }
            keys[.asset] = plan.allAssetTags.compactMap(K.normalized)
            keys[.sparePart] = partsByPlan[key]
            keys[.workOrder] = workOrdersByPlan[key]
        case .sparePart:
            guard let part = parts[key] else { break }
            keys[.plant] = K.normalized(part.plantId).map { [$0] }
            keys[.asset] = Array(Set(part.compatibleAssetTags.compactMap(K.normalized)))
            keys[.maintenancePlan] = plansByPart[key]
        case .workOrder:
            guard let order = workOrders[key] else { break }
            keys[.plant] = K.normalized(order.plantId).map { [$0] }
            keys[.asset] = K.normalized(order.assetTag).map { [$0] }
            keys[.alarm] = alarmKeys(code: order.alarmCode, assetTag: order.assetTag)
            keys[.maintenancePlan] = K.normalized(order.maintenancePlanId).map { [$0] }
        case .document:
            guard let document = documents[key] else { break }
            keys[.asset] = Array(Set(document.tags.compactMap(K.normalized)))
        case .plant:
            for kind in [Kind.asset, .maintenancePlan, .sparePart, .workOrder] { keys[kind] = byPlant[kind]?[key] }
        }
        return Kind.allCases.compactMap { kind in
            let nodes = (keys[kind] ?? []).compactMap { nodeByRef[Ref(kind: kind, key: $0)] }
            return nodes.isEmpty ? nil : AdminKnowledgeGraphRelationGroup(kind: kind, nodes: sorted(nodes, of: kind))
        }
    }

    /// L'allarme di un ordine: a parità di codice, quello dello stesso asset.
    private func alarmKeys(code: String?, assetTag: String?) -> [String]? {
        guard let code = AdminKnowledgeGraphKey.normalized(code), let candidates = alarmsByCode[code] else { return nil }
        let tag = AdminKnowledgeGraphKey.normalized(assetTag)
        let sameAsset = candidates.filter { AdminKnowledgeGraphKey.normalized(alarms[$0]?.assetTag) == tag }
        return sameAsset.isEmpty ? candidates : sameAsset
    }

    /// Le entità più collegate di un tipo: i "nodi centrali" della panoramica.
    func hubs(of kind: Kind, limit: Int) -> [(node: AdminKnowledgeGraphNode, links: Int)] {
        nodes(of: kind)
            .map { node in (node, relations(of: node.ref).reduce(0) { $0 + $1.nodes.count }) }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map { (node: $0.0, links: $0.1) }
    }
}
