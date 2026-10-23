//
//  AdminMarketplaceItemDetailView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  La pagina di un elemento del Marketplace (item-detail.tsx della web), pensata per iPhone e iPad: intestazione, acquisto o stato, corpo per tipo, dettagli e requisiti.
//  Per un connettore, la chiave si inserisce in un foglio e, tornando dal browser, la lista si rilegge da sé.
//

import SwiftUI

struct AdminMarketplaceItemDetailView: View {
    @State private var viewModel: AdminMarketplaceItemDetailViewModel

    @Environment(\.scenePhase) private var scenePhase

    init(viewModel: AdminMarketplaceItemDetailViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                AdminMarketplaceItemHeader(viewModel: viewModel)
                AdminMarketplaceActionCard(viewModel: viewModel)
                itemBody
                extras
                AdminMarketplaceFactsCard(facts: viewModel.facts)
                if !viewModel.requirements.isEmpty {
                    AdminMarketplaceRequirementsCard(viewModel: viewModel)
                }
            }
            .padding(20)
            .ariaReadableWidth()
        }
        .liteBackground()
        .navigationTitle(viewModel.item.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.prepare() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await viewModel.returnedFromConsent() } }
        }
        .sheet(item: $viewModel.credentialsForm) { form in
            AdminConnectorCredentialsFormView(viewModel: form) {
                Task { await viewModel.credentialsSaved() }
            }
        }
        .alert("Couldn't complete the action", isPresented: $viewModel.showsActionError) {
            Button("OK") {}
        } message: {
            Text(viewModel.actionError ?? "")
        }
        .alert(viewModel.purchaseTitle, isPresented: $viewModel.confirmsPurchase) {
            Button("Buy") { viewModel.buy() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(viewModel.purchaseMessage)
        }
    }

    // MARK: Corpo per tipo

    @ViewBuilder
    private var itemBody: some View {
        switch viewModel.bodyKind {
        case .workflow:
            AdminMarketplaceDetailCard(title: Text("How it runs"), systemImage: "point.3.connected.trianglepath.dotted") {
                AdminMarketplaceTimelineView(rows: viewModel.timeline)
            }
        case .fullSet:
            AdminMarketplaceFullSetBody(viewModel: viewModel)
        case .adds:
            AdminMarketplaceAddsCard(title: viewModel.item.kind.addsTitle, lines: viewModel.item.adds)
        }
    }

    /// Quello che ha solo un tipo: chi configura un agent pack, cosa entra in un knowledge pack, le skill di un pacchetto.
    @ViewBuilder
    private var extras: some View {
        if let sentence = viewModel.agentPackSentence {
            AdminMarketplaceDetailCard(title: Text("Who it configures"), systemImage: "person.crop.rectangle.stack") {
                Text(verbatim: sentence)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        if let sentence = viewModel.knowledgeSentence {
            AdminMarketplaceDetailCard(title: Text("What lands in your knowledge base"), systemImage: "books.vertical") {
                VStack(alignment: .leading, spacing: 12) {
                    Text(verbatim: sentence)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if !viewModel.standards.isEmpty {
                        AdminMarketplaceSectionFlow(spacing: 6) {
                            ForEach(viewModel.standards, id: \.self) { AdminMarketplaceCapsule(verbatim: $0) }
                        }
                    }
                }
            }
        }
        let skills = viewModel.bundledSkills
        if !skills.isEmpty {
            AdminMarketplaceDetailCard(title: Text(verbatim: viewModel.bundledSkillsTitle), systemImage: "sparkles") {
                AdminMarketplaceItemLinkList(items: skills, viewModel: viewModel)
            }
        }
    }
}
