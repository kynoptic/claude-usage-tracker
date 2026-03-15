import SwiftUI

/// Smart, minimal, and professional popover interface
struct PopoverContentView: View {
    @ObservedObject var manager: MenuBarManager
    let onRefresh: () -> Void
    let onPreferences: () -> Void
    let onQuit: () -> Void

    @State private var isRefreshing = false
    @State private var showInsights = false
    @StateObject private var profileManager = ProfileManager.shared

    // Computed properties for multi-profile mode support
    private var displayUsage: ClaudeUsage {
        // In multi-profile mode, use the clicked profile's usage
        manager.clickedProfileUsage ?? manager.usage
    }

    private var displayAPIUsage: APIUsage? {
        manager.clickedProfileAPIUsage ?? manager.apiUsage
    }

    var body: some View {
        VStack(spacing: 0) {
            // Smart Header with Status and Profile Switcher
            SmartHeader(
                usage: displayUsage,
                status: manager.status,
                isRefreshing: isRefreshing,
                onRefresh: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isRefreshing = true
                    }
                    onRefresh()
                    Task {
                        try? await Task.sleep(nanoseconds: UInt64(1.0 * 1_000_000_000))
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isRefreshing = false
                        }
                    }
                },
                onManageProfiles: onPreferences,
                clickedProfileId: manager.clickedProfileId
            )

            // Intelligent Usage Dashboard
            SmartUsageDashboard(
                usage: displayUsage,
                apiUsage: displayAPIUsage,
                sessionContext: manager.pacingContext,
                isStale: manager.isStale,
                lastSuccessfulFetch: manager.lastSuccessfulFetch,
                lastRefreshError: manager.lastRefreshError,
                nextRetryDate: manager.nextRetryDate
            )

            // Contextual Insights
            if showInsights {
                ContextualInsights(usage: displayUsage)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
            }

            // Smart Footer with Actions
            SmartFooter(
                usage: displayUsage,
                status: manager.status,
                showInsights: $showInsights,
                onPreferences: onPreferences,
                onQuit: onQuit
            )
        }
        .frame(width: 280)
        .background(.regularMaterial)
    }
}
