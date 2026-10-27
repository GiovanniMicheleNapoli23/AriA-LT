//
//  AdminTaskboardKanbanBoard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 26/10/26.
//
//  La kanban: tutte le colonne affiancate a tutta altezza, in uno scroll orizzontale che si ferma su una
//  colonna. Su schermi larghi (e iPhone in orizzontale) se ne vedono più insieme e crescono con il Dynamic Type.
//  Su iPhone in verticale una colonna prende quasi tutto lo schermo e lascia intravedere la successiva, uno
//  swipe porta alla colonna dopo e sopra stanno le chip degli stati: dicono dove si è, ci portano a una colonna
//  con un tocco e accolgono le card trascinate (le colonne lontane non sono a schermo, le chip sì).
//

import SwiftUI

struct AdminTaskboardKanbanBoard<CardView: View>: View {
    @Bindable var viewModel: AdminTaskboardViewModel
    @ViewBuilder var card: (AdminWorkOrderRowItem) -> CardView

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @ScaledMetric(relativeTo: .body) private var columnWidth: CGFloat = 300
    @State private var position = ScrollPosition(idType: AdminWorkOrderStatus.self)

    /// iPhone in verticale: una colonna alla volta, con le chip.
    private var isPhonePortrait: Bool { horizontalSizeClass == .compact && verticalSizeClass == .regular }
    /// Quanto si vede della colonna successiva su iPhone, uguale su ogni modello.
    private let peek: CGFloat = 28

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if isPhonePortrait {
                AdminTaskboardColumnPicker(columns: AdminTaskboardViewModel.columns, selection: chipSelection,
                                           count: { viewModel.count(in: $0) },
                                           onDrop: { viewModel.drop($1, on: $0) })
            }
            columns
        }
        .onAppear {
            if isPhonePortrait { position.scrollTo(id: viewModel.selectedStatus, anchor: .leading) }
        }
    }

    private var columns: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(AdminTaskboardViewModel.columns, id: \.self) { status in
                    AdminTaskboardKanbanColumn(status: status, items: viewModel.cards(in: status),
                                               onDrop: { viewModel.drop($0, on: status) }, card: card)
                        .containerRelativeFrame(.horizontal) { length, _ in
                            isPhonePortrait ? length - peek : min(columnWidth, length * 0.86)
                        }
                }
            }
            .scrollTargetLayout()
        }
        .contentMargins(.horizontal, 16, for: .scrollContent)
        .scrollPosition($position)
        .scrollTargetBehavior(.viewAligned(limitBehavior: isPhonePortrait ? .alwaysByOne : .automatic))
        .scrollIndicators(.hidden)
        // La colonna quasi tutta a schermo è quella scelta (e quella in cui nasce un nuovo task).
        .onScrollTargetVisibilityChange(idType: AdminWorkOrderStatus.self, threshold: 0.6) { visible in
            guard isPhonePortrait, let status = visible.first, status != viewModel.selectedStatus else { return }
            viewModel.selectedStatus = status
        }
    }

    /// Un tocco su una chip porta alla sua colonna; lo scroll a mano aggiorna la chip senza ripassare di qui.
    private var chipSelection: Binding<AdminWorkOrderStatus> {
        Binding(get: { viewModel.selectedStatus }, set: { status in
            viewModel.selectedStatus = status
            withAnimation(.snappy) { position.scrollTo(id: status, anchor: .leading) }
        })
    }
}
