//
//  AriaOnboardingPage.swift
//  AriaLite
//
//  Created by Giovanni Michele on 10/11/26.
//
//  Una pagina della presentazione: simbolo, titolo, una frase e, se serve, le voci che la spiegano
//  (per l'admin, le sezioni della sidebar con gli stessi nomi e simboli di AriaSidebarSections).
//

import Foundation

nonisolated struct AriaOnboardingPage: Identifiable, Sendable {
    struct Highlight: Identifiable, Sendable {
        let symbol: String
        let title: LocalizedStringResource
        var detail: LocalizedStringResource?

        var id: String { symbol + title.key }
    }

    let id: String
    let symbol: String
    let title: LocalizedStringResource
    let message: LocalizedStringResource
    var highlights: [Highlight] = []
}

// MARK: - Tecnico

nonisolated extension AriaOnboardingPage {
    /// Quello che il tecnico ha oggi: chat, voce, procedure, Task e Calendario. Le sezioni della web che il ruolo
    /// può concedere (`access.appFollowsRole`) non si promettono: con l'interruttore spento non ci sono.
    static let technician: [AriaOnboardingPage] = [
        AriaOnboardingPage(
            id: "chat", symbol: "bubble.left.and.text.bubble.right", title: "Ask Aria",
            message: "Describe a fault, a machine or a step you're stuck on: Aria answers from your site's manuals and history.",
            highlights: [
                Highlight(symbol: "mic", title: "Type or dictate"),
                Highlight(symbol: "paperclip", title: "Attach photos and files"),
                Highlight(symbol: "pin", title: "Pinned and recent conversations in the sidebar"),
            ]),
        AriaOnboardingPage(
            id: "voice", symbol: "waveform", title: "Talk hands-free",
            message: "Start a voice conversation and keep your hands on the job: Aria listens and answers out loud."),
        AriaOnboardingPage(
            id: "procedures", symbol: "list.number", title: "Step-by-step procedures",
            message: "Aria guides you through the job one step at a time and stops to check before anything risky.",
            highlights: [
                Highlight(symbol: "lock.shield", title: "Lockout/tagout (LOTO) confirmation"),
                Highlight(symbol: "questionmark.bubble", title: "Guided questions to pin down the fault"),
                Highlight(symbol: "checklist", title: "Your progress is saved as you go"),
            ]),
        AriaOnboardingPage(
            id: "jobs", symbol: "checklist", title: "Your jobs",
            message: "Tasks lists the work orders assigned to you and Calendar shows them day by day. Open one and work through its steps.",
            highlights: [
                Highlight(symbol: "bell.badge", title: "A notification when a new job arrives"),
                Highlight(symbol: "camera", title: "Photos on each step"),
                Highlight(symbol: "person.crop.circle.badge.checkmark", title: "Let the team know you're available, from your profile"),
            ]),
        AriaOnboardingPage(
            id: "offline", symbol: "wifi.slash", title: "Even without signal",
            message: "No network on site? Keep working: your changes stay on the phone and are sent as soon as you're back online."),
        AriaOnboardingPage(
            id: "closeout", symbol: "checkmark.seal", title: "Close the job",
            message: "When you're done, Aria writes the report and files the work order, in MaintainX too if your company uses it."),
        AriaOnboardingPage(
            id: "access", symbol: "faceid", title: "Quick, secure access",
            message: "Sign in with the link we email you, no password needed. Face ID locks the app whenever you leave it."),
    ]
}

// MARK: - Admin

nonisolated extension AriaOnboardingPage {
    /// Una pagina per gruppo della sidebar dell'admin, nello stesso ordine.
    static let admin: [AriaOnboardingPage] = [
        AriaOnboardingPage(
            id: "overview", symbol: "square.grid.2x2", title: "The whole platform, on your phone",
            message: "What you manage on AriaPLT web is here too, grouped in the sidebar as on the web. You only see what your role allows.",
            highlights: [
                Highlight(symbol: "bubble.left.and.text.bubble.right", title: "Chat with Aria, by text or voice"),
                Highlight(symbol: "sidebar.left", title: "Every section from the sidebar"),
                Highlight(symbol: "faceid", title: "Sign in with an email link, locked with Face ID"),
            ]),
        AriaOnboardingPage(
            id: "intelligence", symbol: "brain.head.profile", title: "Intelligence",
            message: "Teach Aria how your site works and let it work for you.",
            highlights: [
                Highlight(symbol: "doc.text", title: "Documents", detail: "Upload manuals and procedures for Aria to read"),
                Highlight(symbol: "text.viewfinder", title: "Extraction Review",
                          detail: "Approve the assets, alarms, plans and parts Aria found in them"),
                Highlight(symbol: "brain", title: "Learned knowledge", detail: "What Aria has learned from the field, to review"),
                Highlight(symbol: "cpu", title: "Agent Studio", detail: "Agents that run on a schedule or when something happens"),
                Highlight(symbol: "chart.line.uptrend.xyaxis", title: "Scenario analysis",
                          detail: "Scenarios, session reviews and procedure closures"),
                Highlight(symbol: "sparkles", title: "Crafted", detail: "Documents and pages Aria creates for you"),
            ]),
        AriaOnboardingPage(
            id: "marketplace", symbol: "puzzlepiece.extension", title: "Marketplace",
            message: "Connect the tools you already use, like MaintainX, and add skills, agents and knowledge packs."),
        AriaOnboardingPage(
            id: "operations", symbol: "wrench.and.screwdriver", title: "Operations",
            message: "Plan the work and follow it until it's done.",
            highlights: [
                Highlight(symbol: "wrench.and.screwdriver", title: "Work Orders", detail: "Create, assign and track jobs, with help from AI"),
                Highlight(symbol: "calendar.badge.clock", title: "Maintenance", detail: "Preventive maintenance plans"),
                Highlight(symbol: "checklist.checked", title: "Inspections", detail: "Checklists for rounds and checks"),
                Highlight(symbol: "rectangle.split.3x1", title: "Taskboard", detail: "The work in columns, like a board"),
            ]),
        AriaOnboardingPage(
            id: "resources", symbol: "shippingbox", title: "Assets, parts and purchases",
            message: "Everything on the site, and everything it needs.",
            highlights: [
                Highlight(symbol: "gearshape.2", title: "Assets", detail: "Machines, their details and downtime"),
                Highlight(symbol: "shippingbox", title: "Spare Parts", detail: "Stock and low-stock warnings"),
                Highlight(symbol: "bell.badge", title: "Alarms", detail: "AI diagnosis with the likely cause and repair steps"),
                Highlight(symbol: "cart", title: "Purchase Orders", detail: "Orders to your vendors"),
                Highlight(symbol: "building.2", title: "Vendors", detail: "Your suppliers' details"),
            ]),
        AriaOnboardingPage(
            id: "analytics", symbol: "chart.bar.xaxis", title: "Analytics",
            message: "See how the site, and Aria, are doing.",
            highlights: [
                Highlight(symbol: "chart.bar.xaxis", title: "Reports", detail: "Saved widgets with today's data"),
                Highlight(symbol: "chart.pie", title: "LLM Usage", detail: "How much AI your company uses"),
            ]),
        AriaOnboardingPage(
            id: "configuration", symbol: "building.columns", title: "Configuration",
            message: "Set up the company and the people who work in it.",
            highlights: [
                Highlight(symbol: "building.columns", title: "Sites", detail: "Your sites"),
                Highlight(symbol: "tag", title: "Categories", detail: "The categories that keep your data in order"),
                Highlight(symbol: "person.3", title: "Teams", detail: "Groups of people"),
                Highlight(symbol: "person.2", title: "Members", detail: "Your people, their role and access to this app"),
                Highlight(symbol: "person.badge.key", title: "Roles & Rights", detail: "What each role can see and do"),
            ]),
    ]
}
