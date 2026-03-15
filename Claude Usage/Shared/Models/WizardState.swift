//
//  WizardState.swift
//  Claude Usage
//
//  Shared wizard state machine for credential setup flows.
//

import Foundation

// MARK: - Wizard Step

/// Steps in the credential setup wizard (enterKey → selectOrg → confirm).
enum WizardStep: Int, Comparable {
    case enterKey = 1
    case selectOrg = 2
    case confirm = 3

    static func < (lhs: WizardStep, rhs: WizardStep) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Wizard State

/// Shared state for credential setup wizards (SetupWizard and PersonalUsage).
struct WizardState {
    var currentStep: WizardStep = .enterKey
    var sessionKey: String = ""
    var validationState: ValidationState = .idle
    var testedOrganizations: [ClaudeAPIService.AccountInfo] = []
    var selectedOrgId: String? = nil

    // Used by PersonalUsageView for edit-mode restore
    var originalSessionKey: String? = nil
    var originalOrgId: String? = nil

    // Used by SetupWizardView
    var autoStartSessionEnabled: Bool = false
    var showInstructions: Bool = false
}
