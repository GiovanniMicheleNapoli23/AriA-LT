//
//  AdminAgentStudioAPI+Policy.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Policy dei workflow (pagina /agent-studio/policy), accuratezza degli agenti e prompt di sistema
//  degli agenti dell'azienda. La policy è in camelCase (anche la matrice R1–R3): il body si manda così com'è.
//

import Foundation

extension AdminAgentStudioAPI {
    // MARK: Policy

    /// Non dà mai 404: un'azienda che non ha impostato nulla gira sui valori di default.
    static func policy() -> AriaEndpoint<AdminAgentStudioOne<AdminAgentStudioPolicy>> {
        .get("v1/agent-studio/policy")
    }

    /// Sostituisce tutta la policy e ne alza la versione: `policy` è l'oggetto intero, non solo i campi cambiati.
    static func updatePolicy(_ policy: [String: AriaJSON]) -> AriaEndpoint<AdminAgentStudioOne<AdminAgentStudioPolicy>> {
        .put("v1/agent-studio/policy", body: AriaJSON.object(policy))
    }

    // MARK: Accuratezza

    /// L'accuratezza di ogni agente sulle ultime risposte valutate (`window` nel resto della risposta).
    static func agentAccuracy() -> AriaEndpoint<AdminAgentStudioList<AdminAgentStudioAgentAccuracy>> {
        .get("v1/agent-studio/agent-accuracy")
    }

    // MARK: Prompt degli agenti

    static func agentPrompts(companyId: String) -> AriaEndpoint<AdminAgentStudioList<AdminAgentStudioAgentPrompt>> {
        .get("v1/companies/\(companyId)/agent-prompts")
    }

    static func saveAgentPrompt(companyId: String, agent: String, prompt: String) -> AriaEndpoint<AdminAgentStudioPromptSaved> {
        .put("v1/companies/\(companyId)/agent-prompts/\(agent)", body: AdminAgentStudioPromptBody(prompt: prompt))
    }

    /// Toglie l'override: l'agente torna al prompt di base.
    static func resetAgentPrompt(companyId: String, agent: String) -> AriaEndpoint<AdminAgentStudioOne<AdminAgentStudioAgentPrompt>> {
        .delete("v1/companies/\(companyId)/agent-prompts/\(agent)")
    }
}
