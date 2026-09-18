import SwiftUI
import CoreGraphics

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Value Object representing a color in the OKLab (L, a, b) and OKLCH (L, C, H) perceptually uniform color spaces.
public struct OKLabColorValue: Codable, Equatable, Hashable, Sendable, CustomStringConvertible, Identifiable {
    public var id: String { hexString }

    /// Lightness component L ∈ [0.0, 1.0]
    public var lightness: Double
    /// Green-Red chromatic axis a ∈ [-0.4, 0.4]
    public var a: Double
    /// Blue-Yellow chromatic axis b ∈ [-0.4, 0.4]
    public var b: Double
    /// Opacity / Alpha component α ∈ [0.0, 1.0]
    public var alpha: Double

    /// Creates an OKLab color from (L, a, b) components with optional alpha.
    public init(lightness: Double, a: Double, b: Double, alpha: Double = 1.0) {
        self.lightness = min(max(lightness, 0.0), 1.0)
        self.a = min(max(a, -0.4), 0.4)
        self.b = min(max(b, -0.4), 0.4)
        self.alpha = min(max(alpha, 0.0), 1.0)
    }

    /// Creates an OKLCH color from Lightness (L), Chroma (C), and Hue Angle (H in degrees) with optional alpha.
    public init(lightness: Double, chroma: Double, hueDegrees: Double, alpha: Double = 1.0) {
        let radians = hueDegrees * .pi / 180.0
        self.lightness = min(max(lightness, 0.0), 1.0)
        self.a = chroma * cos(radians)
        self.b = chroma * sin(radians)
        self.alpha = min(max(alpha, 0.0), 1.0)
    }

    // MARK: - Derived Properties

    /// Chroma (C*) component of OKLCH: C = √(a² + b²)
    public var chroma: Double {
        sqrt(a * a + b * b)
    }

    /// Hue Angle (H°) component of OKLCH in degrees [0, 360)
    public var hueDegrees: Double {
        let degrees = atan2(b, a) * 180.0 / .pi
        return degrees < 0 ? degrees + 360.0 : degrees
    }

    /// Converts OKLab color to a SwiftUI `Color`
    public var color: Color {
        let (r, g, bComp) = toSRGB()
        return Color(.sRGB, red: r, green: g, blue: bComp, opacity: alpha)
    }

    public var description: String {
        String(format: "OKLCH(L: %.0f%%, C: %.2f, H: %.0f°, α: %.2f)", lightness * 100, chroma, hueDegrees, alpha)
    }

    // MARK: - Color Space Conversions

    /// Converts OKLab to sRGB components (0.0 ... 1.0)
    public func toSRGB() -> (red: Double, green: Double, blue: Double) {
        let l_ = lightness + 0.3963377774 * a + 0.2158037573 * b
        let m_ = lightness - 0.1055613458 * a - 0.0638541728 * b
        let s_ = lightness - 0.0894841775 * a - 1.2914855480 * b

        let l = l_ * l_ * l_
        let m = m_ * m_ * m_
        let s = s_ * s_ * s_

        let rLinear = +4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
        let gLinear = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
        let bLinear = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s

        let r = gammaCompress(rLinear)
        let g = gammaCompress(gLinear)
        let bComp = gammaCompress(bLinear)

        return (
            red: min(max(r, 0.0), 1.0),
            green: min(max(g, 0.0), 1.0),
            blue: min(max(bComp, 0.0), 1.0)
        )
    }

    /// Creates an `OKLabColorValue` from sRGB component values (0.0 to 1.0)
    public static func from(srgbRed r: Double, green g: Double, blue b: Double, alpha: Double = 1.0) -> OKLabColorValue {
        let rLin = gammaExpand(r)
        let gLin = gammaExpand(g)
        let bLin = gammaExpand(b)

        let l = 0.4122214708 * rLin + 0.5363325363 * gLin + 0.0514459929 * bLin
        let m = 0.2119034982 * rLin + 0.6806995451 * gLin + 0.1073969566 * bLin
        let s = 0.0883024619 * rLin + 0.2817188376 * gLin + 0.6299787005 * bLin

        let l_ = cbrt(l)
        let m_ = cbrt(m)
        let s_ = cbrt(s)

        let L = 0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_
        let aVal = 1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_
        let bVal = 0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_

        return OKLabColorValue(lightness: L, a: aVal, b: bVal, alpha: alpha)
    }

    // MARK: - Hex String Parsing & Format

    /// Hexadecimal String representation (e.g. "#FF5733")
    public var hexString: String {
        let srgb = toSRGB()
        let r = Int(round(srgb.red * 255.0))
        let g = Int(round(srgb.green * 255.0))
        let b = Int(round(srgb.blue * 255.0))
        if alpha < 0.999 {
            let aInt = Int(round(alpha * 255.0))
            return String(format: "#%02X%02X%02X%02X", r, g, b, aInt)
        }
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    /// Creates an `OKLabColorValue` from a hex string (e.g. "#FF5733", "FF5733", "F00", or "#FF5733FF")
    public static func from(hex: String) -> OKLabColorValue? {
        let hexClean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        guard Scanner(string: hexClean).scanHexInt64(&int) else { return nil }

        let r, g, b, a: Double
        switch hexClean.count {
        case 3: // 3-digit hex (e.g. "F00")
            let rInt = (int >> 8) & 0xF
            let gInt = (int >> 4) & 0xF
            let bInt = int & 0xF
            r = Double(rInt * 17) / 255.0
            g = Double(gInt * 17) / 255.0
            b = Double(bInt * 17) / 255.0
            a = 1.0
        case 6: // 6-digit RGB (e.g. "FF5733")
            r = Double((int >> 16) & 0xFF) / 255.0
            g = Double((int >> 8) & 0xFF) / 255.0
            b = Double(int & 0xFF) / 255.0
            a = 1.0
        case 8: // 8-digit RGBA (e.g. "FF5733FF")
            r = Double((int >> 24) & 0xFF) / 255.0
            g = Double((int >> 16) & 0xFF) / 255.0
            b = Double((int >> 8) & 0xFF) / 255.0
            a = Double(int & 0xFF) / 255.0
        default:
            return nil
        }
        return OKLabColorValue.from(srgbRed: r, green: g, blue: b, alpha: a)
    }

    // MARK: - Color Harmonies Generator

    /// Generates complementary color (opposite hue angle 180°)
    public var complementary: OKLabColorValue {
        let compHue = (hueDegrees + 180.0).truncatingRemainder(dividingBy: 360.0)
        return OKLabColorValue(lightness: lightness, chroma: chroma, hueDegrees: compHue, alpha: alpha)
    }

    /// Generates analogous colors (±30° hue shifts)
    public func analogous(angleStep: Double = 30.0) -> (left: OKLabColorValue, right: OKLabColorValue) {
        let leftHue = (hueDegrees - angleStep + 360.0).truncatingRemainder(dividingBy: 360.0)
        let rightHue = (hueDegrees + angleStep).truncatingRemainder(dividingBy: 360.0)
        return (
            left: OKLabColorValue(lightness: lightness, chroma: chroma, hueDegrees: leftHue, alpha: alpha),
            right: OKLabColorValue(lightness: lightness, chroma: chroma, hueDegrees: rightHue, alpha: alpha)
        )
    }

    /// Generates triadic color harmony (±120° hue shifts)
    public var triadic: (first: OKLabColorValue, second: OKLabColorValue) {
        let firstHue = (hueDegrees + 120.0).truncatingRemainder(dividingBy: 360.0)
        let secondHue = (hueDegrees + 240.0).truncatingRemainder(dividingBy: 360.0)
        return (
            first: OKLabColorValue(lightness: lightness, chroma: chroma, hueDegrees: firstHue, alpha: alpha),
            second: OKLabColorValue(lightness: lightness, chroma: chroma, hueDegrees: secondHue, alpha: alpha)
        )
    }

    /// Generates array of color harmonies
    public func harmonies() -> [OKLabColorValue] {
        let (analLeft, analRight) = analogous()
        let (triFirst, triSecond) = triadic
        return [complementary, analLeft, analRight, triFirst, triSecond]
    }

    /// Generates a monochromatic gradient palette (varying lightness steps)
    public func monochromaticPalette(steps: Int = 5) -> [OKLabColorValue] {
        guard steps > 1 else { return [self] }
        return (0..<steps).map { i in
            let l = 0.2 + (Double(i) / Double(steps - 1)) * 0.75
            return OKLabColorValue(lightness: l, chroma: chroma * 0.85, hueDegrees: hueDegrees, alpha: alpha)
        }
    }

    // MARK: - WCAG Contrast Ratio

    /// Relative Luminance according to WCAG 2.1
    public var relativeLuminance: Double {
        let (r, g, b) = toSRGB()
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    /// Calculates WCAG 2.1 contrast ratio with another OKLab color (1:1 to 21:1)
    public func contrastRatio(with other: OKLabColorValue) -> Double {
        let l1 = max(relativeLuminance, other.relativeLuminance)
        let l2 = min(relativeLuminance, other.relativeLuminance)
        return (l1 + 0.05) / (l2 + 0.05)
    }

    /// Check if contrast meets WCAG AA standard for normal text (>= 4.5:1)
    public func isWCAGAACompliant(with background: OKLabColorValue = OKLabColorValue(lightness: 1, a: 0, b: 0)) -> Bool {
        contrastRatio(with: background) >= 4.5
    }

    // MARK: - Internal Math Helpers

    private func gammaCompress(_ c: Double) -> Double {
        c <= 0.0031308 ? 12.92 * c : 1.055 * pow(c, 1.0 / 2.4) - 0.055
    }

    private static func gammaExpand(_ c: Double) -> Double {
        c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }
}

public extension OKLabColorValue {
    static let presets: [OKLabColorValue] = [
        OKLabColorValue(lightness: 0.65, chroma: 0.20, hueDegrees: 25.0),   // Coral Red
        OKLabColorValue(lightness: 0.70, chroma: 0.18, hueDegrees: 55.0),   // Amber Orange
        OKLabColorValue(lightness: 0.82, chroma: 0.16, hueDegrees: 95.0),   // Warm Yellow
        OKLabColorValue(lightness: 0.75, chroma: 0.18, hueDegrees: 145.0),  // Emerald Green
        OKLabColorValue(lightness: 0.72, chroma: 0.17, hueDegrees: 185.0),  // Mint Teal
        OKLabColorValue(lightness: 0.68, chroma: 0.19, hueDegrees: 240.0),  // Ocean Blue
        OKLabColorValue(lightness: 0.62, chroma: 0.22, hueDegrees: 285.0),  // Indigo Purple
        OKLabColorValue(lightness: 0.67, chroma: 0.21, hueDegrees: 330.0)   // Magenta Pink
    ]
}

public extension Color {
    init(hex: String) {
        let hexClean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hexClean).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hexClean.count {
        case 3:
            let rInt = (int >> 8) & 0xF
            let gInt = (int >> 4) & 0xF
            let bInt = int & 0xF
            (r, g, b) = (rInt * 17, gInt * 17, bInt * 17)
        case 6:
            (r, g, b) = (int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (128, 128, 128)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255.0,
            green: Double(g) / 255.0,
            blue: Double(b) / 255.0,
            opacity: 1.0
        )
    }
}
