import SwiftUI

struct FlagBadge: View {
    let country: Country
    var size: CGFloat = 24

    var body: some View {
        HStack(spacing: 6) {
            Text(country.flag)
                .font(.system(size: size))
            Text(country.code.uppercased())
                .font(.system(size: size * 0.5, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }
}
