import AppKit

let target = CommandLine.arguments[1]
let image = NSImage(size: NSSize(width: 1024, height: 1024))
image.lockFocus()
let background = NSBezierPath(roundedRect: NSRect(x: 64, y: 64, width: 896, height: 896), xRadius: 205, yRadius: 205)
NSGradient(colors: [NSColor(calibratedRed: 0.96, green: 0.98, blue: 1, alpha: 1),
                    NSColor(calibratedRed: 0.77, green: 0.85, blue: 0.95, alpha: 1)])!.draw(in: background, angle: -80)
NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = NSColor.systemBlue.withAlphaComponent(0.18)
shadow.shadowBlurRadius = 36
shadow.shadowOffset = NSSize(width: 0, height: -12)
shadow.set()
let halo = NSBezierPath(ovalIn: NSRect(x: 238, y: 238, width: 548, height: 548))
halo.lineWidth = 28
NSColor.white.withAlphaComponent(0.9).setStroke()
halo.stroke()
halo.lineWidth = 17
NSColor.systemBlue.withAlphaComponent(0.85).setStroke()
halo.stroke()
NSGraphicsContext.restoreGraphicsState()
let cursor = NSBezierPath()
cursor.move(to: NSPoint(x: 445, y: 654))
cursor.line(to: NSPoint(x: 445, y: 326))
cursor.line(to: NSPoint(x: 517, y: 402))
cursor.line(to: NSPoint(x: 576, y: 274))
cursor.line(to: NSPoint(x: 635, y: 302))
cursor.line(to: NSPoint(x: 573, y: 431))
cursor.line(to: NSPoint(x: 681, y: 438))
cursor.close()
NSColor.white.setStroke()
cursor.lineWidth = 19
cursor.lineJoinStyle = .round
cursor.stroke()
NSColor(calibratedWhite: 0.13, alpha: 1).setFill()
cursor.fill()
image.unlockFocus()
try FileManager.default.createDirectory(atPath: target, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
        NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 2 ? "@2x" : ""
        let path = "\(target)/icon_\(size)x\(size)\(suffix).png"
        try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
    }
}
