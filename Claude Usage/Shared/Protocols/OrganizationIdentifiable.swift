//
//  OrganizationIdentifiable.swift
//  Claude Usage
//
//  Created by Claude Code on 2026-03-15.
//

import Foundation

/// A type that represents an organization that can be selected in a wizard step.
/// Conforming types provide a stable string identifier and a display name.
protocol OrganizationIdentifiable: Identifiable {
    /// A stable string identifier used for selection and persistence.
    var idString: String { get }

    /// The human-readable name shown in the organization picker.
    var displayName: String { get }
}

// MARK: - AccountInfo Conformance

extension ClaudeAPIService.AccountInfo: OrganizationIdentifiable {
    var id: String { uuid }
    var idString: String { uuid }
    var displayName: String { name.isEmpty ? uuid : name }
}

// MARK: - APIOrganization Conformance

extension APIOrganization: OrganizationIdentifiable {
    var idString: String { id }
    // displayName is already defined on APIOrganization
}
