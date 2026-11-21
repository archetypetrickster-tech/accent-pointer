import AppKit
import SwiftUI
import QuartzCore

final class OverlayPanel: NSPanel {
    init(size: NSSize) {
        super.init(contentRect: NSRect(origin: .zero, size: size),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        level = .init(rawValue: Int(CGWindowLevelForKey(.statusWindow)) + 1)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]
        if #available(macOS 14.0, *) { collectionBehavior.insert(.canJoinAllApplications) }
        animationBehavior = .none
        isExcludedFromWindowsMenu = true
        sharingType = .readOnly
        isMovable = false
    }
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class RingView: NSView {
    var radius: CGFloat = 25
    var stroke: CGFloat = 2.4
    var tint = NSColor.controlAccentColor
    var rightTint = NSColor.systemPurple
    var ringOpacity: CGFloat = 0.85
    var heldButton: Int? = nil
    override var isOpaque: Bool { false }
    override func draw(_ dirtyRect: NSRect) {
        let thickness = stroke + (heldButton == nil ? 0 : 1.1)
        let r = radius - (heldButton == nil ? 0 : 1.5)
        let rect = NSRect(x: bounds.midX - r, y: bounds.midY - r, width: r * 2, height: r * 2)
        let path = NSBezierPath(ovalIn: rect)
        // Two fine neutral outlines keep the unfilled ring readable on any background.
        NSColor.black.withAlphaComponent(0.27 * ringOpacity).setStroke()
        path.lineWidth = thickness + 2.0
        path.stroke()
        NSColor.white.withAlphaComponent(0.8 * ringOpacity).setStroke()
        path.lineWidth = thickness + 0.9
        path.stroke()
        (heldButton == 1 ? rightTint : tint).withAlphaComponent(ringOpacity).setStroke()
        path.lineWidth = thickness
        path.stroke()
    }
}

final class PointerOverlay {
    let panel = OverlayPanel(size: NSSize(width: 116, height: 116))
    private let ring = RingView(frame: NSRect(x: 0, y: 0, width: 116, height: 116))
    private let preferences: Preferences
    private var timer: Timer?
    private var lastPosition = NSPoint(x: -10000, y: -10000)
    private var lastMovement = CACurrentMediaTime()
    private var previousHeld: Int? = nil
    private var lastOpacity: CGFloat = -1
    private var ripples: [UUID: OverlayPanel] = [:]

    init(preferences: Preferences) {
        self.preferences = preferences
        panel.contentView = ring
    }
    func update() {
        ring.radius = preferences.radius
        ring.stroke = preferences.lineWidth
        ring.tint = preferences.tint.nsColor
        ring.rightTint = preferences.rightClickColor
        ring.needsDisplay = true
        if preferences.running && (preferences.ringEnabled || preferences.clicksEnabled) {
            if timer == nil {
                timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in self?.tick() }
                RunLoop.main.add(timer!, forMode: .common)
            }
            tick()
        } else {
            timer?.invalidate()
            timer = nil
            panel.orderOut(nil)
            clearRipples()
        }
        if !preferences.clicksEnabled { clearRipples() }
    }
    private func tick() {
        guard preferences.running else { return }
        let point = NSEvent.mouseLocation
        if point != lastPosition {
            lastPosition = point
            lastMovement = CACurrentMediaTime()
            panel.setFrameOrigin(NSPoint(x: point.x - 58, y: point.y - 58))
        }
        let buttons = NSEvent.pressedMouseButtons
        let held: Int? = preferences.clicksEnabled ? ((buttons & 1) != 0 ? 0 : ((buttons & 2) != 0 ? 1 : nil)) : nil
        let opacity = CGFloat(preferences.opacity) * (CACurrentMediaTime() - lastMovement > 1.7 && held == nil ? 0.65 : 1)
        if held != previousHeld || opacity != lastOpacity {
            previousHeld = held
            lastOpacity = opacity
            ring.heldButton = held
            ring.ringOpacity = opacity
            ring.needsDisplay = true
        }
        if preferences.ringEnabled {
            if !panel.isVisible { panel.orderFrontRegardless() }
        } else { panel.orderOut(nil) }
    }
    func click(at point: NSPoint, right: Bool, preview: Bool = false) {
        guard preview || (preferences.running && preferences.clicksEnabled) else { return }
        // Bound simultaneous windows even during a burst of clicks.
        if ripples.count >= 12, let id = ripples.keys.first { ripples.removeValue(forKey: id)?.close() }
        let id = UUID()
        let size: CGFloat = right ? 208 : 144
        let window = OverlayPanel(size: NSSize(width: size, height: size))
        window.setFrameOrigin(NSPoint(x: point.x - size / 2, y: point.y - size / 2))
        let view = NSView(frame: NSRect(x: 0, y: 0, width: size, height: size))
        view.wantsLayer = true
        let reduced = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if right, let layer = view.layer {
            ClickDroplets.add(to: layer, center: CGPoint(x: size / 2, y: size / 2),
                             radius: CGFloat(preferences.radius), color: preferences.rightClickColor,
                             reducedMotion: reduced)
            window.contentView = view
            ripples[id] = window
            window.orderFrontRegardless()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.62) { [weak self] in
                self?.ripples.removeValue(forKey: id)?.close()
            }
            return
        }
        let radius = min(64, CGFloat(preferences.radius) + 18)
        let radii = [radius]
        let shapes = radii.map { r -> CAShapeLayer in
            let shape = CAShapeLayer()
            shape.frame = view.bounds
            shape.path = CGPath(ellipseIn: CGRect(x: size / 2 - r, y: size / 2 - r,
                                                 width: r * 2, height: r * 2), transform: nil)
            shape.fillColor = nil
            shape.strokeColor = preferences.tint.nsColor.cgColor
            shape.lineWidth = 2
            shape.shadowColor = NSColor.black.cgColor
            shape.shadowOpacity = 0.18
            shape.shadowRadius = 1
            shape.shadowOffset = .zero
            view.layer?.addSublayer(shape)
            return shape
        }
        window.contentView = view
        ripples[id] = window
        window.orderFrontRegardless()
        for shape in shapes {
          if !reduced {
            let scale = CABasicAnimation(keyPath: "transform.scale")
            scale.fromValue = 0.45
            scale.toValue = 1
            scale.duration = 0.5
            scale.timingFunction = CAMediaTimingFunction(name: .easeOut)
            shape.add(scale, forKey: "scale")
          }
          let fade = CABasicAnimation(keyPath: "opacity")
          fade.fromValue = 0.9
          fade.toValue = 0
          fade.duration = reduced ? 0.25 : 0.5
          shape.opacity = 0
          shape.add(fade, forKey: "fade")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { [weak self] in
            self?.ripples.removeValue(forKey: id)?.close()
        }
    }
    private func clearRipples() {
        ripples.values.forEach { $0.close() }
        ripples.removeAll()
    }
    func stop() { timer?.invalidate(); timer = nil; panel.orderOut(nil); clearRipples() }
}

enum ClickDroplets {
    static let count = 8
    static let duration: CFTimeInterval = 0.56

    static func path(length: CGFloat, width: CGFloat) -> CGPath {
        // Rounded leading edge, tapered trailing edge; the long axis points outward.
        let path = CGMutablePath()
        let tail = CGPoint(x: -length * 0.55, y: 0)
        let head = CGPoint(x: length * 0.45, y: 0)
        path.move(to: tail)
        path.addCurve(to: head,
                      control1: CGPoint(x: -length * 0.08, y: -width * 0.65),
                      control2: CGPoint(x: length * 0.45, y: -width * 0.65))
        path.addCurve(to: tail,
                      control1: CGPoint(x: length * 0.45, y: width * 0.65),
                      control2: CGPoint(x: -length * 0.08, y: width * 0.65))
        path.closeSubpath()
        return path
    }

    static func add(to layer: CALayer, center: CGPoint, radius: CGFloat,
                    color: NSColor, reducedMotion: Bool) {
        let variation: [CGFloat] = [0, 7, -3, 4, 1, -5, 6, -1]
        for index in 0..<count {
            let angle = CGFloat(index) * .pi / 4 + .pi / 8
            let startRadius = max(16, radius * 0.8)
            let endRadius = radius + 26 + variation[index]
            let start = CGPoint(x: center.x + cos(angle) * startRadius,
                                y: center.y + sin(angle) * startRadius)
            let end = CGPoint(x: center.x + cos(angle) * endRadius,
                              y: center.y + sin(angle) * endRadius)
            let drop = CAShapeLayer()
            drop.path = path(length: 11 + CGFloat(index % 3), width: 5.5)
            drop.position = reducedMotion ? start : end
            drop.transform = CATransform3DMakeRotation(angle, 0, 0, 1)
            drop.fillColor = color.cgColor
            drop.strokeColor = NSColor.white.withAlphaComponent(0.4).cgColor
            drop.lineWidth = 0.5
            drop.shadowColor = NSColor.black.cgColor
            drop.shadowOpacity = 0.18
            drop.shadowRadius = 1
            drop.shadowOffset = .zero
            drop.opacity = 0
            layer.addSublayer(drop)

            if !reducedMotion {
                let motion = CABasicAnimation(keyPath: "position")
                motion.fromValue = NSValue(point: start)
                motion.toValue = NSValue(point: end)
                motion.duration = duration
                motion.timingFunction = CAMediaTimingFunction(controlPoints: 0.15, 0.7, 0.25, 1)
                drop.add(motion, forKey: "flight")
                let scale = CAKeyframeAnimation(keyPath: "transform.scale")
                scale.values = [0.55, 1, 0.45]
                scale.keyTimes = [0, 0.2, 1]
                scale.duration = duration
                drop.add(scale, forKey: "size")
            }
            let fade = CAKeyframeAnimation(keyPath: "opacity")
            fade.values = [0.9, 0.85, 0]
            fade.keyTimes = [0, 0.25, 1]
            fade.duration = reducedMotion ? 0.25 : duration
            drop.add(fade, forKey: "fade")
        }
    }
}

struct ChordView: View {
    let keys: [String]
    let repetitions: Int
    var compact = false
    var body: some View {
        HStack(spacing: compact ? 5 : 7) {
            ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
                Text(key)
                    .font(.system(size: compact ? 18 : 28, weight: .medium, design: .rounded))
                    .frame(minWidth: compact ? 27 : 38, minHeight: compact ? 31 : 44)
                    .padding(.horizontal, compact ? 3 : 5)
                    .background(.primary.opacity(0.065), in: RoundedRectangle(cornerRadius: compact ? 7 : 9))
                    .overlay(RoundedRectangle(cornerRadius: compact ? 7 : 9).strokeBorder(.primary.opacity(0.08)))
            }
            if repetitions > 1 {
                Text("×\(repetitions)").font(.system(size: 15, weight: .medium)).foregroundStyle(.secondary).padding(.leading, 4)
            }
        }
        .padding(compact ? 11 : 14)
        .modifier(SystemGlass(cornerRadius: compact ? 18 : 23))
        .overlay(RoundedRectangle(cornerRadius: compact ? 18 : 23, style: .continuous)
            .strokeBorder(.white.opacity(0.25), lineWidth: 0.75))
        .shadow(color: .black.opacity(0.12), radius: 12, y: 5)
        .padding(16)
    }
}

private struct SystemGlass: ViewModifier {
    let cornerRadius: CGFloat
    @ViewBuilder func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            content.background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }
}

final class KeyboardOverlay {
    private let preferences: Preferences
    private var panel: OverlayPanel?
    private var dismiss: DispatchWorkItem?
    private var lastKeys: [String] = []
    private var lastTime: TimeInterval = 0
    private var repetitions = 1
    private var generation = 0
    init(preferences: Preferences) { self.preferences = preferences }
    func show(_ keys: [String], preview: Bool = false) {
        guard preview || (preferences.running && preferences.keysEnabled) else { return }
        dismiss?.cancel()
        generation += 1
        let now = CACurrentMediaTime()
        repetitions = keys == lastKeys && now - lastTime < 0.8 ? min(99, repetitions + 1) : 1
        lastKeys = keys
        lastTime = now
        let content = NSHostingView(rootView: ChordView(keys: keys, repetitions: repetitions))
        let fitting = content.fittingSize
        let size = NSSize(width: max(100, fitting.width), height: max(90, fitting.height))
        let window = panel ?? OverlayPanel(size: size)
        panel = window
        window.contentView = content
        window.setContentSize(size)
        let point = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }) ?? NSScreen.main
        if let screen { window.setFrameOrigin(preferences.hudPosition.origin(in: screen.visibleFrame, size: size)) }
        window.alphaValue = 1
        window.orderFrontRegardless()
        let current = generation
        let task = DispatchWorkItem { [weak self] in
            guard let self, current == self.generation else { return }
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : 0.16
                window.animator().alphaValue = 0
            }, completionHandler: { [weak self] in
                guard self?.generation == current else { return }
                window.orderOut(nil)
            })
        }
        dismiss = task
        DispatchQueue.main.asyncAfter(deadline: .now() + preferences.hudDuration, execute: task)
    }
    func hide() { generation += 1; dismiss?.cancel(); dismiss = nil; panel?.orderOut(nil); lastKeys = []; repetitions = 1 }
}
