//
//  AriaShellView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 26/09/26.
//
//  Navigazione come Claude mobile: la chat è la schermata principale e tutte le
//  sezioni (Chat, Task, Calendario, conversazioni fissate e recenti)
//  stanno in una sidebar che si apre dal pulsante ☰ o trascinando dal bordo sinistro.
//  Un account della piattaforma (admin) vede le sezioni della web al posto di Task e Calendario.
//  Il pannello principale scivola a destra con gli angoli arrotondati.
//

import SwiftUI

enum AriaDestination: Hashable {
    case chat
    case chats
    // Operatore
    case tasks
    case calendar
    // Admin
    case adminDocuments
    case adminKnowledgeGraph
    case adminAgentStudio
    case adminMarketplace
    case adminExtractionReview
    case adminLearnedKnowledge
    case adminReasoningConsole
    case adminScenarioAnalysis
    case adminCrafted
    case adminWorkOrders
    case adminMaintenance
    case adminInspections
    case adminTaskboard
    case assets
    case spareParts
    case adminAlarms
    case adminMeters
    case adminLocations
    case adminPurchaseOrders
    case adminVendors
    case adminReports
    case adminLLMUsage
    case adminPlants
    case adminCategories
    case adminTeams
    case adminMembers
    case adminMobileUsers
    case adminChecklistTemplates
    case adminWorkflows
    case adminAgentPrompts
    case adminAuditLog
    case adminCompanySettings
}

/// Stato di apertura della sidebar: un modello osservabile al posto di una closure
/// nell'ambiente, così le viste che leggono il controller non invalidano a ogni render.
@MainActor
@Observable
final class AriaSidebarController {
    private(set) var isOpen = false

    func setOpen(_ open: Bool) {
        if open {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        withAnimation(.snappy(duration: 0.3)) { isOpen = open }
    }
}

extension EnvironmentValues {
    /// Apre la sidebar: il pulsante ☰ di ogni sezione lo legge da qui.
    @Entry var sidebarController: AriaSidebarController?
}

/// Pulsante ☰ da mettere in alto a sinistra nella toolbar di ogni sezione.
struct AriaSidebarButton: View {
    @Environment(\.sidebarController) private var sidebarController

    var body: some View {
        Button("Menu", systemImage: "line.3.horizontal") {
            sidebarController?.setOpen(true)
        }
    }
}

struct AriaShellView: View {
    let user: User
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.scenePhase) private var scenePhase

    @State private var destination: AriaDestination = .chat
    @State private var sidebar = AriaSidebarController()
    @GestureState(resetTransaction: Transaction(animation: .snappy(duration: 0.3)))
    private var dragX: CGFloat = 0
    /// Cambia a ogni "Nuova chat" dalla sidebar: la chat riparte da capo (fonte, bozza, scroll).
    @State private var chatID = UUID()
    @State private var showSettings = false
    @State private var showConnection = false

    /// Da quanto vicino al bordo sinistro parte il trascinamento che apre la sidebar.
    private let edgeWidth: CGFloat = 30

    private var chat: AriaAgentChat { viewModel.mainChat }
    private var store: AriaSessionStore { viewModel.sessions }
    /// Task assegnati, disponibilità e notifiche dei lavori sono solo dell'operatore.
    private var isOperator: Bool { viewModel.accountKind == .operator }

    var body: some View {
        GeometryReader { geo in
            let width = min(geo.size.width * 0.82, 360)
            let offset = min(max((sidebar.isOpen ? width : 0) + dragX, 0), width)
            let progress = offset / width

            ZStack(alignment: .leading) {
                AriaSidebar(
                    user: user,
                    destination: destination,
                    select: select,
                    openSession: openSession,
                    newChat: newChat,
                    showSettings: { showSettings = true },
                    showConnection: { showConnection = true }
                )
                .frame(width: width)
                .offset(x: (progress - 1) * 60)
                .opacity(0.3 + 0.7 * progress)

                main(progress: progress)
                    // Il pannello disegna anche nell'area sicura a sinistra (notch in orizzontale):
                    // scivola oltre anche quella, se no copre la sidebar.
                    .offset(x: offset + progress * geo.safeAreaInsets.leading)
            }
            .simultaneousGesture(dragGesture(width: width))
        }
        .background(Color.liteSidebar.ignoresSafeArea())
        .environment(\.sidebarController, sidebar)
        .sensoryFeedback(.impact(weight: .light), trigger: sidebar.isOpen)
        .task(id: viewModel.backend.isReady) { await store.load() }
        // Disponibilità e lavori all'apertura e a ogni ritorno in primo piano.
        .task {
            guard isOperator else { return }
            await viewModel.notifications.enable()
            await viewModel.ariaWorkOrders.sync()
        }
        .onChange(of: scenePhase) { _, phase in
            // Uscendo dall'app le modifiche ai lavori ancora sul telefono partono subito.
            guard isOperator else { return }
            if phase == .background {
                Task { await viewModel.ariaWorkOrders.flushForBackground() }
                return
            }
            guard phase == .active else { return }
            Task {
                await viewModel.notifications.clearBadge()
                // Il permesso dato più tardi da Impostazioni, o un token cambiato da APNs.
                await viewModel.notifications.enable()
                await viewModel.ariaWorkOrders.sync()
            }
        }
        // Notifica toccata (anche quella che ha aperto l'app): si va ai task e si apre il lavoro.
        .onChange(of: viewModel.notifications.pendingWorkOrderId, initial: true) { _, id in
            guard let id else { return }
            viewModel.notifications.pendingWorkOrderId = nil
            viewModel.ariaWorkOrders.openRequest = id
            select(.tasks)
        }
        // Lavoro arrivato con l'app aperta: la lista si aggiorna da sola.
        .onChange(of: viewModel.notifications.lastArrival) { _, arrival in
            guard arrival != nil else { return }
            Task { await viewModel.ariaWorkOrders.refresh() }
        }
        .onChange(of: sidebar.isOpen) { _, open in
            // Le recenti si aggiornano a ogni apertura: una chat appena iniziata prende il suo titolo.
            if open { Task { await store.load() } }
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheet(user: user, viewModel: viewModel)
        }
        .sheet(isPresented: $showConnection) {
            AriaConnectionSheet(backend: viewModel.backend)
        }
    }

    // MARK: - Pannello principale

    private func main(progress: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: 44 * progress, style: .continuous)
        return content
            .overlay {
                Color.litePanelVeil
                    .opacity(0.45 * progress)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
            // Maschera e ombra fin sotto la status bar: il pannello è tutto lo schermo.
            .mask { shape.ignoresSafeArea() }
            .background {
                shape
                    .fill(Color.liteBackground)
                    .shadow(color: .black.opacity(0.12 * progress), radius: 24, x: -4)
                    .ignoresSafeArea()
            }
            .overlay {
                // Aperta la sidebar, il pannello non si usa: un tocco lo richiude.
                if sidebar.isOpen {
                    Color.clear
                        .contentShape(Rectangle())
                        .ignoresSafeArea()
                        .onTapGesture { sidebar.setOpen(false) }
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch destination {
        case .chat:
            AIChatView()
                .id(chatID)
        case .chats:
            AriaChatHistoryView(chat: chat, store: store, backend: viewModel.backend,
                                onOpen: openSession, onNewChat: newChat,
                                onConnect: { showConnection = true })
        case .calendar:
            AriaCalendarView(store: viewModel.ariaWorkOrders)
        case .tasks:
            AriaWorkOrdersView(store: viewModel.ariaWorkOrders)
        case .adminDocuments:
            AdminDocumentsView(viewModel: viewModel.adminDocuments)
        case .adminKnowledgeGraph:
            AdminKnowledgeGraphView(viewModel: viewModel.adminKnowledgeGraph)
        case .adminAgentStudio:
            AdminAgentStudioView(viewModel: viewModel.adminAgentStudio)
        case .adminMarketplace:
            AdminMarketplaceView(viewModel: viewModel.adminMarketplace)
        case .adminExtractionReview:
            AdminExtractionReviewView(viewModel: viewModel.adminExtractionReview)
        case .adminLearnedKnowledge:
            AdminLearnedKnowledgeView(viewModel: viewModel.adminLearnedKnowledge)
        case .adminReasoningConsole:
            AdminReasoningConsoleView(viewModel: viewModel.adminReasoningConsole)
        case .adminScenarioAnalysis:
            AdminScenarioAnalysisView(viewModel: viewModel.adminScenarioAnalysis)
        case .adminCrafted:
            AdminCraftedView(viewModel: viewModel.adminCrafted)
        case .adminWorkOrders:
            AdminWorkOrdersView(viewModel: viewModel.adminWorkOrders)
        case .adminMaintenance:
            AdminMaintenanceView(viewModel: viewModel.adminMaintenance)
        case .adminInspections:
            AdminInspectionsView(viewModel: viewModel.adminInspections)
        case .adminTaskboard:
            AdminTaskboardView(viewModel: viewModel.adminTaskboard)
        case .assets:
            AdminAssetsView(viewModel: viewModel.adminAssets)
        case .spareParts:
            AdminSparePartsView(viewModel: viewModel.adminSpareParts)
        case .adminPurchaseOrders:
            AdminPurchaseOrdersView(viewModel: viewModel.adminPurchaseOrders)
        case .adminVendors:
            AdminVendorsView(viewModel: viewModel.adminVendors)
        case .adminAlarms:
            AdminAlarmsView(viewModel: viewModel.adminAlarms)
        case .adminMeters:
            AdminComingSoonView(page: .meters)
        case .adminLocations:
            AdminComingSoonView(page: .locations)
        case .adminReports:
            AdminReportsView(viewModel: viewModel.adminReports)
        case .adminLLMUsage:
            AdminLLMUsageView(viewModel: viewModel.adminLLMUsage)
        case .adminPlants:
            AdminPlantsView(viewModel: viewModel.adminPlants)
        case .adminCategories:
            AdminCategoriesView(viewModel: viewModel.adminCategories)
        case .adminTeams:
            AdminTeamsView(viewModel: viewModel.adminTeams)
        case .adminMembers:
            AdminMembersView(viewModel: viewModel.adminMembers)
        case .adminMobileUsers:
            AdminMobileUsersView(viewModel: viewModel.adminMobileUsers)
        case .adminChecklistTemplates:
            AdminComingSoonView(page: .checklistTemplates)
        case .adminWorkflows:
            AdminWorkflowsView(viewModel: viewModel.adminWorkflows)
        case .adminAgentPrompts:
            AdminAgentPromptsView(viewModel: viewModel.adminAgentStudio.prompts)
        case .adminAuditLog:
            AdminAuditLogView(viewModel: viewModel.adminAuditLog)
        case .adminCompanySettings:
            AdminCompanySettingsView(viewModel: viewModel.adminCompanySettings)
        }
    }

    // MARK: - Trascinamento

    private func dragGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 14)
            .updating($dragX) { value, state, _ in
                guard isSidebarDrag(value) else { return }
                state = value.translation.width
            }
            .onEnded { value in
                guard isSidebarDrag(value) else { return }
                let landing = (sidebar.isOpen ? width : 0) + value.predictedEndTranslation.width
                sidebar.setOpen(landing > width / 2)
            }
    }

    /// Orizzontale, e — a sidebar chiusa — partito dal bordo sinistro (lo scroll resta dei contenuti).
    private func isSidebarDrag(_ value: DragGesture.Value) -> Bool {
        guard abs(value.translation.width) > abs(value.translation.height) else { return false }
        return sidebar.isOpen || value.startLocation.x < edgeWidth
    }

    // MARK: - Azioni

    private func select(_ target: AriaDestination) {
        destination = target
        sidebar.setOpen(false)
    }

    private func openSession(_ session: AriaSessionSummary) {
        destination = .chat
        sidebar.setOpen(false)
        guard session.sessionId != chat.sessionId || chat.messages.isEmpty else { return }
        Task { await chat.open(sessionId: session.sessionId) }
    }

    private func newChat() {
        chat.newConversation()
        chatID = UUID()
        destination = .chat
        sidebar.setOpen(false)
    }
}

#Preview {
    AriaShellView(user: User(id: UUID(), username: "operator@example.com", name: "Operator"))
        .environment(AppViewModel())
}
