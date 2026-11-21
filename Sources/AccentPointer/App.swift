import AppKit
import SwiftUI
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate {
    let preferences = Preferences()
    lazy var pointer = PointerOverlay(preferences: preferences)
    lazy var keyboard = KeyboardOverlay(preferences: preferences)
    lazy var input = InputMonitor(preferences: preferences, pointer: pointer, keyboard: keyboard)
    let hotkey = PauseHotkey()
    private var window: NSWindow?
    private var status: NSStatusItem?
    private var subscriptions = Set<AnyCancellable>()
    private var changeWork: DispatchWorkItem?
    private var stopping = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        let identifier = Bundle.main.bundleIdentifier ?? "ru.ninesquares.Accent"
        if NSRunningApplication.runningApplications(withBundleIdentifier: identifier).count > 1 {
            NSRunningApplication.runningApplications(withBundleIdentifier: identifier)
                .first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier })?
                .activate(options: [.activateAllWindows])
            NSApp.terminate(nil)
            return
        }
        buildApplicationMenu()
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        status = item
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        item.button?.setAccessibilityLabel("Акцент — управление эффектами")
        hotkey.onToggle = { [weak self] in self?.preferences.running.toggle() }
        preferences.hotkeyAvailable = hotkey.register()
        preferences.objectWillChange.sink { [weak self] in
            guard let self else { return }
            self.changeWork?.cancel()
            let work = DispatchWorkItem { [weak self] in self?.applyPreferences() }
            self.changeWork = work
            DispatchQueue.main.async(execute: work)
        }.store(in: &subscriptions)
        NotificationCenter.default.addObserver(self, selector: #selector(refreshDisplays), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(refreshInput), name: NSApplication.didBecomeActiveNotification, object: nil)
        input.start()
        applyPreferences()
        showSettings()
    }
    private func applyPreferences() {
        guard !stopping else { return }
        pointer.update()
        if !preferences.running || !preferences.keysEnabled { keyboard.hide() }
        input.refresh()
        let symbol = preferences.running ? "cursorarrow.rays" : "pause.circle"
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Акцент")
        image?.isTemplate = true
        status?.button?.image = image
        status?.button?.toolTip = preferences.running ? "Акцент включён · ⌃⌥P — пауза" : "Акцент на паузе · ⌃⌥P — включить"
    }
    @objc private func refreshDisplays() { pointer.update(); keyboard.hide() }
    @objc private func refreshInput() { input.refresh() }
    func menuWillOpen(_ menu: NSMenu) {
        menu.removeAllItems()
        let title = NSMenuItem(title: "Акцент", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        let toggle = NSMenuItem(title: preferences.running ? "Поставить на паузу" : "Включить эффекты", action: #selector(toggleRunning), keyEquivalent: preferences.hotkeyAvailable ? "p" : "")
        toggle.keyEquivalentModifierMask = [.control, .option]
        toggle.target = self
        menu.addItem(toggle)
        menu.addItem(.separator())
        for (title, action, enabled) in [
            ("Кольцо курсора", #selector(toggleRing), preferences.ringEnabled),
            ("Клики", #selector(toggleClicks), preferences.clicksEnabled),
            ("Сочетания клавиш", #selector(toggleKeys), preferences.keysEnabled)
        ] {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            item.target = self
            item.state = enabled ? .on : .off
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let settings = NSMenuItem(title: "Настройки…", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        let quit = NSMenuItem(title: "Выйти из «Акцента»", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }
    @objc private func toggleRunning() { preferences.running.toggle() }
    @objc private func toggleRing() { preferences.ringEnabled.toggle() }
    @objc private func toggleClicks() { preferences.clicksEnabled.toggle() }
    @objc private func toggleKeys() { preferences.keysEnabled.toggle() }
    @objc func showSettings() {
        if window == nil {
            let settings = SettingsView(preferences: preferences,
                requestPermission: { [weak self] in self?.input.requestPermission() },
                openPermissions: { [weak self] in self?.input.openPermissionSettings() },
                preview: { [weak self] in self?.previewEffects() },
                quit: { NSApp.terminate(nil) })
            let host = NSHostingView(rootView: settings)
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 774),
                             styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            w.title = "Акцент"
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.contentView = host
            w.contentMinSize = NSSize(width: 590, height: 660)
            w.contentMaxSize = NSSize(width: 820, height: 1000)
            w.isReleasedWhenClosed = false
            w.delegate = self
            w.setFrameAutosaveName("AccentSettings")
            if !w.setFrameUsingName("AccentSettings") { w.center() }
            if let screen = w.screen ?? NSScreen.main, w.frame.height > screen.visibleFrame.height {
                w.setFrame(NSRect(x: w.frame.minX, y: screen.visibleFrame.minY,
                    width: w.frame.width, height: screen.visibleFrame.height), display: false)
            }
            window = w
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    private func previewEffects() {
        guard preferences.running else { NSSound.beep(); return }
        if preferences.clicksEnabled { pointer.click(at: NSEvent.mouseLocation, right: false) }
        if preferences.keysEnabled { keyboard.show(["⇧", "⌘", "S"], preview: true) }
    }
    private func buildApplicationMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Об «Акценте»", action: #selector(about), keyEquivalent: "").target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Настройки…", action: #selector(showSettings), keyEquivalent: ",").target = self
        appMenu.addItem(withTitle: "Пауза / включить", action: #selector(toggleRunning), keyEquivalent: "").target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Скрыть «Акцент»", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: "Выйти из «Акцента»", action: #selector(quit), keyEquivalent: "q").target = self
        appItem.submenu = appMenu
        main.addItem(appItem)
        let windowItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Окно")
        windowMenu.addItem(withTitle: "Закрыть окно", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowItem.submenu = windowMenu
        main.addItem(windowItem)
        NSApp.mainMenu = main
    }
    @objc private func about() {
        NSApp.orderFrontStandardAboutPanel(options: [.applicationName: "Акцент", .applicationVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.2",
            .credits: NSAttributedString(string: "Курсор, клики и сочетания клавиш для лекций.\nРаботает локально, не сохраняет нажатия.")])
    }
    @objc private func quit() { NSApp.terminate(nil) }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showSettings(); return true }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationWillTerminate(_ notification: Notification) {
        stopping = true
        changeWork?.cancel()
        subscriptions.removeAll()
        input.stop()
        pointer.stop()
        keyboard.hide()
        hotkey.stop()
        if let status { NSStatusBar.system.removeStatusItem(status) }
    }
}

@main
struct AccentMain {
    static func main() {
        if CommandLine.arguments.contains("--self-test") { SelfTests.run(); return }
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
