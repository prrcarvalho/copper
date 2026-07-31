import CoreGraphics
import Foundation
import ImageIO

guard CommandLine.arguments.count == 3 else {
    fputs("usage: GenerateAppIcon.swift <source.png> <master.png>\n", stderr)
    exit(64)
}

let sourceURL = URL(fileURLWithPath: CommandLine.arguments[1])
let masterURL = URL(fileURLWithPath: CommandLine.arguments[2])

guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
      let sourceImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
    fputs("GenerateAppIcon: could not read source image\n", stderr)
    exit(1)
}

let canvasSize = 1024
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
guard let context = CGContext(
    data: nil,
    width: canvasSize,
    height: canvasSize,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fputs("GenerateAppIcon: could not create bitmap context\n", stderr)
    exit(1)
}

context.clear(CGRect(x: 0, y: 0, width: canvasSize, height: canvasSize))
context.interpolationQuality = .high

// The supplied artwork already contains the Copper arch, blocks, sparkle and
// material treatment. Keep it intact and only remove the white exterior that
// surrounds the rounded-square artwork so Finder/Dock can apply native icon
// compositing without a visible white corner box.
let artworkRect = CGRect(x: 48, y: 48, width: 928, height: 928)
let artworkPath = CGPath(
    roundedRect: artworkRect,
    cornerWidth: 166,
    cornerHeight: 166,
    transform: nil
)
context.addPath(artworkPath)
context.clip()
context.draw(sourceImage, in: CGRect(x: 0, y: 0, width: canvasSize, height: canvasSize))

guard let master = context.makeImage() else {
    fputs("GenerateAppIcon: could not render master image\n", stderr)
    exit(1)
}

func writePNG(_ image: CGImage, to url: URL) throws {
    guard let destination = CGImageDestinationCreateWithURL(
        url as CFURL,
        "public.png" as CFString,
        1,
        nil
    ) else {
        throw NSError(domain: "GenerateAppIcon", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not create PNG destination"])
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw NSError(domain: "GenerateAppIcon", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not finalize PNG"])
    }
}

try FileManager.default.createDirectory(
    at: masterURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)
try writePNG(master, to: masterURL)
print(masterURL.path)
