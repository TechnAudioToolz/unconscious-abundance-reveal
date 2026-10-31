// Draws the app icon (a waveform on a deep purple tile, with a gold sparkle) and writes
// Resources/AppIcon.png and Resources/AppIcon.icns.
//   swift make_icon.swift
// The tile sits on the macOS icon grid: an 824-point rounded square centred on a 1024 canvas, with a soft shadow.
import AppKit

let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
let tile = NSRect(x: 100, y: 100, width: 824, height: 824)
let shape = NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185)
NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
shadow.shadowOffset = NSSize(width: 0, height: -10)
shadow.shadowBlurRadius = 24
shadow.set()
NSColor(red: 0.18, green: 0.10, blue: 0.36, alpha: 1).setFill()
shape.fill()
NSGraphicsContext.restoreGraphicsState()
NSGradient(starting: NSColor(red: 0.42, green: 0.26, blue: 0.78, alpha: 1),
           ending: NSColor(red: 0.13, green: 0.07, blue: 0.30, alpha: 1))!.draw(in: shape, angle: -90)

func symbol(_ name: String, points: CGFloat, color: NSColor, in rect: NSRect) {
    let config = NSImage.SymbolConfiguration(pointSize: points, weight: .semibold)
        .applying(.init(paletteColors: [color]))
    let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)!.withSymbolConfiguration(config)!
    let fitted = image.size.width / image.size.height > rect.width / rect.height
        ? NSSize(width: rect.width, height: rect.width * image.size.height / image.size.width)
        : NSSize(width: rect.height * image.size.width / image.size.height, height: rect.height)
    image.draw(in: NSRect(x: rect.midX - fitted.width / 2, y: rect.midY - fitted.height / 2,
                          width: fitted.width, height: fitted.height))
}
symbol("waveform", points: 400, color: .white, in: NSRect(x: 230, y: 300, width: 564, height: 424))
symbol("sparkle", points: 200, color: NSColor(red: 1.0, green: 0.82, blue: 0.40, alpha: 1),
       in: NSRect(x: 640, y: 620, width: 180, height: 180))
image.unlockFocus()

let png = NSBitmapImageRep(data: image.tiffRepresentation!)!.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: "Resources/AppIcon.png"))

// The .icns: every size macOS asks for, through iconutil.
let iconset = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = points * scale
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
                                   samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                   colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
        NSGraphicsContext.restoreGraphicsState()
        let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
        try! rep.representation(using: .png, properties: [:])!.write(to: iconset.appendingPathComponent(name))
    }
}
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", "Resources/AppIcon.icns"]
try! iconutil.run()
iconutil.waitUntilExit()
print("Wrote Resources/AppIcon.png and Resources/AppIcon.icns")
