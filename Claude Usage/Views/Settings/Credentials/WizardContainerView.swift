//
//  WizardContainerView.swift
//  Claude Usage
//
//  Shared wizard scaffold used by PersonalUsageView and APIBillingView.
//  Renders the step progress header, divider, and step content slot.
//

import SwiftUI

// MARK: - Step Progress Header

/// Renders a horizontal step indicator for a multi-step wizard.
///
/// - Parameters:
///   - currentStep: The 1-based index of the active step.
///   - totalSteps: Total number of steps in the wizard.
///   - stepTitles: Labels for each step (count must equal `totalSteps`).
struct WizardStepHeader: View {
    let currentStep: Int
    let totalSteps: Int
    let stepTitles: [String]

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.small) {
            ForEach(1...totalSteps, id: \.self) { step in
                let isCurrent = currentStep == step
                let isCompleted = currentStep > step

                HStack(spacing: DesignTokens.Spacing.extraSmall) {
                    ZStack {
                        Circle()
                            .fill(isCompleted ? Color.green : (isCurrent ? Color.accentColor : Color.secondary.opacity(0.2)))
                            .frame(width: 20, height: 20)

                        if isCompleted {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white)
                        } else {
                            Text("\(step)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(isCurrent ? .white : .secondary)
                        }
                    }

                    if isCurrent {
                        Text(stepTitles[step - 1])
                            .font(DesignTokens.Typography.body)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                }

                if step < totalSteps {
                    Rectangle()
                        .fill(isCompleted ? Color.green.opacity(0.3) : Color.secondary.opacity(0.2))
                        .frame(height: 1)
                }
            }
        }
    }
}

// MARK: - Wizard Container

/// A card container that provides the shared wizard scaffold:
/// configuration section title, step progress header, a divider,
/// and an animated content slot for the current step's view.
///
/// Usage:
/// ```swift
/// WizardContainerView(
///     configurationTitle: "wizard.configure".localized,
///     currentStep: wizardState.currentStep.rawValue,
///     stepTitles: stepTitles,
///     animationValue: wizardState.currentStep
/// ) {
///     EnterKeyStep(...)
/// }
/// ```
struct WizardContainerView<Content: View, AnimationValue: Hashable>: View {
    let configurationTitle: String
    let currentStep: Int
    let stepTitles: [String]
    let animationValue: AnimationValue
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Step Indicator Header
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.medium) {
                Text(configurationTitle)
                    .font(DesignTokens.Typography.sectionTitle)
                    .foregroundColor(.secondary)

                WizardStepHeader(
                    currentStep: currentStep,
                    totalSteps: stepTitles.count,
                    stepTitles: stepTitles
                )
            }
            .padding(DesignTokens.Spacing.cardPadding)
            .padding(.bottom, DesignTokens.Spacing.extraSmall)

            Divider()

            // Step Content
            Group {
                content()
            }
            .padding(DesignTokens.Spacing.cardPadding)
            .animation(.easeInOut(duration: 0.25), value: animationValue)
        }
        .background(DesignTokens.Colors.cardBackground)
        .cornerRadius(DesignTokens.Radius.card)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.card)
                .strokeBorder(DesignTokens.Colors.cardBorder, lineWidth: 1)
        )
    }
}
