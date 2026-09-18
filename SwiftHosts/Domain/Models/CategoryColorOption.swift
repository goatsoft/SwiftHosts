import SwiftUI

public struct OKLabColor: Sendable, Hashable {
    public let l: Float
    public let a: Float
    public let b: Float
    
    public init(l: Float, a: Float, b: Float) {
        self.l = l
        self.a = a
        self.b = b
    }
    
    public var color: Color {
        let l_ = l + 0.3963377774 * a + 0.2158037573 * b
        let m_ = l - 0.1055613458 * a - 0.0638541728 * b
        let s_ = l - 0.0894841775 * a - 1.2914855480 * b
        
        let l3 = l_ * l_ * l_
        let m3 = m_ * m_ * m_
        let s3 = s_ * s_ * s_
        
        let rLinear = +4.0767416621 * l3 - 3.3077115913 * m3 + 0.2309699292 * s3
        let gLinear = -1.2684380046 * l3 + 2.6097574011 * m3 - 0.3413193965 * s3
        let bLinear = -0.0041960863 * l3 - 0.7034186147 * m3 + 1.7076147010 * s3
        
        func toSRGB(_ val: Float) -> Double {
            let clamped = max(0.0, min(1.0, val))
            return Double(clamped <= 0.0031308 ? (12.92 * clamped) : (1.055 * pow(clamped, 1.0 / 2.4) - 0.055))
        }
        
        return Color(.sRGB, red: toSRGB(rLinear), green: toSRGB(gLinear), blue: toSRGB(bLinear), opacity: 1.0)
    }
}

public enum CategoryColorOption: String, CaseIterable, Identifiable, Sendable {
    case blue, purple, pink, red, orange, yellow, green, teal, indigo, mint
    
    public var id: String { rawValue }
    
    public var oklab: OKLabColor {
        switch self {
        case .blue:   return OKLabColor(l: 0.65, a: -0.05, b: -0.28)
        case .purple: return OKLabColor(l: 0.65, a: +0.18, b: -0.22)
        case .pink:   return OKLabColor(l: 0.68, a: +0.24, b: -0.05)
        case .red:    return OKLabColor(l: 0.65, a: +0.22, b: +0.12)
        case .orange: return OKLabColor(l: 0.68, a: +0.14, b: +0.20)
        case .yellow: return OKLabColor(l: 0.72, a: -0.02, b: +0.22)
        case .green:  return OKLabColor(l: 0.68, a: -0.20, b: +0.14)
        case .teal:   return OKLabColor(l: 0.68, a: -0.20, b: -0.05)
        case .indigo: return OKLabColor(l: 0.62, a: +0.08, b: -0.28)
        case .mint:   return OKLabColor(l: 0.70, a: -0.22, b: +0.02)
        }
    }
    
    public var color: Color {
        oklab.color
    }
    
    public var displayName: String {
        rawValue.capitalized
    }
    
    public static var random: CategoryColorOption {
        allCases.randomElement() ?? .blue
    }
}
