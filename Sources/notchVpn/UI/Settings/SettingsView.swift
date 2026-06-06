import SwiftUI

struct SettingsView: View {
    var body: some View {
        Form {
            Section("Polling") {
                LabeledContent("Strategy", value: "Adaptive backoff")
                LabeledContent("Interval", value: "30s → 5min")
            }
            Section("Privacy") {
                Text("notchVpn only stores the last known country code locally.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(width: 380, height: 220)
    }
}
