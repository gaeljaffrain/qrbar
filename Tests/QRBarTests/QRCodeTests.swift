import CoreImage
import XCTest
@testable import QRBarCore

final class QRCodeTests: XCTestCase {
    /// Decode our own PNG with Core Image's detector: proves the grid is scannable
    /// (right orientation, quiet zone) and that the payload round-trips.
    func testPNGRoundTrips() throws {
        let url = "https://example.com/some/path?q=1"
        let code = try XCTUnwrap(QRCode(url))
        let png = try XCTUnwrap(code.pngData(scale: 8))
        let image = try XCTUnwrap(CIImage(data: png))
        let detector = try XCTUnwrap(CIDetector(ofType: CIDetectorTypeQRCode, context: nil,
                                                options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]))
        let message = (detector.features(in: image).first as? CIQRCodeFeature)?.messageString
        XCTAssertEqual(message, url)
    }

    func testEmptyInputIsNil() {
        XCTAssertNil(QRCode(""))
    }

    func testHigherCorrectionIsNotSmaller() throws {
        let low = try XCTUnwrap(QRCode("https://example.com", correction: .low))
        let high = try XCTUnwrap(QRCode("https://example.com", correction: .high))
        XCTAssertGreaterThanOrEqual(high.size, low.size)
    }

    func testSVGHasViewBox() throws {
        let code = try XCTUnwrap(QRCode("hello"))
        XCTAssertTrue(code.svgString().contains("viewBox=\"0 0 \(code.size + 8) \(code.size + 8)\""))
    }
}
