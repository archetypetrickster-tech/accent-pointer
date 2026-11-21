import AppKit

enum SelfTests {
    static func run() {
        var count = 0
        func check(_ condition: @autoclosure () -> Bool, _ label: String) {
            guard condition() else { fputs("FAIL: \(label)\n", stderr); exit(1) }
            count += 1
        }
        check(ChordFormatter.format(keyCode: 0, flags: []) == nil, "ordinary typing is hidden")
        check(ChordFormatter.format(keyCode: 0, flags: .maskShift) == nil, "capital letters are hidden")
        check(ChordFormatter.format(keyCode: 8, flags: .maskCommand) == ["⌘", "C"], "command C")
        check(ChordFormatter.format(keyCode: 1, flags: [.maskCommand, .maskShift]) == ["⇧", "⌘", "S"], "modifier ordering")
        check(ChordFormatter.format(keyCode: 35, flags: [.maskControl, .maskAlternate]) == nil, "pause shortcut stays hidden")
        check(ChordFormatter.format(keyCode: 56, flags: .maskShift) == nil, "modifier-only events stay hidden")
        check(ChordFormatter.format(keyCode: 123, flags: []) == nil, "unmodified navigation is hidden")
        check(ChordFormatter.format(keyCode: 123, flags: .maskAlternate) == ["⌥", "←"], "modified navigation")
        check(ChordFormatter.format(keyCode: 122, flags: []) == ["F1"], "function keys")
        check(ChordFormatter.format(keyCode: 49, flags: .maskCommand) == ["⌘", "Space"], "space chord")
        check(ChordFormatter.format(keyCode: 999, flags: .maskCommand) == nil, "unknown key is hidden")
        for frame in [NSRect(x: 0, y: 0, width: 1440, height: 900),
                      NSRect(x: -1920, y: -200, width: 1920, height: 1080),
                      NSRect(x: 1440, y: 900, width: 1280, height: 800)] {
            for position in HUDPosition.allCases {
                let size = NSSize(width: 350, height: 104)
                let origin = position.origin(in: frame, size: size)
                check(frame.contains(NSRect(origin: origin, size: size)), "HUD is inside its display")
            }
        }
        let suite = "ru.ninesquares.Accent.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let first = Preferences(defaults: defaults)
        check(first.tint == .system && first.ringEnabled, "system accent defaults")
        first.radius = 32
        first.hudPosition = .topCenter
        first.keysEnabled = false
        let restored = Preferences(defaults: defaults)
        check(restored.radius == 32 && restored.hudPosition == .topCenter && !restored.keysEnabled, "settings persist")
        print("PASS: \(count) checks (shortcut filtering, display geometry, saved settings)")
    }
}
