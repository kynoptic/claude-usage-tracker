//
//  ProfileMenuContent.swift
//  Claude Usage
//
//  Shared menu content for ProfileSwitcherCompact and ProfileSwitcherBar.
//

import SwiftUI

/// Reusable profile list and "Manage Profiles" action for Menu-based profile switchers.
///
/// Both `ProfileSwitcherCompact` and `ProfileSwitcherBar` share the same ForEach
/// logic for listing profiles with badges and a trailing "Manage Profiles" button.
/// This view encapsulates that shared content so changes propagate to both.
struct ProfileMenuContent: View {
    let profiles: [Profile]
    let activeProfileId: UUID?
    let onActivate: (UUID) -> Void
    let onManageProfiles: () -> Void

    var body: some View {
        ForEach(profiles) { profile in
            Button(action: {
                onActivate(profile.id)
            }) {
                HStack(spacing: 8) {
                    // Profile icon
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 12))

                    // Profile name
                    Text(profile.name)
                        .font(.system(size: 12, weight: .medium))

                    Spacer()

                    // Badges
                    HStack(spacing: 4) {
                        // CLI Account badge
                        if profile.hasCliAccount {
                            Image(systemName: "terminal.fill")
                                .font(.system(size: 9))
                                .foregroundColor(.green)
                        }

                        // Claude.ai badge
                        if profile.claudeSessionKey != nil {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 9))
                                .foregroundColor(.blue)
                        }

                        // Active indicator
                        if profile.id == activeProfileId {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 6))
                                .foregroundColor(.accentColor)
                        }
                    }
                }
            }
        }

        Divider()

        Button(action: onManageProfiles) {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 12))
                Text("popover.manage_profiles".localized)
                    .font(.system(size: 12, weight: .medium))
            }
        }
    }
}
