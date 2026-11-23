import AppKit

let target = CommandLine.arguments[1]
let dark = CommandLine.arguments.contains("--dark")
let image = NSImage(size: NSSize(width: 1024, height: 1024))
image.lockFocus()
let background = NSBezierPath(roundedRect: NSRect(x: 64, y: 64, width: 896, height: 896), xRadius: 245, yRadius: 245)
NSColor(calibratedWhite: dark ? 0.14 : 0.925, alpha: 1).setFill()
background.fill()
NSColor(calibratedWhite: dark ? 0.26 : 0.86, alpha: 1).setStroke()
background.lineWidth = 12
background.stroke()
// The same native symbol used in the app header and the user's reference.
let configuration = NSImage.SymbolConfiguration(pointSize: 450, weight: .medium)
    .applying(NSImage.SymbolConfiguration(paletteColors: [dark
        ? NSColor(srgbRed: 0.24, green: 0.62, blue: 1, alpha: 1) : NSColor.systemBlue]))
if let cursor = NSImage(systemSymbolName: "cursorarrow.rays", accessibilityDescription: nil)?
    .withSymbolConfiguration(configuration) {
    let ratio = cursor.size.width / cursor.size.height
    let height: CGFloat = 452
    let width = height * ratio
    cursor.draw(in: NSRect(x: (1024 - width) / 2, y: (1024 - height) / 2,
                          width: width, height: height))
}
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
