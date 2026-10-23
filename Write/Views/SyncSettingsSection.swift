import SwiftUI

struct SyncSettingsSection: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var history: PracticeHistoryStore
    @EnvironmentObject private var sync: HistorySyncController

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("iCloud")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.leading, 4)

            Toggle("Sync practice history", isOn: $settings.iCloudSyncEnabled)
                .accessibilityIdentifier("iCloudSyncEnabled")
                .padding(16)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            if settings.iCloudSyncEnabled {
                statusText
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                    .accessibilityIdentifier("iCloudSyncStatus")
            }
        }
        .onChange(of: settings.iCloudSyncEnabled) { enabled in
            sync.sceneBecameActive(history: history, enabled: enabled)
        }
    }

    private var statusText: Text {
        switch sync.status {
        case .synced(let date):
            return Text("Synced \(date, format: .relative(presentation: .named))")
        case .syncing:
            return Text("Syncing…")
        case .accountUnavailable:
            return Text("iCloud account unavailable")
        case .notSynced:
            return Text("Not synced yet")
        }
    }
}
