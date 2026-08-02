import AppKit
import Foundation

guard CommandLine.arguments.count == 3,
      let scale = Int(CommandLine.arguments[2]),
      scale == 1 || scale == 2 else {
    FileHandle.standardError.write(Data("Usage: generate-dmg-background.swift OUTPUT_PATH SCALE\n".utf8))
    exit(2)
}

let outputPath = CommandLine.arguments[1]
let width = 2560
let height = 1600
let initialWindowHeight: CGFloat = 520
let initialWindowCenterX: CGFloat = 459

func initialCanvasY(_ y: CGFloat) -> CGFloat {
    CGFloat(height) - initialWindowHeight + y
}

guard
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: width * scale,
        pixelsHigh: height * scale,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ),
    let context = NSGraphicsContext(bitmapImageRep: bitmap)
else {
    fatalError("Could not create the DMG background bitmap.")
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context

let retinaTransform = NSAffineTransform()
retinaTransform.scale(by: CGFloat(scale))
retinaTransform.concat()

let bounds = NSRect(x: 0, y: 0, width: width, height: height)
let background = NSGradient(colors: [
    NSColor(red: 0.19, green: 0.27, blue: 0.38, alpha: 1),
    NSColor(red: 0.37, green: 0.46, blue: 0.56, alpha: 1)
])!
background.draw(in: bounds, angle: -90)

let glow = NSGradient(colors: [
    NSColor(red: 0.18, green: 0.50, blue: 0.95, alpha: 0.20),
    NSColor.clear
])!
glow.draw(
    fromCenter: NSPoint(x: initialWindowCenterX, y: initialCanvasY(470)),
    radius: 0,
    toCenter: NSPoint(x: initialWindowCenterX, y: initialCanvasY(470)),
    radius: 360,
    options: [.drawsAfterEndingLocation]
)

func drawSSDPattern(at origin: NSPoint, rotation: CGFloat) {
    NSGraphicsContext.saveGraphicsState()

    let transform = NSAffineTransform()
    transform.translateX(by: origin.x, yBy: origin.y)
    transform.rotate(byDegrees: rotation)
    transform.concat()

    let strokeColor = NSColor.white.withAlphaComponent(0.085)
    let fillColor = NSColor.white.withAlphaComponent(0.018)

    let boardRect = NSRect(x: 0, y: 0, width: 92, height: 28)
    let board = NSBezierPath(roundedRect: boardRect, xRadius: 4, yRadius: 4)
    board.lineWidth = 1
    fillColor.setFill()
    strokeColor.setStroke()
    board.fill()
    board.stroke()

    let controller = NSBezierPath(roundedRect: NSRect(x: 13, y: 6, width: 17, height: 16), xRadius: 2, yRadius: 2)
    controller.lineWidth = 0.8
    controller.stroke()

    for chipX in stride(from: CGFloat(36), through: CGFloat(72), by: 13) {
        let chip = NSBezierPath(roundedRect: NSRect(x: chipX, y: 6, width: 10, height: 16), xRadius: 1.5, yRadius: 1.5)
        chip.lineWidth = 0.8
        chip.stroke()
    }

    let connector = NSBezierPath()
    connector.lineWidth = 0.8
    for pinY in stride(from: CGFloat(5), through: CGFloat(23), by: 4.5) {
        connector.move(to: NSPoint(x: 0, y: pinY))
        connector.line(to: NSPoint(x: 8, y: pinY))
    }
    connector.stroke()

    let mountingHole = NSBezierPath(ovalIn: NSRect(x: 82, y: 10, width: 7, height: 7))
    mountingHole.lineWidth = 0.8
    mountingHole.stroke()

    NSGraphicsContext.restoreGraphicsState()
}

let patternRows = Int(ceil(CGFloat(height) / 94)) + 2
let patternColumns = Int(ceil(CGFloat(width) / 145)) + 2
for row in 0..<patternRows {
    for column in 0..<patternColumns {
        let horizontalOffset: CGFloat = row.isMultiple(of: 2) ? 0 : 68
        drawSSDPattern(
            at: NSPoint(
                x: CGFloat(column) * 145 - 35 + horizontalOffset,
                y: CGFloat(row) * 94 - 8
            ),
            rotation: row.isMultiple(of: 2) ? -9 : 9
        )
    }
}

func drawCentered(_ text: String, y: CGFloat, attributes: [NSAttributedString.Key: Any]) {
    let attributed = NSAttributedString(string: text, attributes: attributes)
    let size = attributed.size()
    attributed.draw(at: NSPoint(x: initialWindowCenterX - size.width / 2, y: initialCanvasY(y)))
}

drawCentered(
    "Drag the app to Applications",
    y: 480,
    attributes: [
        .font: NSFont.systemFont(ofSize: 15, weight: .medium),
        .foregroundColor: NSColor.white.withAlphaComponent(0.72)
    ]
)

let arrow = NSBezierPath()
arrow.lineWidth = 3
arrow.lineCapStyle = .round
arrow.move(to: NSPoint(x: 374, y: initialCanvasY(390)))
arrow.line(to: NSPoint(x: 544, y: initialCanvasY(390)))
arrow.move(to: NSPoint(x: 531, y: initialCanvasY(401)))
arrow.line(to: NSPoint(x: 544, y: initialCanvasY(390)))
arrow.line(to: NSPoint(x: 531, y: initialCanvasY(379)))
NSColor.white.withAlphaComponent(0.50).setStroke()
arrow.stroke()

drawCentered(
    "Optional agent integrations",
    y: 300,
    attributes: [
        .font: NSFont.systemFont(ofSize: 12, weight: .medium),
        .foregroundColor: NSColor.white.withAlphaComponent(0.62)
    ]
)

NSGraphicsContext.restoreGraphicsState()

guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Could not encode the DMG background PNG.")
}

try pngData.write(to: URL(fileURLWithPath: outputPath), options: .atomic)
