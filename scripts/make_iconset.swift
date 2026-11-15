import AppKit
import CoreGraphics
import Foundation

let args = CommandLine.arguments
guard args.count >= 3 else {
    fputs("Usage: make_iconset <source_icon_image> <output.appiconset> [banner_image] [project_root]\n", stderr)
    exit(1)
}

let srcURL = URL(fileURLWithPath: args[1])
let appiconsetURL = URL(fileURLWithPath: args[2], isDirectory: true)
try FileManager.default.createDirectory(at: appiconsetURL, withIntermediateDirectories: true)

guard let nsImg = NSImage(contentsOf: srcURL),
      let cgSrc = nsImg.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    fputs("Failed to load source image at \(srcURL.path)\n", stderr)
    exit(1)
}

let macSpecs: [(String, Int)] = [
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

let cs = CGColorSpaceCreateDeviceRGB()

for (filename, px) in macSpecs {
    guard let ctx = CGContext(
        data: nil,
        width: px,
        height: px,
        bitsPerComponent: 8,
        bytesPerRow: px * 4,
        space: cs,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { continue }

    let s = CGFloat(px)
    let inset = s * 0.085
    let bodyRect = CGRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let radius = bodyRect.width * 0.225

    ctx.interpolationQuality = .high
    let clipPath = CGPath(roundedRect: bodyRect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    ctx.saveGState()
    ctx.addPath(clipPath)
    ctx.clip()
    ctx.draw(cgSrc, in: bodyRect)

    ctx.setStrokeColor(NSColor(calibratedRed: 0.98, green: 0.80, blue: 0.30, alpha: 0.52).cgColor)
    ctx.setLineWidth(max(1.0, s * 0.013))
    ctx.addPath(clipPath)
    ctx.strokePath()
    ctx.restoreGState()

    if let outCG = ctx.makeImage() {
        let rep = NSBitmapImageRep(cgImage: outCG)
        if let png = rep.representation(using: .png, properties: [:]) {
            try png.write(to: appiconsetURL.appendingPathComponent(filename))
        }
    }
}

if let iosCtx = CGContext(
    data: nil,
    width: 1024,
    height: 1024,
    bitsPerComponent: 8,
    bytesPerRow: 1024 * 4,
    space: cs,
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
) {
    iosCtx.interpolationQuality = .high
    iosCtx.setFillColor(NSColor(calibratedRed: 0.04, green: 0.06, blue: 0.14, alpha: 1.0).cgColor)
    iosCtx.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
    iosCtx.draw(cgSrc, in: CGRect(x: 0, y: 0, width: 1024, height: 1024))
    if let iosCG = iosCtx.makeImage(),
       let rgbRep = NSBitmapImageRep(
           bitmapDataPlanes: nil,
           pixelsWide: 1024,
           pixelsHigh: 1024,
           bitsPerSample: 8,
           samplesPerPixel: 3,
           hasAlpha: false,
           isPlanar: false,
           colorSpaceName: .deviceRGB,
           bytesPerRow: 1024 * 3,
           bitsPerPixel: 24
       ) {
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rgbRep)
        NSGraphicsContext.current?.cgContext.draw(iosCG, in: CGRect(x: 0, y: 0, width: 1024, height: 1024))
        NSGraphicsContext.restoreGraphicsState()
        if let png = rgbRep.representation(using: .png, properties: [:]) {
            try png.write(to: appiconsetURL.appendingPathComponent("icon_ios_1024.png"))
        }
    }
}

let contentsJSON = """
{
  "images" : [
    { "filename" : "icon_ios_1024.png", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" },
    { "filename" : "icon_16x16.png", "idiom" : "mac", "scale" : "1x", "size" : "16x16" },
    { "filename" : "icon_16x16@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "16x16" },
    { "filename" : "icon_32x32.png", "idiom" : "mac", "scale" : "1x", "size" : "32x32" },
    { "filename" : "icon_32x32@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "32x32" },
    { "filename" : "icon_128x128.png", "idiom" : "mac", "scale" : "1x", "size" : "128x128" },
    { "filename" : "icon_128x128@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "128x128" },
    { "filename" : "icon_256x256.png", "idiom" : "mac", "scale" : "1x", "size" : "256x256" },
    { "filename" : "icon_256x256@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "256x256" },
    { "filename" : "icon_512x512.png", "idiom" : "mac", "scale" : "1x", "size" : "512x512" },
    { "filename" : "icon_512x512@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "512x512" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
"""
try contentsJSON.write(to: appiconsetURL.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)

let rootContentsJSON = """
{
  "info" : { "author" : "xcode", "version" : 1 }
}
"""
try rootContentsJSON.write(
    to: appiconsetURL.deletingLastPathComponent().appendingPathComponent("Contents.json"),
    atomically: true,
    encoding: .utf8
)

if args.count >= 5 {
    let bannerURL = URL(fileURLWithPath: args[3])
    let projRoot = URL(fileURLWithPath: args[4], isDirectory: true)
    let mktDir = projRoot.appendingPathComponent("Marketing", isDirectory: true)
    let ascDir = projRoot.appendingPathComponent("dist/AppStore_Assets", isDirectory: true)
    try FileManager.default.createDirectory(at: mktDir, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: ascDir, withIntermediateDirectories: true)

    let tmpIcon = URL(fileURLWithPath: "/tmp/mb_icon_tmp.png")
    _ = try? FileManager.default.removeItem(at: tmpIcon)
    try FileManager.default.copyItem(at: appiconsetURL.appendingPathComponent("icon_ios_1024.png"), to: tmpIcon)
    _ = try? FileManager.default.removeItem(at: mktDir.appendingPathComponent("app_icon_source.png"))
    try FileManager.default.moveItem(at: tmpIcon, to: mktDir.appendingPathComponent("app_icon_source.png"))

    if let bImg = NSImage(contentsOf: bannerURL),
       let bCG = bImg.cgImage(forProposedRect: nil, context: nil, hints: nil) {
        let rep = NSBitmapImageRep(cgImage: bCG)
        if let png = rep.representation(using: .png, properties: [:]) {
            try png.write(to: mktDir.appendingPathComponent("storefront_banner.png"))
        }
        let tw = 1800, th = 1200
        if let clipCtx = CGContext(data: nil, width: tw, height: th, bitsPerComponent: 8, bytesPerRow: tw * 4, space: cs, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) {
            clipCtx.interpolationQuality = .high
            let sw = CGFloat(bCG.width), sh = CGFloat(bCG.height)
            let scale = max(CGFloat(tw) / sw, CGFloat(th) / sh)
            let dw = sw * scale, dh = sh * scale
            clipCtx.draw(bCG, in: CGRect(x: (CGFloat(tw) - dw) * 0.5, y: (CGFloat(th) - dh) * 0.5, width: dw, height: dh))
            if let outCG = clipCtx.makeImage() {
                let jpgRep = NSBitmapImageRep(cgImage: outCG)
                if let jpg = jpgRep.representation(using: .jpeg, properties: [.compressionFactor: 0.94]) {
                    try jpg.write(to: ascDir.appendingPathComponent("AppClip_Card_Header_1800x1200.jpg"))
                }
            }
        }
    }
}

print("Generated Universal macOS + iOS AppIcon.appiconset & Marketing banners at \(appiconsetURL.path)")
