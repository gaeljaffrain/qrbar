import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import ImageIO
import UniformTypeIdentifiers

public enum ErrorCorrection: String, CaseIterable, Identifiable {
    case low = "L", medium = "M", quartile = "Q", high = "H"
    public var id: String { rawValue }
}

/// A QR code as a square grid of modules, generated offline by Core Image.
public struct QRCode {
    public let size: Int
    /// Row-major, top row first; `true` is a dark module.
    public let modules: [Bool]

    public init?(_ text: String, correction: ErrorCorrection = .medium) {
        guard !text.isEmpty else { return nil }
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = correction.rawValue
        guard let output = filter.outputImage else { return nil }

        // The generator emits one pixel per module, without a quiet zone.
        let extent = output.extent.integral
        let width = Int(extent.width), height = Int(extent.height)
        guard width == height, width > 0 else { return nil }
        // Render RGBA and keep the red channel (an R8 render into a gray colorspace
        // comes out all black).
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        guard let srgb = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        CIContext().render(output, toBitmap: &rgba, rowBytes: width * 4, bounds: extent,
                           format: .RGBA8, colorSpace: srgb)
        let pixels = (0..<width * height).map { rgba[$0 * 4] }

        // Core Image pads the symbol with a white border; crop to the dark bounding
        // box (finder patterns touch every edge of a valid symbol) so `size` is the
        // true symbol size: 21, 25, 29, ...
        let dark = (0..<width * height).filter { pixels[$0] < 128 }
        guard let minRow = dark.map({ $0 / width }).min(), let maxRow = dark.map({ $0 / width }).max(),
              let minCol = dark.map({ $0 % width }).min(), let maxCol = dark.map({ $0 % width }).max(),
              maxRow - minRow == maxCol - minCol else { return nil }
        size = maxRow - minRow + 1
        modules = (minRow...maxRow).flatMap { row in
            (minCol...maxCol).map { col in pixels[row * width + col] < 128 }
        }
    }

    public func isDark(row: Int, col: Int) -> Bool { modules[row * size + col] }

    /// PNG with `scale` pixels per module and a white quiet zone around the code.
    public func pngData(scale: Int = 10, quietZone: Int = 4) -> Data? {
        let side = (size + 2 * quietZone) * scale
        guard let ctx = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8,
                                  bytesPerRow: 0, space: CGColorSpaceCreateDeviceGray(),
                                  bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        ctx.setFillColor(gray: 1, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: side, height: side))
        ctx.setFillColor(gray: 0, alpha: 1)
        for row in 0..<size {
            for col in 0..<size where isDark(row: row, col: col) {
                // CGContext's origin is bottom-left; row 0 is the top of the code.
                ctx.fill(CGRect(x: (col + quietZone) * scale,
                                y: (size - 1 - row + quietZone) * scale,
                                width: scale, height: scale))
            }
        }
        guard let image = ctx.makeImage() else { return nil }
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(dest, image, nil)
        return CGImageDestinationFinalize(dest) ? data as Data : nil
    }

    public func svgString(quietZone: Int = 4) -> String {
        let side = size + 2 * quietZone
        var path = ""
        for row in 0..<size {
            for col in 0..<size where isDark(row: row, col: col) {
                path += "M\(col + quietZone) \(row + quietZone)h1v1h-1z"
            }
        }
        return """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 \(side) \(side)" shape-rendering="crispEdges">\
        <rect width="\(side)" height="\(side)" fill="#fff"/><path d="\(path)" fill="#000"/></svg>
        """
    }
}
