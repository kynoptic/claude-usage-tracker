import SwiftUI

/// Header section of the setup wizard with logo, title, and step progress indicator.
struct SetupWizardHeader: View {
    let currentStep: WizardStep

    var body: some View {
        VStack(spacing: 16) {
            // Logo and title
            HStack(spacing: 2) {
                Image("WizardLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)

                VStack(spacing: 8) {
                    Text("setup.welcome.title".localized)
                        .font(.system(size: 24, weight: .semibold))

                    Text("setup.welcome.subtitle".localized)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 32)

            // Step progress indicator
            HStack(spacing: 8) {
                SetupStepCircle(number: 1, isCurrent: currentStep == .enterKey, isCompleted: currentStep > .enterKey)
                SetupStepLine(isCompleted: currentStep > .enterKey)
                SetupStepCircle(number: 2, isCurrent: currentStep == .selectOrg, isCompleted: currentStep > .selectOrg)
                SetupStepLine(isCompleted: currentStep > .selectOrg)
                SetupStepCircle(number: 3, isCurrent: currentStep == .confirm, isCompleted: false)
                Spacer()
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 16)
        }
    }
}
