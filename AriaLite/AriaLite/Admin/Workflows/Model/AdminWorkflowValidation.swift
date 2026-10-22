//
//  AdminWorkflowValidation.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  L'esito del controllo di un flusso (FlowValidationResult): valido o no, con errori (bloccano la
//  pubblicazione) e avvisi (non la bloccano). Ogni problema può indicare il nodo o il collegamento.
//

import Foundation

nonisolated struct AdminWorkflowValidation: Decodable, Sendable, Hashable {
    let valid: Bool
    let errors: [AdminWorkflowIssue]
    let warnings: [AdminWorkflowIssue]

    private enum CodingKeys: String, CodingKey { case valid, errors, warnings }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        errors = (try? c.decodeIfPresent(AriaLossyArray<AdminWorkflowIssue>.self, forKey: .errors))?.items ?? []
        warnings = (try? c.decodeIfPresent(AriaLossyArray<AdminWorkflowIssue>.self, forKey: .warnings))?.items ?? []
        // Se `valid` manca, vale la presenza di errori.
        valid = (try? c.decodeIfPresent(Bool.self, forKey: .valid)) ?? errors.isEmpty
    }
}

nonisolated struct AdminWorkflowIssue: Decodable, Sendable, Hashable {
    let code: String
    let message: String
    let nodeId: String?
    let edgeId: String?

    private enum CodingKeys: String, CodingKey { case code, message, nodeId, edgeId }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        code = (try? c.decodeIfPresent(String.self, forKey: .code)) ?? ""
        message = (try? c.decodeIfPresent(String.self, forKey: .message)) ?? ""
        nodeId = (try? c.decodeIfPresent(String.self, forKey: .nodeId)).flatMap { $0.isEmpty ? nil : $0 }
        edgeId = (try? c.decodeIfPresent(String.self, forKey: .edgeId)).flatMap { $0.isEmpty ? nil : $0 }
    }
}
