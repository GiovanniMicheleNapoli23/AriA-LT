//
//  CraftedStorageTests.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 20/11/26.
//
//  Gli artifact e le versioni di Crafted stanno sul dispositivo in una cartella per azienda e per account:
//  un altro account della stessa azienda, sullo stesso dispositivo, non trova quelli di chi c'era prima.
//

import Foundation
import Testing
@testable import AriaLite

@MainActor
struct CraftedStorageTests {
    private func temporaryFolder() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "CraftedStorageTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    }

    @Test func artifactsBelongToTheAccountThatMadeThem() {
        let base = temporaryFolder()
        defer { try? FileManager.default.removeItem(at: base) }
        let first = AdminCraftedArtifactStore(companyId: "c1", accountId: "u1", baseURL: base)
        first.create(request: "Report on pump P-101", sessionId: "s1")
        #expect(first.list.count == 1)

        #expect(AdminCraftedArtifactStore(companyId: "c1", accountId: "u2", baseURL: base).list.isEmpty,
                "un altro account della stessa azienda non li vede")
        #expect(AdminCraftedArtifactStore(companyId: "c2", accountId: "u1", baseURL: base).list.isEmpty)
        #expect(AdminCraftedArtifactStore(companyId: "c1", accountId: "u1", baseURL: base).list.count == 1,
                "chi li ha fatti li ritrova")
    }

    @Test func theFolderIsPerCompanyAndPerAccount() {
        let base = URL(filePath: "/base", directoryHint: .isDirectory)
        let url = AdminCraftedStorage.fileURL(baseURL: base, companyId: "c1", accountId: "u1", name: "artifacts.json")
        #expect(url.path() == "/base/c1/u1/artifacts.json")
        // Gli id finiscono nel percorso: i caratteri che lo cambierebbero non passano.
        let odd = AdminCraftedStorage.fileURL(baseURL: base, companyId: "../c", accountId: "a/b", name: "artifacts.json")
        #expect(odd.path() == "/base/___c/a_b/artifacts.json")
    }
}
