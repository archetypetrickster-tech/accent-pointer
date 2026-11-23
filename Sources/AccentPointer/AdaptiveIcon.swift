import AppKit

final class AdaptiveAppIcon {
    private var appearanceObserver: NSKeyValueObservation?
    private var displayedDark: Bool?
    init() {
        appearanceObserver = NSApp.observe(\.effectiveAppearance, options: [.initial, .new]) { [weak self] app, _ in
            DispatchQueue.main.async { self?.update(app.effectiveAppearance) }
        }
    }
    private func update(_ appearance: NSAppearance) {
        let dark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        guard displayedDark != dark else { return }
        let name = dark ? "AppIconDark" : "AppIcon"
        guard let url = Bundle.main.url(forResource: name, withExtension: "icns"), let image = NSImage(contentsOf: url) else { return }
        image.isTemplate = false
        NSApp.applicationIconImage = image
        displayedDark = dark
    }
}
