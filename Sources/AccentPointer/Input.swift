import AppKit
import Carbon

enum ChordFormatter {
    // Conventional Latin shortcut labels remain readable with a Cyrillic input source.
    static let names: [Int: String] = [
        0:"A", 1:"S", 2:"D", 3:"F", 4:"H", 5:"G", 6:"Z", 7:"X", 8:"C", 9:"V", 11:"B",
        12:"Q", 13:"W", 14:"E", 15:"R", 16:"Y", 17:"T", 18:"1", 19:"2", 20:"3", 21:"4",
        22:"6", 23:"5", 24:"=", 25:"9", 26:"7", 27:"−", 28:"8", 29:"0", 30:"]", 31:"O",
        32:"U", 33:"[", 34:"I", 35:"P", 37:"L", 38:"J", 39:"’", 40:"K", 41:";", 42:"\\",
        43:",", 44:"/", 45:"N", 46:"M", 47:".", 48:"⇥", 49:"Space", 50:"`", 51:"⌫",
        36:"↩", 53:"esc", 65:".", 67:"×", 69:"+", 71:"Clear", 75:"÷", 76:"↩", 78:"−",
        81:"=", 82:"0", 83:"1", 84:"2", 85:"3", 86:"4", 87:"5", 88:"6", 89:"7", 91:"8", 92:"9",
        64:"F17", 79:"F18", 80:"F19", 90:"F20", 96:"F5", 97:"F6", 98:"F7", 99:"F3",
        100:"F8", 101:"F9", 103:"F11", 105:"F13", 106:"F16", 107:"F14", 109:"F10",
        111:"F12", 113:"F15", 114:"Help", 115:"↖", 116:"⇞", 117:"⌦", 118:"F4", 119:"↘",
        120:"F2", 121:"⇟", 122:"F1", 123:"←", 124:"→", 125:"↓", 126:"↑"
    ]
    static func format(keyCode: Int, flags: CGEventFlags) -> [String]? {
        guard let key = names[keyCode] else { return nil }
        let command = flags.contains(.maskCommand)
        let control = flags.contains(.maskControl)
        let option = flags.contains(.maskAlternate)
        let shift = flags.contains(.maskShift)
        // The application's own pause shortcut should never flash on the lecture screen.
        if keyCode == 35 && control && option && !command && !shift { return nil }
        let functionKey = key.hasPrefix("F") && Int(key.dropFirst()) != nil
        guard command || control || option || functionKey else { return nil }
        var parts: [String] = []
        if control { parts.append("⌃") }
        if option { parts.append("⌥") }
        if shift { parts.append("⇧") }
        if command { parts.append("⌘") }
        parts.append(key)
        return parts
    }
}

final class InputMonitor {
    private let preferences: Preferences
    private let pointer: PointerOverlay
    private let keyboard: KeyboardOverlay
    private var globalMouse: Any?
    private var localMouse: Any?
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var permissionTimer: Timer?
    private var requestPending = false
    private var retryAfter: Date = .distantPast

    init(preferences: Preferences, pointer: PointerOverlay, keyboard: KeyboardOverlay) {
        self.preferences = preferences
        self.pointer = pointer
        self.keyboard = keyboard
    }
    func start() {
        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown]
        globalMouse = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] in self?.mouse($0) }
        localMouse = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            self?.mouse(event)
            return event
        }
        permissionTimer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.refresh() }
        RunLoop.main.add(permissionTimer!, forMode: .common)
        refresh()
    }
    private func mouse(_ event: NSEvent) {
        let point: NSPoint
        if let cg = event.cgEvent, let primary = NSScreen.screens.first {
            point = NSPoint(x: cg.location.x, y: primary.frame.maxY - cg.location.y)
        } else { point = NSEvent.mouseLocation }
        pointer.click(at: point, right: event.type == .rightMouseDown)
    }
    func requestPermission() {
        requestPending = true
        let alreadyAllowed = CGPreflightListenEventAccess()
        if !alreadyAllowed { _ = CGRequestListenEventAccess() }
        if alreadyAllowed || !CGPreflightListenEventAccess() { openPermissionSettings() }
        refresh()
    }
    func openPermissionSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }
    func refresh() {
        let allowed = CGPreflightListenEventAccess()
        if preferences.inputAllowed != allowed { preferences.inputAllowed = allowed }
        let secure = IsSecureEventInputEnabled()
        if preferences.secureInput != secure { preferences.secureInput = secure }
        if secure { keyboard.hide() }
        if allowed && preferences.running && preferences.keysEnabled {
            if tap == nil && Date() >= retryAfter { createTap() }
            if let tap, !CGEvent.tapIsEnabled(tap: tap) { CGEvent.tapEnable(tap: tap, enable: true) }
            if requestPending && tap != nil { requestPending = false }
        } else {
            stopTap()
            keyboard.hide()
        }
        let working = tap != nil && allowed
        if preferences.inputWorking != working { preferences.inputWorking = working }
    }
    private func createTap() {
        let mask = CGEventMask(1) << CGEventType.keyDown.rawValue
        let callback: CGEventTapCallBack = { _, type, event, info in
            guard let info else { return Unmanaged.passUnretained(event) }
            let owner = Unmanaged<InputMonitor>.fromOpaque(info).takeUnretainedValue()
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = owner.tap, owner.preferences.running && owner.preferences.keysEnabled {
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
                return Unmanaged.passUnretained(event)
            }
            guard type == .keyDown, owner.preferences.running, owner.preferences.keysEnabled,
                  !IsSecureEventInputEnabled() else { return Unmanaged.passUnretained(event) }
            let code = Int(event.getIntegerValueField(.keyboardEventKeycode))
            if let keys = ChordFormatter.format(keyCode: code, flags: event.flags) { owner.keyboard.show(keys) }
            return Unmanaged.passUnretained(event)
        }
        guard let created = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .tailAppendEventTap,
            options: .listenOnly, eventsOfInterest: mask, callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()) else {
            retryAfter = Date().addingTimeInterval(5)
            return
        }
        tap = created
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, created, 0)
        if let source { CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes) }
        CGEvent.tapEnable(tap: created, enable: true)
    }
    private func stopTap() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        source = nil
    }
    func stop() {
        if let globalMouse { NSEvent.removeMonitor(globalMouse) }
        if let localMouse { NSEvent.removeMonitor(localMouse) }
        globalMouse = nil
        localMouse = nil
        permissionTimer?.invalidate()
        permissionTimer = nil
        stopTap()
    }
}

final class PauseHotkey {
    private var hotkey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private var down = false
    var onToggle: (() -> Void)?
    func register() -> Bool {
        var types = [EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
                     EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))]
        let result = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let context, let event else { return OSStatus(eventNotHandledErr) }
            let owner = Unmanaged<PauseHotkey>.fromOpaque(context).takeUnretainedValue()
            if GetEventKind(event) == UInt32(kEventHotKeyReleased) { owner.down = false }
            else if !owner.down { owner.down = true; owner.onToggle?() }
            return noErr
        }, types.count, &types, Unmanaged.passUnretained(self).toOpaque(), &handler)
        guard result == noErr else { return false }
        let id = EventHotKeyID(signature: 0x41434E54, id: 1)
        return RegisterEventHotKey(UInt32(kVK_ANSI_P), UInt32(controlKey | optionKey), id,
                                   GetApplicationEventTarget(), 0, &hotkey) == noErr
    }
    func stop() {
        if let hotkey { UnregisterEventHotKey(hotkey) }
        if let handler { RemoveEventHandler(handler) }
        hotkey = nil
        handler = nil
    }
    deinit { stop() }
}
