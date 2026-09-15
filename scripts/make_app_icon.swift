import AppKit
import Foundation

struct IconEntry {
    let code: String
    let logicalSize: Int
    let scale: Int

    var pixelSize: Int {
        logicalSize * scale
    }

    var fileName: String {
        scale == 1 ? "icon_\(logicalSize)x\(logicalSize).png" : "icon_\(logicalSize)x\(logicalSize)@2x.png"
    }
}

let arguments = CommandLine.arguments
guard arguments.count == 4 else {
    fputs("Usage: make_app_icon.swift <input-logo.png> <output-icon.icns> <output-rounded-logo.png>\n", stderr)
    exit(64)
}

let inputURL = URL(fileURLWithPath: arguments[1])
let outputIconURL = URL(fileURLWithPath: arguments[2])
let outputRoundedLogoURL = URL(fileURLWithPath: arguments[3])

guard let source = NSImage(contentsOf: inputURL) else {
    fputs("Could not load input image: \(inputURL.path)\n", stderr)
    exit(66)
}

let entries = [
    IconEntry(code: "ic04", logicalSize: 16, scale: 1),
    IconEntry(code: "ic11", logicalSize: 16, scale: 2),
    IconEntry(code: "ic05", logicalSize: 32, scale: 1),
    IconEntry(code: "ic12", logicalSize: 32, scale: 2),
    IconEntry(code: "ic07", logicalSize: 128, scale: 1),
    IconEntry(code: "ic13", logicalSize: 128, scale: 2),
    IconEntry(code: "ic08", logicalSize: 256, scale: 1),
    IconEntry(code: "ic14", logicalSize: 256, scale: 2),
    IconEntry(code: "ic09", logicalSize: 512, scale: 1),
    IconEntry(code: "ic10", logicalSize: 512, scale: 2)
]

let fileManager = FileManager.default
let iconsetURL = outputIconURL
    .deletingPathExtension()
    .appendingPathExtension("iconset")

try? fileManager.removeItem(at: iconsetURL)
try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

func roundedPNG(size: Int) -> Data? {
    let imageSize = NSSize(width: size, height: size)
    let image = NSImage(size: imageSize)
    image.lockFocus()

    NSColor.clear.setFill()
    NSRect(origin: .zero, size: imageSize).fill()

    let radius = CGFloat(size) * 0.224
    let rect = NSRect(origin: .zero, size: imageSize)
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).addClip()
    source.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)

    image.unlockFocus()

    guard
        let tiffData = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiffData)
    else {
        return nil
    }

    return bitmap.representation(using: .png, properties: [:])
}

for entry in entries {
    guard let png = roundedPNG(size: entry.pixelSize) else {
        fputs("Could not render \(entry.fileName)\n", stderr)
        exit(70)
    }
    try png.write(to: iconsetURL.appendingPathComponent(entry.fileName))
}

if let roundedLogo = roundedPNG(size: 512) {
    try roundedLogo.write(to: outputRoundedLogoURL)
}

var chunks = [Data]()
for entry in entries {
    let png = try Data(contentsOf: iconsetURL.appendingPathComponent(entry.fileName))
    var chunk = Data(entry.code.utf8)
    chunk.append(UInt32(png.count + 8).bigEndianData)
    chunk.append(png)
    chunks.append(chunk)
}

let totalLength = 8 + chunks.reduce(0) { $0 + $1.count }
var iconData = Data("icns".utf8)
iconData.append(UInt32(totalLength).bigEndianData)
chunks.forEach { iconData.append($0) }
try iconData.write(to: outputIconURL)

try? fileManager.removeItem(at: iconsetURL)

private extension UInt32 {
    var bigEndianData: Data {
        var value = self.bigEndian
        return Data(bytes: &value, count: MemoryLayout<UInt32>.size)
    }
}
