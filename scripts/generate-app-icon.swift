#!/usr/bin/env swift

import AppKit
import Foundation

let arguments = CommandLine.arguments

guard arguments.count == 2 else {
    FileHandle.standardError.write(Data("Usage: generate-app-icon.swift <output-iconset>\n".utf8))
    exit(2)
}

let outputURL = URL(fileURLWithPath: arguments[1], isDirectory: true)
let fileManager = FileManager.default

try fileManager.createDirectory(at: outputURL, withIntermediateDirectories: true)

let sizes: [(name: String, pixels: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for size in sizes {
    let image = NSImage(size: NSSize(width: size.pixels, height: size.pixels))
    image.lockFocus()

    let rect = NSRect(x: 0, y: 0, width: size.pixels, height: size.pixels)
    let radius = CGFloat(size.pixels) * 0.22
    let background = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

    NSColor(calibratedRed: 0.07, green: 0.08, blue: 0.10, alpha: 1).setFill()
    background.fill()

    let inset = CGFloat(size.pixels) * 0.16
    let keyRect = rect.insetBy(dx: inset, dy: inset)
    let keyPath = NSBezierPath(roundedRect: keyRect, xRadius: radius * 0.42, yRadius: radius * 0.42)
    NSColor(calibratedWhite: 0.96, alpha: 1).setFill()
    keyPath.fill()

    let innerInset = CGFloat(size.pixels) * 0.055
    let innerRect = keyRect.insetBy(dx: innerInset, dy: innerInset)
    let innerPath = NSBezierPath(roundedRect: innerRect, xRadius: radius * 0.28, yRadius: radius * 0.28)
    NSColor(calibratedRed: 0.13, green: 0.15, blue: 0.18, alpha: 1).setFill()
    innerPath.fill()

    let fontSize = CGFloat(size.pixels) * 0.32
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedSystemFont(ofSize: fontSize, weight: .bold),
        .foregroundColor: NSColor(calibratedWhite: 0.96, alpha: 1)
    ]
    let text = "⌘"
    let textSize = text.size(withAttributes: attributes)
    let textPoint = NSPoint(
        x: rect.midX - textSize.width / 2,
        y: rect.midY - textSize.height / 2 + CGFloat(size.pixels) * 0.015
    )
    text.draw(at: textPoint, withAttributes: attributes)

    image.unlockFocus()

    guard
        let tiffData = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiffData),
        let pngData = bitmap.representation(using: .png, properties: [:])
    else {
        FileHandle.standardError.write(Data("Could not render \(size.name)\n".utf8))
        exit(1)
    }

    try pngData.write(to: outputURL.appendingPathComponent(size.name))
}
