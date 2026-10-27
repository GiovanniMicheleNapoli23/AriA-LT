//
//  AriaSidebarSections.swift
//  AriaLite
//
//  Created by Giovanni Michele on 26/10/26.
//
//  Le sezioni della sidebar per tipo di account, raggruppate come nella sidebar della web. L'operatore ha
//  Task e Calendario più una parte delle sezioni della web: le stesse viste dell'admin, dove il server gli
//  risponde 403 la sezione lo dice ("il tuo ruolo non può") invece di sparire.
//

import SwiftUI

struct AriaSidebarItem: Identifiable {
    let title: LocalizedStringResource
    let icon: String
    let target: AriaDestination

    var id: AriaDestination { target }
}

struct AriaSidebarGroup: Identifiable {
    /// `nil`: le righe stanno subito sotto "Chat", senza titolo.
    let title: LocalizedStringResource?
    let items: [AriaSidebarItem]

    var id: String { items.first.map { "\($0.target)" } ?? "" }
}

enum AriaSidebarSections {
    static func groups(for kind: AriaAccountKind) -> [AriaSidebarGroup] {
        switch kind {
        case .operator: operatorGroups
        case .admin: adminGroups
        }
    }

    private static let operatorGroups: [AriaSidebarGroup] = [
        AriaSidebarGroup(title: nil, items: [
            AriaSidebarItem(title: "Tasks", icon: "checklist", target: .tasks),
            AriaSidebarItem(title: "Calendar", icon: "calendar", target: .calendar),
        ]),
        AriaSidebarGroup(title: "Intelligence", items: [marketplace, crafted]),
        // Niente Work Orders: i lavori dell'operatore sono già in Task.
        AriaSidebarGroup(title: "Operations", items: [maintenance, taskboard]),
        AriaSidebarGroup(title: "Resources", items: [assets, spareParts, alarms]),
        AriaSidebarGroup(title: "Purchases", items: [vendors]),
        AriaSidebarGroup(title: "Analytics", items: [llmUsage]),
        AriaSidebarGroup(title: "Configuration", items: [categories]),
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
            AriaSidebarItem(title: "Plants", icon: "building.columns", target: .adminPlants),
            categories,
            AriaSidebarItem(title: "Teams", icon: "person.3", target: .adminTeams),
            AriaSidebarItem(title: "Members", icon: "person.2", target: .adminMembers),
            AriaSidebarItem(title: "Mobile Users", icon: "iphone.gen3", target: .adminMobileUsers),
        ]),
    ]

    // MARK: Sezioni di entrambi

    private static let marketplace = AriaSidebarItem(title: "Marketplace", icon: "puzzlepiece.extension", target: .adminMarketplace)
    private static let crafted = AriaSidebarItem(title: "Crafted", icon: "sparkles", target: .adminCrafted)
    private static let maintenance = AriaSidebarItem(title: "Maintenance", icon: "calendar.badge.clock", target: .adminMaintenance)
    private static let taskboard = AriaSidebarItem(title: "Taskboard", icon: "rectangle.split.3x1", target: .adminTaskboard)
    private static let assets = AriaSidebarItem(title: "Assets", icon: "gearshape.2", target: .assets)
    private static let spareParts = AriaSidebarItem(title: "Spare Parts", icon: "shippingbox", target: .spareParts)
    private static let alarms = AriaSidebarItem(title: "Alarms", icon: "bell.badge", target: .adminAlarms)
    private static let vendors = AriaSidebarItem(title: "Vendors", icon: "building.2", target: .adminVendors)
    private static let llmUsage = AriaSidebarItem(title: "LLM Usage", icon: "chart.pie", target: .adminLLMUsage)
    private static let categories = AriaSidebarItem(title: "Categories", icon: "tag", target: .adminCategories)
}
