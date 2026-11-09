//
//  AdminAgentStudioCanvasView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 26/10/26.
//
//  Il canvas di un workflow a tutto schermo, come quello della web: nodi e archi con zoom e scorrimento,
//  e toccando un nodo le sue opzioni (pannello a destra su iPad, foglio su iPhone). Sola lettura.
//

import SwiftUI

struct AdminAgentStudioCanvasView: View {
    @State private var viewModel: AdminAgentStudioCanvasViewModel
    @State private var command = AdminAgentStudioCanvasCommand()
    @ScaledMetric(relativeTo: .subheadline) private var nodeWidth: CGFloat = 220
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var usesSidePanel: Bool { horizontalSizeClass == .regular }

    init(viewModel: AdminAgentStudioCanvasViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        Group {
            if viewModel.isEmpty {
                ContentUnavailableView("This workflow has no steps yet.", systemImage: "point.3.filled.connected.trianglepath.dotted")
            } else {
                canvas
            }
        }
        .liteBackground()
        .navigationTitle(viewModel.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !viewModel.isEmpty {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { command.send(.zoomOut) } label: { Label("Zoom out", systemImage: "minus.magnifyingglass") }
                    Button { command.send(.zoomIn) } label: { Label("Zoom in", systemImage: "plus.magnifyingglass") }
                    Button { command.send(.fit) } label: { Label("Fit", systemImage: "arrow.up.left.and.arrow.down.right") }
                }
            }
        }
        .onAppear { viewModel.setNodeWidth(nodeWidth) }
        .onChange(of: nodeWidth) { _, newValue in viewModel.setNodeWidth(newValue) }
        .sheet(isPresented: sheetBinding) {
            AdminAgentStudioNodeInspector(viewModel: viewModel)
                .presentationDetents([.medium, .large])
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                .presentationDragIndicator(.visible)
        }
    }

    private var canvas: some View {
        ZStack(alignment: .trailing) {
            AdminAgentStudioZoomableCanvas(contentSize: viewModel.layout.contentSize, command: command) {
                AdminAgentStudioCanvasContent(viewModel: viewModel)
            }
            .ignoresSafeArea()

            if usesSidePanel, viewModel.selectedNode != nil {
                AdminAgentStudioNodeInspector(viewModel: viewModel)
                    .frame(width: 360)
                    .frame(maxHeight: .infinity)
                    .ariaGlass(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .padding(12)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: viewModel.showsInspector)
    }

    /// Il foglio solo a larghezza compatta: a larghezza regolare il pannello sta accanto al canvas.
    private var sheetBinding: Binding<Bool> {
        Binding(
            get: { !usesSidePanel && viewModel.showsInspector },
            set: { viewModel.showsInspector = $0 }
        )
    }
}
