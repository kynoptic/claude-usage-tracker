//
//  SelectOrgStepView.swift
//  Claude Usage
//
//  Created by Claude Code on 2026-03-15.
//

import SwiftUI

/// Generic organization picker step used in both Personal and API billing wizards.
struct SelectOrgStepView<Org: OrganizationIdentifiable>: View {
    let organizations: [Org]
    @Binding var selectedId: String?
    let onBack: () -> Void
    let onNext: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("wizard.select_organization".localized)
                    .font(.system(size: 13, weight: .medium))
                Text("wizard.choose_organization".localized)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            // Organization list
            VStack(alignment: .leading, spacing: 8) {
                ForEach(organizations) { org in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedId = org.idString
                        }
                    }) {
                        HStack(spacing: 10) {
                            // Radio button
                            ZStack {
                                Circle()
                                    .strokeBorder(
                                        selectedId == org.idString
                                            ? Color.accentColor
                                            : Color.secondary.opacity(0.3),
                                        lineWidth: 1.5
                                    )
                                    .frame(width: 16, height: 16)

                                if selectedId == org.idString {
                                    Circle()
                                        .fill(Color.accentColor)
                                        .frame(width: 8, height: 8)
                                }
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text(org.displayName)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.primary)
                                Text(org.idString)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            if selectedId == org.idString {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .padding(10)
                        .background(
                            selectedId == org.idString
                                ? Color.accentColor.opacity(0.06)
                                : Color(nsColor: .controlBackgroundColor).opacity(0.3)
                        )
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(
                                    selectedId == org.idString
                                        ? Color.accentColor.opacity(0.3)
                                        : Color.secondary.opacity(0.15),
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            // Navigation buttons
            HStack(spacing: 10) {
                Button(action: {
                    withAnimation { onBack() }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11))
                        Text("common.back".localized)
                            .font(.system(size: 12))
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)

                Spacer()

                Button(action: {
                    withAnimation { onNext() }
                }) {
                    HStack(spacing: 6) {
                        Text("common.next".localized)
                            .font(.system(size: 12))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11))
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(selectedId == nil)
            }
        }
        .onAppear {
            if selectedId == nil, let firstOrg = organizations.first {
                selectedId = firstOrg.idString
            }
        }
    }
}
