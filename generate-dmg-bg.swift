import CoreGraphics
import CoreText
import ImageIO
import Foundation

let scale = 2
let w = 660 * scale
let h = 400 * scale

let cs = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(
    data: nil, width: w, height: h,
    bitsPerComponent: 8, bytesPerRow: w * 4,
    space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { exit(1) }

// Solid dark background
ctx.setFillColor(red: 0.09, green: 0.09, blue: 0.14, alpha: 1.0)
ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))

// Icon positions in 2x CG coords
let iconY: CGFloat = CGFloat(h) - 180.0 * 2.0  // 440
let appX: CGFloat = 180.0 * 2.0                 // 360
let appsX: CGFloat = 480.0 * 2.0                // 960

// Simple straight arrow between icons
let startX = appX + 150
let endX = appsX - 150

ctx.saveGState()
ctx.setStrokeColor(red: 1, green: 1, blue: 1, alpha: 0.25)
ctx.setLineWidth(3.0)
ctx.setLineCap(.round)
ctx.move(to: CGPoint(x: startX, y: iconY))
ctx.addLine(to: CGPoint(x: endX - 20, y: iconY))
ctx.strokePath()

// Arrowhead
ctx.setFillColor(red: 1, green: 1, blue: 1, alpha: 0.25)
ctx.move(to: CGPoint(x: endX, y: iconY))
ctx.addLine(to: CGPoint(x: endX - 28, y: iconY + 16))
ctx.addLine(to: CGPoint(x: endX - 28, y: iconY - 16))
ctx.closePath()
ctx.fillPath()
ctx.restoreGState()

// Save
guard let image = ctx.makeImage() else { exit(1) }
let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "dmg-background.png"
let url = URL(fileURLWithPath: outPath) as CFURL
guard let dest = CGImageDestinationCreateWithURL(url, "public.png" as CFString, 1, nil) else { exit(1) }
CGImageDestinationAddImage(dest, image, [kCGImagePropertyDPIWidth: 144, kCGImagePropertyDPIHeight: 144] as CFDictionary)
CGImageDestinationFinalize(dest)
print("  Background: \(w)x\(h) PNG")
