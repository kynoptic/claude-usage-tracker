//
//  StatusFeedbackBox.swift
//  Claude Usage
//
//  Shared status feedback component for wizard and settings views
//

import SwiftUI

/// Reusable status feedback component with icon, color, and message
struct StatusFeedbackBox: View {
    let message: String
    let status: StatusFeedbackType

    enum StatusFeedbackType {
        case success
        case error

        var color: Color {
            switch self {
            case .success: return .green
            case .error: return .red
            }
        }

        var icon: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .error: return "exclamationmark.triangle.fill"
            }
        }
    }

    var body: some View {
        HStack(spacing: Spacing.iconTextSpacing) {
            Image(systemName: status.icon)
                .foregroundColor(status.color)
                .font(.system(size: 14))

            Text(message)
                .font(Typography.label)
                .foregroundColor(.primary)

            Spacer()
        }
        .padding(Spacing.inputPadding)
        .background(
            RoundedRectangle(cornerRadius: Spacing.radiusMedium)
                .fill(status.color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: Spacing.radiusMedium)
                        .strokeBorder(status.color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

#Preview {
    VStack(spacing: 12) {
        StatusFeedbackBox(message: "Setup completed successfully", status: .success)
        StatusFeedbackBox(message: "Invalid session key", status: .error)
    }
    .padding()
}
