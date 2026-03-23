import SwiftUI

struct AppAccent {
    struct Option: Identifiable, Hashable {
        let id: String
        let name: String
        let color: Color

        func hash(into hasher: inout Hasher) { hasher.combine(id) }
        static func == (lhs: Option, rhs: Option) -> Bool { lhs.id == rhs.id }
    }

    static let options: [Option] = [
        Option(id: "red", name: "Last.fm Red", color: Color(red: 0.84, green: 0.06, blue: 0.03)),
        Option(id: "purple", name: "Vinyl Purple", color: .purple),
        Option(id: "blue", name: "Bluetooth Blue", color: .blue),
        Option(id: "green", name: "Spotify Green", color: Color(red: 0.12, green: 0.84, blue: 0.38)),
        Option(id: "orange", name: "Warm Analog", color: .orange),
        Option(id: "teal", name: "Teal", color: .teal),
        Option(id: "indigo", name: "Indigo", color: .indigo),
        Option(id: "pink", name: "Rose", color: .pink),
        Option(id: "gold", name: "Gold", color: Color(red: 0.85, green: 0.7, blue: 0.3)),
        Option(id: "white", name: "Monochrome", color: Color(white: 0.85)),
    ]

    static func color(for name: String) -> Color {
        options.first(where: { $0.id == name })?.color ?? Color(red: 0.84, green: 0.06, blue: 0.03)
    }

    static var current: Color {
        let name = UserDefaults.standard.string(forKey: "accentColorName") ?? "red"
        return color(for: name)
    }
}

private struct AccentColorKey: EnvironmentKey {
    static let defaultValue: Color = Color(red: 0.84, green: 0.06, blue: 0.03)
}

extension EnvironmentValues {
    var appAccent: Color {
        get { self[AccentColorKey.self] }
        set { self[AccentColorKey.self] = newValue }
    }
}
