//
//  APIServiceProtocol.swift
//  Claude Usage
//
//  Created by Claude Code on 2025-12-20.
//

import Foundation

/// Protocol defining API operations for Claude services
/// Enables dependency injection and testing with mock API services
protocol APIServiceProtocol {
    // MARK: - Claude.ai API
    func fetchOrganizationId(sessionKey: String, storedOrgId: String?) async throws -> (orgId: String, isNewlyFetched: Bool)
    func fetchUsageData(sessionKey: String, organizationId: String) async throws -> ClaudeUsage
    func fetchUsageData(oauthAccessToken: String) async throws -> ClaudeUsage
    func fetchUsageData(
        auth: AuthenticationType,
        storedOrgId: String?,
        checkOverageLimitEnabled: Bool,
        sessionKeyFallback: String?
    ) async throws -> (usage: ClaudeUsage, newlyFetchedOrgId: String?)
    @discardableResult
    func sendInitializationMessage(sessionKey: String, organizationId: String) async throws -> Data?

    // MARK: - Console API
    func fetchConsoleOrganizations(apiSessionKey: String) async throws -> [APIOrganization]
    func fetchAPIUsageData(organizationId: String, apiSessionKey: String) async throws -> APIUsage
}
