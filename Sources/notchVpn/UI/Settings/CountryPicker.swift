import SwiftUI

struct CountryPickerButton: View {
    @Binding var selection: Country
    let detected: Country?
    let onUserPick: (Country) -> Void

    @State private var presented = false

    var body: some View {
        Button {
            presented = true
        } label: {
            HStack(spacing: 10) {
                Text(selection.flag)
                    .font(.system(size: 18))
                VStack(alignment: .leading, spacing: 0) {
                    Text(selection.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if detected?.code == selection.code {
                        Text("Auto-detected")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.65))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(.white.opacity(0.18), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $presented, arrowEdge: .bottom) {
            CountryListPopover(
                currentCode: selection.code,
                onPick: { picked in
                    selection = picked
                    onUserPick(picked)
                    presented = false
                }
            )
            .frame(width: 320, height: 360)
        }
    }
}

private struct CountryListPopover: View {
    let currentCode: String
    let onPick: (Country) -> Void

    @State private var query: String = ""

    private static let all: [Country] = {
        Locale.Region.isoRegions
            .filter { $0.isISORegion && $0.identifier.count == 2 }
            .compactMap { region -> Country? in
                guard let name = Locale.current.localizedString(forRegionCode: region.identifier) else {
                    return nil
                }
                return Country(code: region.identifier.uppercased(), name: name)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }()

    private var filtered: [Country] {
        guard !query.isEmpty else { return Self.all }
        let q = query.lowercased()
        return Self.all.filter {
            $0.name.lowercased().contains(q) || $0.code.lowercased().contains(q)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 12))
                TextField("Search", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(filtered, id: \.code) { c in
                        Button {
                            onPick(c)
                        } label: {
                            HStack(spacing: 10) {
                                Text(c.flag).font(.system(size: 16))
                                Text(c.name)
                                    .font(.system(size: 13))
                                    .foregroundStyle(.primary)
                                Spacer()
                                if c.code == currentCode {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                        .font(.system(size: 12, weight: .semibold))
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}
