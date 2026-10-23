import AppKit

let root = URL(fileURLWithPath: CommandLine.arguments[1])
let iconset = root.appendingPathComponent("AppIcon.iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for factor in [1, 2] {
        let pixels = size * factor
        let image = NSImage(size: NSSize(width: pixels, height: pixels))
        image.lockFocus()
        let scale = Double(pixels) / 1024
        let transform = NSAffineTransform(); transform.scale(by: scale); transform.concat()
        NSColor(calibratedRed: 0.13, green: 0.15, blue: 0.13, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 70, y: 70, width: 884, height: 884), xRadius: 205, yRadius: 205).fill()
        let ring = NSBezierPath(ovalIn: NSRect(x: 245, y: 245, width: 534, height: 534))
        ring.lineWidth = 44
        NSColor(calibratedWhite: 1, alpha: 0.12).setStroke(); ring.stroke()
        let arc = NSBezierPath()
        arc.appendArc(withCenter: NSPoint(x: 512, y: 512), radius: 267, startAngle: 90, endAngle: -180, clockwise: true)
        arc.lineWidth = 44; arc.lineCapStyle = .round
        NSColor(calibratedRed: 0.95, green: 0.55, blue: 0.42, alpha: 1).setStroke(); arc.stroke()
        let text = "d" as NSString
        let font = NSFont.systemFont(ofSize: 330, weight: .light)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor(calibratedWhite: 0.96, alpha: 1)]
        let textSize = text.size(withAttributes: attributes)
        text.draw(at: NSPoint(x: (1024 - textSize.width) / 2, y: (1024 - textSize.height) / 2 + 8), withAttributes: attributes)
        image.unlockFocus()
        let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
        let suffix = factor == 2 ? "@2x" : ""
        try bitmap.representation(using: .png, properties: [:])!.write(to: iconset.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
    }
}

// ICNS is a big-endian chunk container. Pack PNG representations directly so
// building doesn't depend on the system IconServices daemon being available.
func bigEndian(_ value: Int) -> Data {
    var value = UInt32(value).bigEndian
    return withUnsafeBytes(of: &value) { Data($0) }
}
var chunks = Data()
for (kind, name) in [("ic07", "128x128"), ("ic08", "256x256"), ("ic09", "512x512"), ("ic10", "512x512@2x"), ("ic11", "16x16@2x"), ("ic12", "32x32@2x"), ("ic13", "128x128@2x"), ("ic14", "256x256@2x")] {
    let png = try Data(contentsOf: iconset.appendingPathComponent("icon_\(name).png"))
    chunks.append(Data(kind.utf8)); chunks.append(bigEndian(png.count + 8)); chunks.append(png)
}
var icns = Data("icns".utf8)
icns.append(bigEndian(chunks.count + 8)); icns.append(chunks)
try icns.write(to: root.appendingPathComponent("AppIcon.icns"))
