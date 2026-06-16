import AppKit

enum MenuBarIcon {
    static func make() -> NSImage {
        let size = NSSize(width: 19, height: 18)
        let image = NSImage(size: size)

        image.lockFocus()

        NSColor.black.setFill()
        NSColor.black.setStroke()

        let keyRect = NSRect(x: 1.5, y: 2.5, width: 16, height: 13)
        let keyPath = NSBezierPath(roundedRect: keyRect, xRadius: 3.2, yRadius: 3.2)
        keyPath.lineWidth = 1.7
        keyPath.stroke()

        let rightAccent = NSBezierPath()
        rightAccent.move(to: NSPoint(x: 14.1, y: 5.2))
        rightAccent.line(to: NSPoint(x: 14.1, y: 12.8))
        rightAccent.lineWidth = 1.4
        rightAccent.lineCapStyle = .round
        rightAccent.stroke()

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 8.8, weight: .semibold),
            .foregroundColor: NSColor.black
        ]
        let symbol = "⌘"
        let symbolSize = symbol.size(withAttributes: attributes)
        symbol.draw(
            at: NSPoint(
                x: 5.7 - symbolSize.width / 2,
                y: 8.9 - symbolSize.height / 2
            ),
            withAttributes: attributes
        )

        let dotPath = NSBezierPath(ovalIn: NSRect(x: 11.3, y: 8.1, width: 1.8, height: 1.8))
        dotPath.fill()

        image.unlockFocus()
        image.isTemplate = true
        return image
    }
}
