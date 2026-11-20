//
//  AriaSidebarSections.swift
//  AriaLite
//
//  Created by Giovanni Michele on 26/10/26.
//
//  Le sezioni della sidebar per tipo di account, raggruppate come nella sidebar della web. Il layout
//  dell'operatore ha Task e Calendario, che il ruolo può togliere; quando la sessione segue il ruolo
//  (`access.appFollowsRole`) anche le sezioni della web che il ruolo concede, con le stesse viste dell'admin.
//

import SwiftUI

struct AriaSidebarItem: Identifiable {
    let title: LocalizedStringResource
    let icon: String
    let target: AriaDestination
    /// Le sezioni che il ruolo deve concedere perché la riga si veda (layout dell'operatore).
    var needs: [AriaSection] = []
    /// Users: la regola del §2 (titolare, o Members con l'app che segue il ruolo); mentre /v1/me non ha risposto si vede.
    var needsUsersEntry = false
    /// Users si offre anche a chi gestisce i ruoli senza vedere le persone: la sua vista Roles è l'ex sezione
    /// Roles & Rights (AriaRights.canOpenRolesAndRights).
    var alsoForRoleManagers = false
    /// Usage: la regola del §2 del contratto Usage (titolare, o membro con il ruolo che la concede e l'app che lo
    /// segue) e i consumi visibili ai clienti (`usageVisible`, dalla config; mentre non ha risposto si vede).
    var needsUsageEntry = false

    func isOffered(by rights: AriaRights, usageVisible: Bool = true) -> Bool {
        let offered = needs.allSatisfy(rights.has)
            && (!needsUsersEntry || AdminUsersRules.entry(rights.access) != .hidden)
            && (!needsUsageEntry || (usageVisible && AdminUsageAccess.mayOpen(rights)))
        return offered || (alsoForRoleManagers && AdminUsersRules.rolesViewOpen(rights))
    }

    var id: AriaDestination { target }
}

struct AriaSidebarGroup: Identifiable {
    /// `nil`: le righe stanno subito sotto "Chat", senza titolo.
    let title: LocalizedStringResource?
    let items: [AriaSidebarItem]

    var id: String { items.first.map { "\($0.target)" } ?? "" }
}

enum AriaSidebarSections {
    /// `usageVisible`: la config dei consumi non ha detto di no (`AriaBackend.usageEntryVisible`).
    static func groups(operatorLayout: Bool, rights: AriaRights, usageVisible: Bool = true) -> [AriaSidebarGroup] {
        // Senza ruolo che lo segua restano Task e Calendario (se il ruolo li concede): come prima dei ruoli.
        let groups = !operatorLayout ? adminGroups : rights.followsRole ? operatorGroups : Array(operatorGroups.prefix(1))
        return groups.compactMap { group in
            let items = group.items.filter { $0.isOffered(by: rights, usageVisible: usageVisible) }
            return items.isEmpty ? nil : AriaSidebarGroup(title: group.title, items: items)
        }
    }

    /// Le destinazioni che la sidebar offre: una sezione tolta dal ruolo a schermata aperta torna alla chat.
    static func destinations(operatorLayout: Bool, rights: AriaRights, usageVisible: Bool = true) -> Set<AriaDestination> {
        Set(groups(operatorLayout: operatorLayout, rights: rights, usageVisible: usageVisible).flatMap { $0.items.map(\.target) })
    }

    private static let operatorGroups: [AriaSidebarGroup] = [
        AriaSidebarGroup(title: nil, items: [
            AriaSidebarItem(title: "Tasks", icon: "checklist", target: .tasks, needs: [.workOrders]),
            AriaSidebarItem(title: "Calendar", icon: "calendar", target: .calendar, needs: [.workOrders]),
        ]),
        // Niente Work Orders: i lavori dell'operatore sono già in Task.
        AriaSidebarGroup(title: "Intelligence", items: [marketplace, crafted]),
        AriaSidebarGroup(title: "Operations", items: [maintenance, taskboard]),
        AriaSidebarGroup(title: "Resources", items: [assets, spareParts, alarms]),
        AriaSidebarGroup(title: "Purchases", items: [vendors]),
        AriaSidebarGroup(title: "Analytics", items: [llmUsage]),
        AriaSidebarGroup(title: "Configuration", items: [
            AriaSidebarItem(title: "Users", icon: "person.2", target: .adminUsers, needs: [.members], needsUsersEntry: true,
                            alsoForRoleManagers: true),
            categories,
        ]),
    ]

    private static let adminGroups: [AriaSidebarGroup] = [
        AriaSidebarGroup(title: "Intelligence", items: [
            AriaSidebarItem(title: "Documents", icon: "doc.text", target: .adminDocuments),
            AriaSidebarItem(title: "Agent Studio", icon: "cpu", target: .adminAgentStudio),
            marketplace,
            AriaSidebarItem(title: "Extraction Review", icon: "text.viewfinder", target: .adminExtractionReview),
            AriaSidebarItem(title: "Learned knowledge", icon: "brain", target: .adminLearnedKnowledge),
            AriaSidebarItem(title: "Scenario analysis", icon: "chart.line.uptrend.xyaxis", target: .adminScenarioAnalysis),
            crafted,
        ]),
        AriaSidebarGroup(title: "Operations", items: [
            AriaSidebarItem(title: "Work Orders", icon: "wrench.and.screwdriver", target: .adminWorkOrders),
            maintenance,
            AriaSidebarItem(title: "Inspections", icon: "checklist.checked", target: .adminInspections),
            taskboard,
        ]),
        AriaSidebarGroup(title: "Resources", items: [assets, spareParts, alarms]),
        AriaSidebarGroup(title: "Purchases", items: [
            AriaSidebarItem(title: "Purchase Orders", icon: "cart", target: .adminPurchaseOrders),
            vendors,
        ]),
        AriaSidebarGroup(title: "Analytics", items: [
            AriaSidebarItem(title: "Reports", icon: "chart.bar.xaxis", target: .adminReports),
            llmUsage,
        ]),
        AriaSidebarGroup(title: "Configuration", items: [
            AriaSidebarItem(title: "Sites", icon: "building.columns", target: .adminPlants),
            categories,
            AriaSidebarItem(title: "Teams", icon: "person.3", target: .adminTeams),
            AriaSidebarItem(title: "Users", icon: "person.2", target: .adminUsers, needsUsersEntry: true,
                            alsoForRoleManagers: true),
        ]),
    ]

    // MARK: Sezioni di entrambi

    private static let marketplace = AriaSidebarItem(title: "Marketplace", icon: "puzzlepiece.extension", target: .adminMarketplace,
                                                     needs: [.marketplace])
    private static let crafted = AriaSidebarItem(title: "Crafted", icon: "sparkles", target: .adminCrafted, needs: [.crafted])
    private static let maintenance = AriaSidebarItem(title: "Maintenance", icon: "calendar.badge.clock", target: .adminMaintenance,
                                                     needs: [.maintenance])
    /// Ogni chiamata della Taskboard è una chiamata sui lavori.
    private static let taskboard = AriaSidebarItem(title: "Taskboard", icon: "rectangle.split.3x1", target: .adminTaskboard,
                                                   needs: [.taskboard, .workOrders])
    private static let assets = AriaSidebarItem(title: "Assets", icon: "gearshape.2", target: .assets, needs: [.assets])
    private static let spareParts = AriaSidebarItem(title: "Spare Parts", icon: "shippingbox", target: .spareParts,
                                                    needs: [.spareParts])
    private static let alarms = AriaSidebarItem(title: "Alarms", icon: "bell.badge", target: .adminAlarms, needs: [.alarms])
    private static let vendors = AriaSidebarItem(title: "Vendors", icon: "building.2", target: .adminVendors, needs: [.vendors])
    /// "LLM Usage" come nella sidebar della web (/settings/usage): crediti del ciclo, dove sono andati e, per i titolari, i controlli.
    private static let llmUsage = AriaSidebarItem(title: "LLM Usage", icon: "chart.pie", target: .adminUsage, needsUsageEntry: true)
    private static let categories = AriaSidebarItem(title: "Categories", icon: "tag", target: .adminCategories,
                                                    needs: [.categories])
}
