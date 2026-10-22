//
//  AdminAgentPromptsView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La sezione Agent prompts, come la pagina /settings/agents della web. Lista, editor e ritorno al testo
//  di base ci sono già in Agent Studio: qui si riusano con lo stesso view model, così le due sezioni
//  mostrano sempre gli stessi prompt.
//

import SwiftUI

struct AdminAgentPromptsView: View {
    let viewModel: AdminAgentStudioPromptsViewModel

    var body: some View {
        NavigationStack {
            AdminAgentStudioPromptsView(viewModel: viewModel)
                .navigationBarTitleDisplayMode(.automatic)
                .navigationDestination(for: AdminAgentStudioRoute.self) { route in
                    if case .prompt(let name) = route {
                        AdminAgentStudioPromptEditorView(viewModel: viewModel.makeEditor(name: name))
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) { AriaSidebarButton() }
                }
        }
    }
}
