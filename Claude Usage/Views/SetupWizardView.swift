import SwiftUI
import AppKit

/// Professional, native macOS setup wizard with 3-step flow.
///
/// Coordinates the wizard header, optional banners (Claude Code, migration),
/// and step content views. Each step is defined in its own file under
/// `Views/SetupWizard/`.
struct SetupWizardView: View {
    @Environment(\.dismiss) var dismiss
    @State private var wizardState = WizardState()
    @State private var hasClaudeCodeCredentials = false
    @State private var isMigrating = false
    @State private var migrationMessage: String?
    private let apiService = ClaudeAPIService()

    var body: some View {
        VStack(spacing: 0) {
            SetupWizardHeader(currentStep: wizardState.currentStep)

            Divider()

            // Claude Code info banner
            if hasClaudeCodeCredentials {
                claudeCodeBanner
                Divider()
            }

            // Migration banner
            if MigrationService.shared.shouldShowMigrationOption() {
                SetupWizardMigrationBanner(
                    isMigrating: $isMigrating,
                    migrationMessage: $migrationMessage
                )
                Divider()
            }

            // Step content
            Group {
                switch wizardState.currentStep {
                case .enterKey:
                    EnterKeyStepSetup(wizardState: $wizardState, apiService: apiService)
                case .selectOrg:
                    SelectOrgStepSetup(wizardState: $wizardState)
                case .confirm:
                    ConfirmStepSetup(wizardState: $wizardState, apiService: apiService, dismiss: dismiss)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: wizardState.currentStep)
        }
        .frame(width: 580, height: 680)
        .onAppear {
            if let activeProfile = ProfileManager.shared.activeProfile {
                wizardState.autoStartSessionEnabled = activeProfile.autoStartSessionEnabled
            }

            Task {
                do {
                    let credentials = try await ClaudeCodeSyncService.shared.readSystemCredentials()
                    await MainActor.run {
                        hasClaudeCodeCredentials = (credentials != nil)
                    }
                } catch {
                    await MainActor.run {
                        hasClaudeCodeCredentials = false
                    }
                }
            }
        }
    }

    // MARK: - Claude Code Banner

    private var claudeCodeBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "terminal")
                .font(.system(size: 16))
                .foregroundColor(.purple)

            VStack(alignment: .leading, spacing: 4) {
                Text("wizard.claude_code_info_title".localized)
                    .font(.system(size: 12, weight: .medium))
                Text("wizard.claude_code_info_description".localized)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Button(action: { dismiss() }) {
                Text("wizard.claude_code_skip_setup".localized)
                    .font(.system(size: 11))
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.purple.opacity(0.08))
    }
}

#Preview {
    SetupWizardView()
}
