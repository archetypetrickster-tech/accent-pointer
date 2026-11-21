import AppKit
import SwiftUI
import Combine

enum PointerTint: String, CaseIterable, Identifiable {
    case system, blue, mint, violet, white
    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: return "Системный"
        case .blue: return "Синий"
        case .mint: return "Мятный"
        case .violet: return "Фиолетовый"
        case .white: return "Белый"
        }
    }
    var nsColor: NSColor {
        switch self {
        case .system: return .controlAccentColor
        case .blue: return .systemBlue
        case .mint: return .systemMint
        case .violet: return .systemPurple
        case .white: return .white
        }
    }
    var color: Color { Color(nsColor: nsColor) }
}

enum HUDPosition: String, CaseIterable, Identifiable {
    case bottomCenter, bottomLeft, bottomRight, topCenter
    var id: String { rawValue }
    var title: String {
        switch self {
        case .bottomCenter: return "Снизу по центру"
        case .bottomLeft: return "Снизу слева"
        case .bottomRight: return "Снизу справа"
        case .topCenter: return "Сверху по центру"
        }
    }
    func origin(in frame: NSRect, size: NSSize) -> NSPoint {
        let margin: CGFloat = 32
        let x: CGFloat
        switch self {
        case .bottomLeft: x = frame.minX + margin
        case .bottomRight: x = frame.maxX - size.width - margin
        default: x = frame.midX - size.width / 2
        }
        let y = self == .topCenter
            ? frame.maxY - size.height - margin
            : frame.minY + margin
        return NSPoint(x: max(frame.minX, min(x, frame.maxX - size.width)),
                       y: max(frame.minY, min(y, frame.maxY - size.height)))
    }
}

final class Preferences: ObservableObject {
    private let defaults: UserDefaults
    @Published var running = true
    @Published var ringEnabled: Bool { didSet { save() } }
    @Published var clicksEnabled: Bool { didSet { save() } }
    @Published var keysEnabled: Bool { didSet { save() } }
    @Published var radius: Double { didSet { save() } }
    @Published var lineWidth: Double { didSet { save() } }
    @Published var opacity: Double { didSet { save() } }
    @Published var tint: PointerTint { didSet { save() } }
    @Published var leftClickHex: String? { didSet { save() } }
    @Published var rightClickHex: String? { didSet { save() } }
    @Published var hudPosition: HUDPosition { didSet { save() } }
    @Published var hudDuration: Double { didSet { save() } }
    @Published var hotkeyAvailable = true
    @Published var inputAllowed = false
    @Published var inputWorking = false
    @Published var secureInput = false

    var leftClickColor: NSColor { Self.color(from: leftClickHex) ?? tint.nsColor }

    var rightClickColor: NSColor {
        if let custom = Self.color(from: rightClickHex) { return custom }
        guard let left = tint.nsColor.usingColorSpace(.deviceRGB),
              let purple = NSColor.systemPurple.usingColorSpace(.deviceRGB) else { return .systemPurple }
        let distance = pow(left.redComponent - purple.redComponent, 2)
            + pow(left.greenComponent - purple.greenComponent, 2)
            + pow(left.blueComponent - purple.blueComponent, 2)
        return distance < 0.16 ? .systemOrange : .systemPurple
    }

    static func hex(from color: NSColor) -> String? {
        guard let rgb = color.usingColorSpace(.sRGB) else { return nil }
        func byte(_ component: CGFloat) -> Int { Int((min(1, max(0, component)) * 255).rounded()) }
        return String(format: "%02X%02X%02X", byte(rgb.redComponent), byte(rgb.greenComponent), byte(rgb.blueComponent))
    }

    private static func color(from hex: String?) -> NSColor? {
        guard let hex, hex.count == 6, let value = UInt32(hex, radix: 16) else { return nil }
        return NSColor(srgbRed: CGFloat((value >> 16) & 255) / 255,
                       green: CGFloat((value >> 8) & 255) / 255,
                       blue: CGFloat(value & 255) / 255, alpha: 1)
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: ["ring": true, "clicks": true, "keys": true,
            "radius": 25.0, "lineWidth": 2.4, "opacity": 0.85,
            "tint": "system", "hudPosition": "bottomCenter", "hudDuration": 1.6])
        ringEnabled = defaults.bool(forKey: "ring")
        clicksEnabled = defaults.bool(forKey: "clicks")
        keysEnabled = defaults.bool(forKey: "keys")
        radius = min(48, max(16, defaults.double(forKey: "radius")))
        lineWidth = min(5, max(1.5, defaults.double(forKey: "lineWidth")))
        opacity = min(1, max(0.35, defaults.double(forKey: "opacity")))
        tint = PointerTint(rawValue: defaults.string(forKey: "tint") ?? "") ?? .system
        leftClickHex = defaults.string(forKey: "leftClickColor")
        rightClickHex = defaults.string(forKey: "rightClickColor")
        hudPosition = HUDPosition(rawValue: defaults.string(forKey: "hudPosition") ?? "") ?? .bottomCenter
        hudDuration = min(4, max(0.6, defaults.double(forKey: "hudDuration")))
    }
    private func save() {
        defaults.set(ringEnabled, forKey: "ring")
        defaults.set(clicksEnabled, forKey: "clicks")
        defaults.set(keysEnabled, forKey: "keys")
        defaults.set(radius, forKey: "radius")
        defaults.set(lineWidth, forKey: "lineWidth")
        defaults.set(opacity, forKey: "opacity")
        defaults.set(tint.rawValue, forKey: "tint")
        defaults.set(leftClickHex, forKey: "leftClickColor")
        defaults.set(rightClickHex, forKey: "rightClickColor")
        defaults.set(hudPosition.rawValue, forKey: "hudPosition")
        defaults.set(hudDuration, forKey: "hudDuration")
    }
}
