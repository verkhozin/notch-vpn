import AppKit
import SwiftUI

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var currentCountry: Country?
    @Published var savedHome: Country?
}

struct OnboardingView: View {
    @ObservedObject var model: OnboardingViewModel
    let onSetHome: (Country) -> Void
    let onSkip: () -> Void

    @State private var selection: Country = Country(code: "US", name: "United States")
    @State private var didUserOverride: Bool = false
    @State private var didInitializeFromSaved: Bool = false

    @StateObject private var demoModel = NotchAnimationModel()
    @State private var demoTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            backgroundLayer
            VStack(spacing: 22) {
                header
                infographic
                features
                pickerSection
                ctaSection
            }
            .padding(.horizontal, 28)
            .padding(.top, 28)
            .padding(.bottom, 22)
        }
        .frame(width: 420)
        .onAppear {
            if !didInitializeFromSaved {
                didInitializeFromSaved = true
                if let saved = model.savedHome {
                    selection = saved
                    didUserOverride = true
                } else if let detected = model.currentCountry {
                    selection = detected
                }
            }
        }
        .onChange(of: model.currentCountry) { _, new in
            if !didUserOverride, let new {
                selection = new
            }
        }
    }

    private var backgroundLayer: some View {
        Color.black
            .ignoresSafeArea()
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("Welcome to notchVpn")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
            Text("Live VPN status, right under your notch.")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.75))
        }
    }

    private var infographic: some View {
        let metrics = NotchMorphMetrics.current(pillWidth: 240, pillHeight: 60)
        let screenSize = CGSize(width: 360, height: 180)

        return ZStack(alignment: .top) {
            screenWallpaper
                .frame(width: screenSize.width, height: screenSize.height)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(.white.opacity(0.08), lineWidth: 1)
                )

            NotchNotificationView(
                model: demoModel,
                metrics: metrics,
                panelSize: CGSize(width: screenSize.width, height: metrics.pillHeight + 32)
            )
        }
        .frame(width: screenSize.width, height: screenSize.height, alignment: .top)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onAppear { startDemoLoop() }
        .onDisappear { stopDemoLoop() }
    }

    private func startDemoLoop() {
        demoTask?.cancel()
        let events: [NotchEvent] = [
            .launch,
            .restore(CountryChangeEvent(
                from: Country(code: "US", name: "United States"),
                to: Country(code: "DE", name: "Germany"),
                timestamp: Date()
            )),
            .restore(CountryChangeEvent(
                from: Country(code: "DE", name: "Germany"),
                to: Country(code: "JP", name: "Japan"),
                timestamp: Date()
            )),
            .drop(previous: Country(code: "JP", name: "Japan")),
        ]
        demoTask = Task { @MainActor [demoModel] in
            var index = 0
            while !Task.isCancelled {
                demoModel.play(event: events[index], holdDuration: 1.4) {}
                try? await Task.sleep(for: .milliseconds(4400))
                if Task.isCancelled { return }
                index = (index + 1) % events.count
            }
        }
    }

    private func stopDemoLoop() {
        demoTask?.cancel()
        demoTask = nil
        demoModel.cancel()
    }

    @ViewBuilder
    private var screenWallpaper: some View {
        if let nsImage = NSImage(named: "Wallpaper") {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFill()
        } else {
            LinearGradient(
                colors: [
                    Color(red: 0.30, green: 0.45, blue: 0.85),
                    Color(red: 0.12, green: 0.18, blue: 0.40),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var features: some View {
        VStack(alignment: .leading, spacing: 12) {
            FeatureRow(
                icon: "wifi.slash",
                tint: Color(red: 1.0, green: 0.42, blue: 0.42),
                title: "Spot VPN drops",
                subtitle: "A red banner the moment your tunnel goes down."
            )
            FeatureRow(
                icon: "globe",
                tint: Color(red: 0.46, green: 1.0, blue: 0.76),
                title: "Country changes",
                subtitle: "Notice when your exit node moves to a new country."
            )
            FeatureRow(
                icon: "house.fill",
                tint: Color(red: 0.65, green: 0.88, blue: 1.0),
                title: "Set a home country",
                subtitle: "So we know when your IP returned to your real location."
            )
        }
    }

    private var pickerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("YOUR HOME COUNTRY")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.55))
                .tracking(1.2)
            CountryPickerButton(
                selection: $selection,
                detected: model.currentCountry,
                onUserPick: { _ in didUserOverride = true }
            )
        }
    }

    private var ctaSection: some View {
        VStack(spacing: 10) {
            Button {
                onSetHome(selection)
            } label: {
                Text("Set as home")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .tint(.accentColor)

            Button("Skip for now", action: onSkip)
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.6))
                .font(.system(size: 12))
        }
    }
}

private struct FeatureRow: View {
    let icon: String
    let tint: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}
