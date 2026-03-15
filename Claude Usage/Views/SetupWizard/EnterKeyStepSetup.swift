import SwiftUI
import AppKit

/// Step 1: Enter session key and test connection.
struct EnterKeyStepSetup: View {
    @Environment(\.dismiss) var dismiss
    @Binding var wizardState: WizardState
    let apiService: ClaudeAPIService

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    SetupStepHeader(stepNumber: 1, title: "setup.step.get_session_key".localized)

                    Text("setup.step.get_session_key.description".localized)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)

                    // Action buttons
                    HStack(spacing: 10) {
                        Button(action: {
                            if let url = URL(string: "https://claude.ai") {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            HStack {
                                Image(systemName: "safari")
                                Text("setup.open_claude_ai".localized)
                            }
                            .font(.system(size: 12))
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        Button(action: { wizardState.showInstructions.toggle() }) {
                            HStack {
                                Image(systemName: wizardState.showInstructions ? "chevron.up" : "chevron.down")
                                Text(wizardState.showInstructions ? "setup.hide_instructions".localized : "setup.show_instructions".localized)
                            }
                            .font(.system(size: 12))
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }

                    // Instructions (expandable)
                    if wizardState.showInstructions {
                        VStack(alignment: .leading, spacing: 8) {
                            InstructionRow(text: "setup.instruction.step1".localized)
                            InstructionRow(text: "setup.instruction.step2".localized)
                            InstructionRow(text: "setup.instruction.step3".localized)
                            InstructionRow(text: "setup.instruction.step4".localized)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(nsColor: .controlBackgroundColor))
                        )
                    }

                    Divider()

                    // Session key input
                    VStack(alignment: .leading, spacing: 12) {
                        Text("personal.label_session_key".localized)
                            .font(.system(size: 13, weight: .medium))

                        TextField("personal.placeholder_session_key".localized, text: $wizardState.sessionKey)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12, design: .monospaced))
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(nsColor: .textBackgroundColor))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .strokeBorder(Color.gray.opacity(0.2), lineWidth: 1)
                                    )
                            )

                        Text("setup.paste_session_key".localized)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    // Validation Status
                    if case .success(let message) = wizardState.validationState {
                        StatusFeedbackBox(message: message, status: .success)
                    } else if case .error(let message) = wizardState.validationState {
                        StatusFeedbackBox(message: message, status: .error)
                    }
                }
                .padding(32)
            }

            Divider()

            // Footer
            HStack {
                Button("common.cancel".localized) {
                    // Dismiss handled by parent
                }
                .buttonStyle(.bordered)

                Spacer()

                Button(action: testConnection) {
                    if case .validating = wizardState.validationState {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 100)
                    } else {
                        Text("wizard.test_connection".localized)
                            .frame(width: 100)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(wizardState.sessionKey.isEmpty || wizardState.validationState == .validating)
            }
            .padding(20)
        }
    }

    private func testConnection() {
        let validator = SessionKeyValidator()
        let validationResult = validator.validationStatus(wizardState.sessionKey)

        guard validationResult.isValid else {
            wizardState.validationState = .error(validationResult.errorMessage ?? "Invalid")
            return
        }

        wizardState.validationState = .validating

        Task {
            do {
                let organizations = try await apiService.testSessionKey(wizardState.sessionKey)

                await MainActor.run {
                    wizardState.testedOrganizations = organizations
                    wizardState.validationState = .success("Connection successful! Found \(organizations.count) organization(s)")

                    withAnimation {
                        wizardState.currentStep = .selectOrg
                    }
                }

            } catch {
                let appError = AppError.wrap(error)
                ErrorLogger.shared.log(appError, severity: .error)

                await MainActor.run {
                    let errorMessage = "\(appError.message)\n\nError Code: \(appError.code.rawValue)"
                    wizardState.validationState = .error(errorMessage)
                }
            }
        }
    }
}
