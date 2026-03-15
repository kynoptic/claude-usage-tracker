import SwiftUI

/// Step 2: Select organization from validated session key.
struct SelectOrgStepSetup: View {
    @Binding var wizardState: WizardState

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    SetupStepHeader(stepNumber: 2, title: "wizard.select_organization".localized)

                    Text("wizard.select_org_title".localized)
                        .font(.system(size: 13))

                    Text("wizard.select_org_subtitle".localized)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)

                    // Organization list with radio buttons
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(wizardState.testedOrganizations, id: \.uuid) { org in
                            HStack(spacing: 12) {
                                Image(systemName: wizardState.selectedOrgId == org.uuid ? "circle.fill" : "circle")
                                    .foregroundColor(wizardState.selectedOrgId == org.uuid ? .accentColor : .secondary)
                                    .font(.system(size: 14))

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(org.name)
                                        .font(.system(size: 13, weight: .medium))
                                    Text(org.uuid)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }

                                Spacer()
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(wizardState.selectedOrgId == org.uuid ? Color.accentColor.opacity(0.1) : Color.clear)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(wizardState.selectedOrgId == org.uuid ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                wizardState.selectedOrgId = org.uuid
                            }
                        }
                    }
                }
                .padding(32)
            }

            Divider()

            // Footer
            HStack {
                Button("common.back".localized) {
                    withAnimation {
                        wizardState.currentStep = .enterKey
                    }
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("common.next".localized) {
                    withAnimation {
                        wizardState.currentStep = .confirm
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(wizardState.selectedOrgId == nil)
            }
            .padding(20)
        }
        .onAppear {
            if wizardState.selectedOrgId == nil,
               let firstOrg = wizardState.testedOrganizations.first {
                wizardState.selectedOrgId = firstOrg.uuid
            }
        }
    }
}
