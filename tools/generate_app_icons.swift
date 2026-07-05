#!/usr/bin/env swift

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

private let canvas = 1024
private let size = CGFloat(canvas)
private let colorSpace = CGColorSpaceCreateDeviceRGB()

private enum IconVariant {
    case standard
    case dark
    case tinted
}

private struct IconPalette {
    let backgroundStart: CGColor
    let backgroundEnd: CGColor
    let glow: CGColor
    let track: CGColor
    let innerStart: CGColor
    let innerEnd: CGColor
    let hand: CGColor
    let handSecondary: CGColor
    let segments: [CGColor]
    let tokenHighlights: [CGColor]
}

private func color(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
    let red = CGFloat((hex >> 16) & 0xff) / 255
    let green = CGFloat((hex >> 8) & 0xff) / 255
    let blue = CGFloat(hex & 0xff) / 255
    return CGColor(colorSpace: colorSpace, components: [red, green, blue, alpha])!
}

private func palette(for variant: IconVariant) -> IconPalette {
    switch variant {
    case .standard:
        return IconPalette(
            backgroundStart: color(0x10131b),
            backgroundEnd: color(0x243541),
            glow: color(0x27d6c2, alpha: 0.22),
            track: color(0x222a33),
            innerStart: color(0x121721),
            innerEnd: color(0x1e2731),
            hand: color(0xfffbf2),
            handSecondary: color(0xb8fff4, alpha: 0.82),
            segments: [
                color(0xff7a2f),
                color(0xffc44f),
                color(0x22d0ad),
                color(0x4da3ff)
            ],
            tokenHighlights: [
                color(0xffb14f),
                color(0xffdd77),
                color(0x62f2d5),
                color(0x87c7ff)
            ]
        )
    case .dark:
        return IconPalette(
            backgroundStart: color(0x05070b),
            backgroundEnd: color(0x16242d),
            glow: color(0x32f5dc, alpha: 0.28),
            track: color(0x1a2028),
            innerStart: color(0x070a0f),
            innerEnd: color(0x18212a),
            hand: color(0xffffff),
            handSecondary: color(0xc7fff6, alpha: 0.9),
            segments: [
                color(0xff8a3d),
                color(0xffd65f),
                color(0x36e6c4),
                color(0x66b6ff)
            ],
            tokenHighlights: [
                color(0xffbd63),
                color(0xffe088),
                color(0x75ffdf),
                color(0xa6d7ff)
            ]
        )
    case .tinted:
        return IconPalette(
            backgroundStart: color(0x101114),
            backgroundEnd: color(0x20242a),
            glow: color(0xffffff, alpha: 0.12),
            track: color(0x2a2f36),
            innerStart: color(0x111318),
            innerEnd: color(0x24282f),
            hand: color(0xffffff),
            handSecondary: color(0xd8dde4, alpha: 0.88),
            segments: [
                color(0xf7f8fa),
                color(0xdfe4ea),
                color(0xcbd3dc),
                color(0xb7c0ca)
            ],
            tokenHighlights: [
                color(0xffffff),
                color(0xecf0f4),
                color(0xd9dfe6),
                color(0xc7cfd8)
            ]
        )
    }
}

private func radians(_ degrees: CGFloat) -> CGFloat {
    degrees * .pi / 180
}

private func drawGradientBackground(in context: CGContext, palette: IconPalette) {
    let gradient = CGGradient(
        colorsSpace: colorSpace,
        colors: [palette.backgroundStart, palette.backgroundEnd] as CFArray,
        locations: [0, 1]
    )!
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0, y: size),
        end: CGPoint(x: size, y: 0),
        options: []
    )

    let radial = CGGradient(
        colorsSpace: colorSpace,
        colors: [palette.glow, color(0x000000, alpha: 0)] as CFArray,
        locations: [0, 1]
    )!
    context.drawRadialGradient(
        radial,
        startCenter: CGPoint(x: size * 0.68, y: size * 0.72),
        startRadius: 32,
        endCenter: CGPoint(x: size * 0.58, y: size * 0.54),
        endRadius: 620,
        options: []
    )
}

private func strokeArc(
    in context: CGContext,
    center: CGPoint,
    radius: CGFloat,
    lineWidth: CGFloat,
    startDegrees: CGFloat,
    endDegrees: CGFloat,
    strokeColor: CGColor,
    shadow: Bool = false
) {
    context.saveGState()
    if shadow {
        context.setShadow(
            offset: CGSize(width: 0, height: -18),
            blur: 34,
            color: color(0x000000, alpha: 0.42)
        )
    }
    context.setStrokeColor(strokeColor)
    context.setLineWidth(lineWidth)
    context.setLineCap(.round)
    context.addArc(
        center: center,
        radius: radius,
        startAngle: radians(startDegrees),
        endAngle: radians(endDegrees),
        clockwise: true
    )
    context.strokePath()
    context.restoreGState()
}

private func fillCircle(
    in context: CGContext,
    center: CGPoint,
    radius: CGFloat,
    fill: CGColor,
    shadowBlur: CGFloat = 0,
    shadowAlpha: CGFloat = 0
) {
    let rect = CGRect(
        x: center.x - radius,
        y: center.y - radius,
        width: radius * 2,
        height: radius * 2
    )
    context.saveGState()
    if shadowBlur > 0 {
        context.setShadow(
            offset: CGSize(width: 0, height: -12),
            blur: shadowBlur,
            color: color(0x000000, alpha: shadowAlpha)
        )
    }
    context.setFillColor(fill)
    context.fillEllipse(in: rect)
    context.restoreGState()
}

private func drawToken(
    in context: CGContext,
    center: CGPoint,
    radius: CGFloat,
    baseColor: CGColor,
    highlightColor: CGColor
) {
    let rect = CGRect(
        x: center.x - radius,
        y: center.y - radius,
        width: radius * 2,
        height: radius * 2
    )
    fillCircle(
        in: context,
        center: center,
        radius: radius,
        fill: baseColor,
        shadowBlur: 22,
        shadowAlpha: 0.42
    )

    context.saveGState()
    context.addEllipse(in: rect.insetBy(dx: 7, dy: 7))
    context.clip()
    let shine = CGGradient(
        colorsSpace: colorSpace,
        colors: [highlightColor, baseColor] as CFArray,
        locations: [0, 1]
    )!
    context.drawRadialGradient(
        shine,
        startCenter: CGPoint(x: center.x - radius * 0.32, y: center.y + radius * 0.38),
        startRadius: 4,
        endCenter: center,
        endRadius: radius * 1.15,
        options: []
    )
    context.restoreGState()

    context.saveGState()
    context.setStrokeColor(color(0xffffff, alpha: 0.33))
    context.setLineWidth(5)
    context.strokeEllipse(in: rect.insetBy(dx: 5, dy: 5))
    context.restoreGState()
}

private func drawInnerDial(in context: CGContext, center: CGPoint, palette: IconPalette) {
    let radius: CGFloat = 170
    let rect = CGRect(
        x: center.x - radius,
        y: center.y - radius,
        width: radius * 2,
        height: radius * 2
    )

    context.saveGState()
    context.setShadow(
        offset: CGSize(width: 0, height: -14),
        blur: 24,
        color: color(0x000000, alpha: 0.34)
    )
    context.setFillColor(palette.innerStart)
    context.fillEllipse(in: rect)
    context.restoreGState()

    context.saveGState()
    context.addEllipse(in: rect)
    context.clip()
    let gradient = CGGradient(
        colorsSpace: colorSpace,
        colors: [palette.innerEnd, palette.innerStart] as CFArray,
        locations: [0, 1]
    )!
    context.drawRadialGradient(
        gradient,
        startCenter: CGPoint(x: center.x - 48, y: center.y + 72),
        startRadius: 6,
        endCenter: center,
        endRadius: radius,
        options: []
    )
    context.restoreGState()

    context.saveGState()
    context.setStrokeColor(color(0xffffff, alpha: 0.1))
    context.setLineWidth(4)
    context.strokeEllipse(in: rect.insetBy(dx: 3, dy: 3))
    context.restoreGState()
}

private func drawClockHands(in context: CGContext, center: CGPoint, palette: IconPalette) {
    context.saveGState()
    context.setShadow(
        offset: CGSize(width: 0, height: -8),
        blur: 16,
        color: color(0x000000, alpha: 0.28)
    )
    context.setLineCap(.round)

    context.setStrokeColor(palette.handSecondary)
    context.setLineWidth(23)
    context.move(to: center)
    context.addLine(to: CGPoint(x: center.x + 112, y: center.y + 38))
    context.strokePath()

    context.setStrokeColor(palette.hand)
    context.setLineWidth(32)
    context.move(to: center)
    context.addLine(to: CGPoint(x: center.x, y: center.y + 124))
    context.strokePath()
    context.restoreGState()

    fillCircle(
        in: context,
        center: center,
        radius: 42,
        fill: palette.hand,
        shadowBlur: 16,
        shadowAlpha: 0.24
    )
    fillCircle(
        in: context,
        center: center,
        radius: 20,
        fill: color(0x141922, alpha: 0.82)
    )
}

private func renderIcon(variant: IconVariant, outputURL: URL) throws {
    let bitmapInfo = CGImageAlphaInfo.noneSkipLast.rawValue
    guard let context = CGContext(
        data: nil,
        width: canvas,
        height: canvas,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: bitmapInfo
    ) else {
        throw NSError(domain: "IconRender", code: 1)
    }

    let palette = palette(for: variant)
    let center = CGPoint(x: size / 2, y: size / 2)

    drawGradientBackground(in: context, palette: palette)

    let ringRadius: CGFloat = 304
    let ringWidth: CGFloat = 116
    strokeArc(
        in: context,
        center: center,
        radius: ringRadius,
        lineWidth: ringWidth,
        startDegrees: 0,
        endDegrees: -360,
        strokeColor: palette.track,
        shadow: true
    )

    let glowWidth = ringWidth + 20
    let arcDefinitions: [(CGFloat, CGFloat, CGColor)] = [
        (98, -5, palette.segments[0]),
        (-18, -104, palette.segments[1]),
        (-118, -204, palette.segments[2]),
        (-218, -305, palette.segments[3])
    ]

    for (start, end, segmentColor) in arcDefinitions {
        strokeArc(
            in: context,
            center: center,
            radius: ringRadius,
            lineWidth: glowWidth,
            startDegrees: start,
            endDegrees: end,
            strokeColor: segmentColor.copy(alpha: 0.18)!,
            shadow: false
        )
        strokeArc(
            in: context,
            center: center,
            radius: ringRadius,
            lineWidth: ringWidth,
            startDegrees: start,
            endDegrees: end,
            strokeColor: segmentColor,
            shadow: false
        )
    }

    let tokenAngles: [CGFloat] = [52, -40, -138, 146]
    for (index, angle) in tokenAngles.enumerated() {
        let tokenRadius: CGFloat = index == 0 ? 48 : 42
        let orbit: CGFloat = 314
        let tokenCenter = CGPoint(
            x: center.x + cos(radians(angle)) * orbit,
            y: center.y + sin(radians(angle)) * orbit
        )
        drawToken(
            in: context,
            center: tokenCenter,
            radius: tokenRadius,
            baseColor: palette.segments[index],
            highlightColor: palette.tokenHighlights[index]
        )
    }

    drawInnerDial(in: context, center: center, palette: palette)
    drawClockHands(in: context, center: center, palette: palette)

    guard let image = context.makeImage(),
          let destination = CGImageDestinationCreateWithURL(
            outputURL as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
          ) else {
        throw NSError(domain: "IconRender", code: 2)
    }

    CGImageDestinationAddImage(destination, image, [:] as CFDictionary)
    if !CGImageDestinationFinalize(destination) {
        throw NSError(domain: "IconRender", code: 3)
    }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iosIconSet = root.appendingPathComponent("Visual Timer/Assets.xcassets/AppIcon.appiconset")
let watchIconSet = root.appendingPathComponent("Visual Timer Watch Watch App/Assets.xcassets/AppIcon.appiconset")

try renderIcon(
    variant: .standard,
    outputURL: iosIconSet.appendingPathComponent("AppIcon-1024.png")
)
try renderIcon(
    variant: .dark,
    outputURL: iosIconSet.appendingPathComponent("AppIcon-dark-1024.png")
)
try renderIcon(
    variant: .tinted,
    outputURL: iosIconSet.appendingPathComponent("AppIcon-tinted-1024.png")
)
try renderIcon(
    variant: .standard,
    outputURL: watchIconSet.appendingPathComponent("AppIcon-watch-1024.png")
)

print("Generated Turn Timer app icons.")
