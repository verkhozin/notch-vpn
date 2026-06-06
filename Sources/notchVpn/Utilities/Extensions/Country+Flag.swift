import Foundation

extension Country {
    var flag: String {
        guard code.count == 2 else { return "🏳️" }
        let base: UInt32 = 127_397
        var emoji = ""
        for scalar in code.uppercased().unicodeScalars {
            if let v = UnicodeScalar(base + scalar.value) {
                emoji.unicodeScalars.append(v)
            }
        }
        return emoji.isEmpty ? "🏳️" : emoji
    }
}
