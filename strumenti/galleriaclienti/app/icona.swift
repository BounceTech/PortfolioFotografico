// Disegna l'icona 1024x1024 dell'app (usato da build.sh)
import AppKit
let s: CGFloat = 1024
let img = NSImage(size: NSSize(width: s, height: s))
img.lockFocus()
let r = NSRect(x: 100, y: 100, width: 824, height: 824)
NSGradient(starting: NSColor(calibratedWhite: 0.20, alpha: 1), ending: NSColor(calibratedWhite: 0.07, alpha: 1))!
    .draw(in: NSBezierPath(roundedRect: r, xRadius: 185, yRadius: 185), angle: -90)
let cfg = NSImage.SymbolConfiguration(pointSize: 430, weight: .light)
    .applying(NSImage.SymbolConfiguration(paletteColors: [NSColor(calibratedRed: 0.93, green: 0.88, blue: 0.80, alpha: 1)]))
if let sym = NSImage(systemSymbolName: "photo.on.rectangle.angled", accessibilityDescription: nil)?.withSymbolConfiguration(cfg) {
    let z = sym.size
    sym.draw(in: NSRect(x: (s - z.width) / 2, y: (s - z.height) / 2, width: z.width, height: z.height))
}
img.unlockFocus()
let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
