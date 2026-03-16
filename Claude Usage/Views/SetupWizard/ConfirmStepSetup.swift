import SwiftUI

/// Step 3: Review configuration and save credentials.
struct ConfirmStepSetup: View {
    @Binding var wizardState: WizardState
    let apiService: ClaudeAPIService
    let dismiss: DismissAction
    @StateObject private var viewModel = SetupWizardViewModel()

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    SetupStepHeader(stepNumber: 3, title: "wizard.review_config".localized)

                    // Summary Card
                    VStack(alignment: .leading, spacing: 16) {
                        Text("wizard.config_summary".localized)
                            .font(.system(size: 14, weight: .semibold))

                        // Session Key (masked)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("wizard.session_key".localized)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                            Text(wizardState.sessionKey.maskedKey())
                                .font(.system(size: 11, design: .monospaced))
                        }

                        Divider()

                        // Selected Organization
                        VStack(alignment: .leading, spacing: 6) {
                            Text("wizard.organization".localized)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                            if let selectedOrg = wizardState.testedOrganizations.first(where: { $0.uuid == wizardState.selectedOrgId }) {
                                Text(selectedOrg.name)
                                    .font(.system(size: 13))
                                Text(String(format: "wizard.organization_id".localized, selectedOrg.uuid))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(16)
                    .background(Color.secondary.opacity(0.05))
                    .cornerRadius(10)

                    // Auto-start session option
                    VStack(alignment: .leading, spacing: 10) {
                        Divider()

                        HStack(spacing: 6) {
                            Text("setup.auto_start_session".localized)
                                .font(.system(size: 13, weight: .semibold))

                            Text("session.beta_badge".localized)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.orange)
                                )
                        }

                        Text("setup.auto_start_session.description".localized)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Toggle(isOn: $wizardState.autoStartSessionEnabled) {
                            Text("setup.enable_auto_start".localized)
                                .font(.system(size: 12, weight: .medium))
                        }
                        .toggleStyle(.switch)
                    }
                }
                .padding(32)
            }

            Divider()

            // Footer
            HStack {
                Button("common.back".localized) {
                    withAnimation {
                        wizardState.currentStep = .selectOrg
                    }
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isSaving)

                Spacer()

                Button(action: saveConfiguration) {
                    if viewModel.isSaving {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 100)
                    } else {
                        Text("common.done".localized)
                            .frame(width: 100)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isSaving)
            }
            .padding(20)
        }
    }

    private func saveConfiguration() {
        Task {
            let errorMessage = await viewModel.saveConfiguration(
                sessionKey: wizardState.sessionKey,
                organizationId: wizardState.selectedOrgId,
                autoStartEnabled: wizardState.autoStartSessionEnabled
            )

            if let errorMessage {
                wizardState.validationState = .error(errorMessage)
                withAnimation {
                    wizardState.currentStep = .enterKey
                }
            } else {
                dismiss()
            }
        }
    }

}
