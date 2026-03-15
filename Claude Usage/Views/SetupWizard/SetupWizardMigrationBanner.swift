import SwiftUI

/// Migration banner shown when legacy data can be imported.
struct SetupWizardMigrationBanner: View {
    @Environment(\.dismiss) var dismiss
    @Binding var isMigrating: Bool
    @Binding var migrationMessage: String?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.down.doc")
                .font(.system(size: 16))
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 4) {
                Text("wizard.migrate_old_data".localized)
                    .font(.system(size: 12, weight: .medium))

                if let message = migrationMessage {
                    Text(message)
                        .font(.system(size: 11))
                        .foregroundColor(.green)
                        .lineLimit(1)
                } else {
                    Text("wizard.migrate_description_short".localized)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Button(action: migrateOldData) {
                    HStack {
                        if isMigrating {
                            ProgressView()
                                .scaleEffect(0.6)
                        } else {
                            Text("wizard.migrate_button".localized)
                                .font(.system(size: 11))
                        }
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isMigrating)

                Button(action: skipMigration) {
                    Text("wizard.skip_migration".localized)
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .disabled(isMigrating)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.blue.opacity(0.08))
    }

    // MARK: - Migration Functions

    private func migrateOldData() {
        isMigrating = true
        migrationMessage = nil

        Task {
            do {
                let count = try MigrationService.shared.migrateFromAppGroup()
                await MainActor.run {
                    isMigrating = false
                    migrationMessage = String(format: "wizard.migration_success".localized, count)
                    ProfileManager.shared.loadProfiles()
                }

                try? await Task.sleep(nanoseconds: 1_500_000_000)

                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isMigrating = false
                    migrationMessage = String(format: "wizard.migration_failed".localized, error.localizedDescription)
                }
            }
        }
    }

    private func skipMigration() {
        UserDefaults.standard.set(true, forKey: Constants.UserDefaultsKeys.hasMigratedFromAppGroup)
        migrationMessage = "wizard.migration_skipped".localized
    }
}
