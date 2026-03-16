//
//  ClaudeCodeView.swift
//  Claude Usage - Claude Code Statusline Integration
//
//  Created by Claude Code on 2025-12-20.
//

import SwiftUI

/// Claude Code statusline integration settings
struct ClaudeCodeView: View {
    @StateObject private var viewModel = ClaudeCodeViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.section) {
                // Page Header
                SettingsPageHeader(
                    title: "claudecode.title".localized,
                    subtitle: "claudecode.subtitle".localized
                )

            // Preview Card (keep as is - user loves it!)
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.medium) {
                HStack {
                    Label("claudecode.preview_label".localized, systemImage: "eye.fill")
                        .font(DesignTokens.Typography.sectionTitle)
                        .foregroundColor(.primary)

                    Spacer()

                    Text("ui.updates_realtime".localized)
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
                    Text(generatePreview())
                        .font(DesignTokens.Typography.monospaced)
                        .foregroundColor(.accentColor)
                        .padding(DesignTokens.Spacing.medium)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
                                .fill(Color.accentColor.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
                                        .strokeBorder(Color.accentColor.opacity(0.2), lineWidth: 1)
                                )
                        )

                    Text("claudecode.preview_description".localized)
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(DesignTokens.Spacing.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.card)
                    .fill(DesignTokens.Colors.cardBackground)
            )

            // Components - Simple and clean
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.medium) {
                Text("ui.display_components".localized)
                    .font(DesignTokens.Typography.sectionTitle)

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
                    Toggle("claudecode.component_directory".localized, isOn: $viewModel.showDirectory)
                        .font(DesignTokens.Typography.body)

                    Toggle("claudecode.component_branch".localized, isOn: $viewModel.showBranch)
                        .font(DesignTokens.Typography.body)

                    Toggle("claudecode.component_usage".localized, isOn: $viewModel.showUsage)
                        .font(DesignTokens.Typography.body)

                    if viewModel.showUsage {
                        HStack(spacing: 0) {
                            Spacer().frame(width: 20)
                            Toggle("claudecode.component_progressbar".localized, isOn: $viewModel.showProgressBar)
                                .font(DesignTokens.Typography.caption)
                                .foregroundColor(.secondary)
                        }

                        HStack(spacing: 0) {
                            Spacer().frame(width: 20)
                            Toggle("claudecode.component_resettime".localized, isOn: $viewModel.showResetTime)
                                .font(DesignTokens.Typography.caption)
                                .foregroundColor(.secondary)
                        }

                        if viewModel.showProgressBar {
                            HStack(spacing: 0) {
                                Spacer().frame(width: 20)
                                Toggle("claudecode.component_timemarker".localized, isOn: $viewModel.showTimeMarker)
                                    .font(DesignTokens.Typography.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }

            // Action buttons - compact
            HStack(spacing: DesignTokens.Spacing.iconText) {
                Button(action: { viewModel.applyConfiguration() }) {
                    Text("claudecode.button_apply".localized)
                        .font(DesignTokens.Typography.body)
                        .frame(minWidth: 70)
                }
                .buttonStyle(.borderedProminent)

                Button(action: { viewModel.resetConfiguration() }) {
                    Text("claudecode.button_reset".localized)
                        .font(DesignTokens.Typography.body)
                        .frame(minWidth: 70)
                }
                .buttonStyle(.bordered)
            }

            // Status message
            if let message = viewModel.statusMessage {
                HStack(spacing: DesignTokens.Spacing.iconText) {
                    Image(systemName: viewModel.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(viewModel.isSuccess ? .green : .red)

                    Text(message)
                        .font(DesignTokens.Typography.body)

                    Spacer()

                    Button(action: { viewModel.clearStatus() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(DesignTokens.Spacing.medium)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
                        .fill((viewModel.isSuccess ? Color.green : Color.red).opacity(0.1))
                )
            }

            // Info - minimal
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
                Text("ui.requirements".localized)
                    .font(DesignTokens.Typography.sectionTitle)

                Text("claudecode.requirement_sessionkey".localized)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(.secondary)

                Text("claudecode.requirement_restart".localized)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
            }
            .padding()
        }
    }

    // MARK: - Preview

    /// Generates a preview of what the statusline will look like based on current selections.
    private func generatePreview() -> String {
        var parts: [String] = []

        if viewModel.showDirectory {
            parts.append("claude-usage")
        }

        if viewModel.showBranch {
            parts.append("⎇ main")
        }

        if viewModel.showUsage {
            var usageText = "Usage: 29%"
            if viewModel.showProgressBar {
                if viewModel.showTimeMarker {
                    usageText += " ▓▓▓░░░│░░░"
                } else {
                    usageText += " ▓▓▓░░░░░░░"
                }
            }
            if viewModel.showResetTime {
                usageText += " → Reset: 14:30"
            }
            parts.append(usageText)
        }

        return parts.isEmpty ? "claudecode.preview_no_components".localized : parts.joined(separator: " │ ")
    }
}

// MARK: - Previews

#Preview {
    ClaudeCodeView()
        .frame(width: 520, height: 600)
}
