import SwiftUI

public enum OKLabPickerMode: String, CaseIterable, Identifiable, Sendable {
    case polarOKLCH = "OKLCH (Wheel)"
    case cartesianOKLab = "OKLab (L, a, b)"
    case perceptualSwatches = "Swatches"
    case colorHarmonies = "Harmonies"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .polarOKLCH: return "paintpalette.fill"
        case .cartesianOKLab: return "slider.horizontal.3"
        case .perceptualSwatches: return "square.grid.3x3.fill"
        case .colorHarmonies: return "circle.hexagongrid.fill"
        }
    }
}

/// Configuration object for customizing the `OKLabColorPicker` behavior, presentation style, and feature set.
public struct OKLabPickerConfiguration: Sendable, Equatable, Hashable {
    /// Style of the color picker component
    public enum Style: Sendable {
        case inline
        case compact
        case card
    }

    public var style: Style
    public var title: String?
    public var showHeader: Bool
    public var showHexInput: Bool
    public var showAlphaSlider: Bool
    public var showColorMetrics: Bool
    public var showColorHarmonies: Bool
    public var showPresetsGrid: Bool
    public var allowedModes: [OKLabPickerMode]
    public var customPresets: [OKLabColorValue]

    public init(
        style: Style = .inline,
        title: String? = "OKLab Color",
        showHeader: Bool = true,
        showHexInput: Bool = true,
        showAlphaSlider: Bool = false,
        showColorMetrics: Bool = true,
        showColorHarmonies: Bool = false,
        showPresetsGrid: Bool = true,
        allowedModes: [OKLabPickerMode] = OKLabPickerMode.allCases,
        customPresets: [OKLabColorValue] = OKLabColorValue.presets
    ) {
        self.style = style
        self.title = title
        self.showHeader = showHeader
        self.showHexInput = showHexInput
        self.showAlphaSlider = showAlphaSlider
        self.showColorMetrics = showColorMetrics
        self.showColorHarmonies = showColorHarmonies
        self.showPresetsGrid = showPresetsGrid
        self.allowedModes = allowedModes
        self.customPresets = customPresets
    }

    public static let `default` = OKLabPickerConfiguration()

    public static let compact = OKLabPickerConfiguration(
        style: .compact,
        title: nil,
        showHeader: false,
        showHexInput: false,
        showColorHarmonies: false
    )

    public static let full = OKLabPickerConfiguration(
        style: .card,
        title: "OKLab Color",
        showHeader: true,
        showHexInput: true,
        showAlphaSlider: true,
        showColorMetrics: true,
        showColorHarmonies: true,
        showPresetsGrid: true
    )
}
import SwiftUI

/// A ready-to-use color picker button that displays a live color swatch and opens an OKLab color picker popover/dialog.
public struct OKLabColorPickerButton: View {
    @Binding public var color: OKLabColorValue
    public var label: String?
    public var configuration: OKLabPickerConfiguration

    @State private var isPickerPresented: Bool = false

    public init(
        color: Binding<OKLabColorValue>,
        label: String? = nil,
        configuration: OKLabPickerConfiguration = .default
    ) {
        self._color = color
        self.label = label
        self.configuration = configuration
    }

    public var body: some View {
        Button {
            isPickerPresented.toggle()
        } label: {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(color.color)
                    .frame(width: 22, height: 22)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                    )

                if let label = label {
                    Text(label)
                        .font(.body)
                }

                Text(color.hexString)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(0.06))
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPickerPresented, arrowEdge: .bottom) {
            OKLabColorPicker(color: $color, configuration: configuration)
                .frame(width: 320)
        }
    }
}

#Preview {
    OKLabColorPickerButton(color: .constant(OKLabColorValue(lightness: 0.7, chroma: 0.18, hueDegrees: 240.0)), label: "Badge Color")
        .padding(40)
}
import SwiftUI

public extension View {
    /// Presents an OKLab Color Picker popover attached to the current view.
    func oklabColorPicker(
        isPresented: Binding<Bool>,
        color: Binding<OKLabColorValue>,
        configuration: OKLabPickerConfiguration = .default
    ) -> some View {
        self.popover(isPresented: isPresented) {
            OKLabColorPicker(color: color, configuration: configuration)
                .frame(width: 320)
        }
    }
}
import SwiftUI
import CoreGraphics

public struct OKLabColorPicker: View {
    @Binding public var color: OKLabColorValue
    @Binding public var mode: OKLabPickerMode
    public var configuration: OKLabPickerConfiguration

    @FocusState private var isHexFocused: Bool
    @State private var hexInputText: String = ""
    @State private var isHoveringWheel: Bool = false

    public init(
        color: Binding<OKLabColorValue>,
        mode: Binding<OKLabPickerMode>? = nil,
        configuration: OKLabPickerConfiguration = .default
    ) {
        self._color = color
        if let modeBinding = mode {
            self._mode = modeBinding
        } else {
            self._mode = .constant(.polarOKLCH)
        }
        self.configuration = configuration
        self._hexInputText = State(initialValue: color.wrappedValue.hexString.replacingOccurrences(of: "#", with: ""))
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: Swatch + Hex Input Pill + Realtime Metrics
            if configuration.showHeader {
                HStack(spacing: 8) {
                    // Swatch Badge
                    RoundedRectangle(cornerRadius: 6)
                        .fill(color.color)
                        .frame(width: 26, height: 26)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                        )
                        .shadow(color: color.color.opacity(0.3), radius: 4, x: 0, y: 1)

                    // Hex Input Pill
                    if configuration.showHexInput {
                        HStack(spacing: 2) {
                            Text("#")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(.secondary)
                            TextField("Hex", text: $hexInputText)
                                .font(.system(.caption2, design: .monospaced))
                                .fontWeight(.bold)
                                .textFieldStyle(.plain)
                                .frame(width: 58)
                                .focused($isHexFocused)
                                .onChange(of: hexInputText) { _, newValue in
                                    guard isHexFocused else { return }
                                    let clean = newValue.replacingOccurrences(of: "#", with: "").uppercased()
                                    if let parsed = OKLabColorValue.from(hex: clean) {
                                        color = parsed
                                    }
                                }
                        }
                        .padding(.horizontal, 5)
                        .padding(.vertical, 3)
                        .background(Color.primary.opacity(0.06))
                        .cornerRadius(5)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color.primary.opacity(0.12), lineWidth: 0.8)
                        )
                    }

                    // Metrics Text
                    if configuration.showColorMetrics {
                        Text(String(format: "L:%.0f%% C:%.2f H:%.0f°", color.lightness * 100, color.chroma, color.hueDegrees))
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }

                    Spacer(minLength: 0)
                }
            }

            // Optional Alpha / Opacity Slider
            if configuration.showAlphaSlider {
                HStack(spacing: 8) {
                    Text("α")
                        .font(.caption2.bold())
                        .foregroundColor(.secondary)
                        .frame(width: 12)

                    Slider(
                        value: Binding(
                            get: { color.alpha },
                            set: { color.alpha = $0 }
                        ),
                        in: 0...1
                    )
                    .tint(color.color)

                    Text(String(format: "%.0f%%", color.alpha * 100))
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: 34, alignment: .trailing)
                }
            }

            // Hero Picker View Content based on selected Mode
            VStack(spacing: 0) {
                switch mode {
                case .polarOKLCH:
                    VStack(spacing: 8) {
                        // Ambient Hero Glow behind 2D Color Canvas Wheel
                        ZStack {
                            Circle()
                                .fill(color.color.opacity(isHoveringWheel ? 0.28 : 0.16))
                                .blur(radius: isHoveringWheel ? 16 : 10)
                                .frame(width: 130, height: 130)

                            OKLCHColorWheelView(color: $color, onInteraction: {
                                isHexFocused = false
                            })
                            .frame(height: 145)
                            .onHover { hovering in
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isHoveringWheel = hovering
                                }
                            }
                        }

                        // Compact Lightness Slider
                        HStack(spacing: 6) {
                            Image(systemName: "sun.max.fill")
                                .font(.caption2)
                                .foregroundColor(.secondary)

                            Slider(
                                value: Binding(
                                    get: { color.lightness },
                                    set: {
                                        isHexFocused = false
                                        color.lightness = $0
                                    }
                                ),
                                in: 0...1
                            )
                            .tint(color.color)

                            Text(String(format: "%.0f%%", color.lightness * 100))
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(.secondary)
                                .frame(width: 32, alignment: .trailing)
                        }
                    }

                case .cartesianOKLab:
                    OKLabSlidersView(color: $color, onInteraction: {
                        isHexFocused = false
                    })

                case .perceptualSwatches:
                    OKLabSwatchesView(selectedColor: $color, onInteraction: {
                        isHexFocused = false
                    })

                case .colorHarmonies:
                    OKLabHarmoniesView(color: $color, onInteraction: {
                        isHexFocused = false
                    })
                }
            }
            .frame(maxWidth: .infinity)
        }
        .onAppear {
            hexInputText = color.hexString.replacingOccurrences(of: "#", with: "")
            if !configuration.allowedModes.contains(mode) {
                if let first = configuration.allowedModes.first {
                    mode = first
                }
            }
        }
        .onChange(of: color) { _, newColor in
            let formatted = newColor.hexString.replacingOccurrences(of: "#", with: "")
            if !isHexFocused {
                hexInputText = formatted
            }
        }
    }
}

// MARK: - Subviews & Supporting Picker Components

struct OKLCHColorWheelView: View {
    @Binding var color: OKLabColorValue
    var onInteraction: (() -> Void)? = nil

    @State private var wheelImage: CGImage? = nil
    @State private var lastLightness: Double = -1.0

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            let radius = side / 2.0
            let center = CGPoint(x: geometry.size.width / 2.0, y: geometry.size.height / 2.0)

            ZStack {
                if let cgImage = wheelImage {
                    Image(cgImage, scale: 2.0, label: Text("Color Wheel"))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: side, height: side)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(color.color)
                        .frame(width: side, height: side)
                }

                // Thumb Indicator
                let thumbChromaNorm = min(color.chroma / 0.32, 1.0)
                let thumbRadius = thumbChromaNorm * radius
                let angleRad = color.hueDegrees * .pi / 180.0
                let thumbX = center.x + thumbRadius * cos(angleRad)
                let thumbY = center.y + thumbRadius * sin(angleRad)

                Circle()
                    .fill(color.color)
                    .frame(width: 16, height: 16)
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    .shadow(color: Color.black.opacity(0.4), radius: 3, x: 0, y: 1)
                    .position(x: thumbX, y: thumbY)
            }
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        onInteraction?()
                        let dx = value.location.x - center.x
                        let dy = value.location.y - center.y
                        let dist = hypot(dx, dy)
                        let clampedChroma = min((dist / radius) * 0.32, 0.32)

                        var angle = atan2(dy, dx) * 180.0 / .pi
                        if angle < 0 { angle += 360.0 }

                        color = OKLabColorValue(
                            lightness: color.lightness,
                            chroma: clampedChroma,
                            hueDegrees: angle,
                            alpha: color.alpha
                        )
                    }
            )
            .onAppear {
                updateWheelImageIfNeeded(lightness: color.lightness)
            }
            .onChange(of: color.lightness) { _, newLightness in
                updateWheelImageIfNeeded(lightness: newLightness)
            }
        }
    }

    private func updateWheelImageIfNeeded(lightness: Double) {
        guard abs(lightness - lastLightness) > 0.001 || wheelImage == nil else { return }
        lastLightness = lightness
        wheelImage = makeSmoothWheelImage(lightness: lightness, size: 300)
    }
}

private func makeSmoothWheelImage(lightness: Double, size: Int = 300) -> CGImage? {
    var data = [UInt8](repeating: 0, count: size * size * 4)
    let center = Double(size) / 2.0
    let radius = center

    for y in 0..<size {
        let dy = Double(y) - center
        for x in 0..<size {
            let dx = Double(x) - center
            let dist = hypot(dx, dy)
            let offset = (y * size + x) * 4
            if dist <= radius {
                let normChroma = (dist / radius) * 0.32
                var angle = atan2(dy, dx) * 180.0 / .pi
                if angle < 0 { angle += 360.0 }

                let val = OKLabColorValue(lightness: lightness, chroma: normChroma, hueDegrees: angle, alpha: 1.0)
                let (r, g, b) = val.toSRGB()

                // Edge anti-aliasing (smooth step for the outer 1.5 pixels)
                let alphaFactor: Double
                let edgeDist = radius - dist
                if edgeDist < 1.5 {
                    alphaFactor = max(0.0, edgeDist / 1.5)
                } else {
                    alphaFactor = 1.0
                }

                data[offset]     = UInt8(min(max(r * alphaFactor * 255.0, 0.0), 255.0))
                data[offset + 1] = UInt8(min(max(g * alphaFactor * 255.0, 0.0), 255.0))
                data[offset + 2] = UInt8(min(max(b * alphaFactor * 255.0, 0.0), 255.0))
                data[offset + 3] = UInt8(min(max(alphaFactor * 255.0, 0.0), 255.0))
            }
        }
    }

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
    guard let provider = CGDataProvider(data: Data(data) as CFData) else { return nil }

    return CGImage(
        width: size,
        height: size,
        bitsPerComponent: 8,
        bitsPerPixel: 32,
        bytesPerRow: size * 4,
        space: colorSpace,
        bitmapInfo: bitmapInfo,
        provider: provider,
        decode: nil,
        shouldInterpolate: true,
        intent: .defaultIntent
    )
}

struct OKLabSlidersView: View {
    @Binding var color: OKLabColorValue
    var onInteraction: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("L")
                    .font(.caption.bold())
                    .frame(width: 14)
                Slider(value: Binding(
                    get: { color.lightness },
                    set: { onInteraction?(); color.lightness = $0 }
                ), in: 0...1)
                Text(String(format: "%.2f", color.lightness))
                    .font(.system(.caption, design: .monospaced))
                    .frame(width: 36)
            }

            HStack {
                Text("a")
                    .font(.caption.bold())
                    .frame(width: 14)
                Slider(value: Binding(
                    get: { color.a },
                    set: { onInteraction?(); color.a = $0 }
                ), in: -0.4...0.4)
                Text(String(format: "%.2f", color.a))
                    .font(.system(.caption, design: .monospaced))
                    .frame(width: 36)
            }

            HStack {
                Text("b")
                    .font(.caption.bold())
                    .frame(width: 14)
                Slider(value: Binding(
                    get: { color.b },
                    set: { onInteraction?(); color.b = $0 }
                ), in: -0.4...0.4)
                Text(String(format: "%.2f", color.b))
                    .font(.system(.caption, design: .monospaced))
                    .frame(width: 36)
            }
        }
        .padding(8)
    }
}

struct OKLabSwatchesView: View {
    @Binding var selectedColor: OKLabColorValue
    var onInteraction: (() -> Void)? = nil

    private let swatches: [OKLabColorValue] = [
        OKLabColorValue(lightness: 0.65, chroma: 0.20, hueDegrees: 25),
        OKLabColorValue(lightness: 0.70, chroma: 0.18, hueDegrees: 55),
        OKLabColorValue(lightness: 0.82, chroma: 0.16, hueDegrees: 95),
        OKLabColorValue(lightness: 0.75, chroma: 0.18, hueDegrees: 145),
        OKLabColorValue(lightness: 0.76, chroma: 0.16, hueDegrees: 165),
        OKLabColorValue(lightness: 0.72, chroma: 0.17, hueDegrees: 185),
        OKLabColorValue(lightness: 0.68, chroma: 0.19, hueDegrees: 240),
        OKLabColorValue(lightness: 0.62, chroma: 0.22, hueDegrees: 275),
        OKLabColorValue(lightness: 0.62, chroma: 0.22, hueDegrees: 285),
        OKLabColorValue(lightness: 0.67, chroma: 0.21, hueDegrees: 330)
    ]

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 5), spacing: 6) {
            ForEach(swatches) { swatch in
                RoundedRectangle(cornerRadius: 6)
                    .fill(swatch.color)
                    .frame(height: 32)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(selectedColor.hexString == swatch.hexString ? Color.primary : Color.clear, lineWidth: 2)
                    )
                    .onTapGesture {
                        onInteraction?()
                        selectedColor = swatch
                    }
            }
        }
        .padding(4)
    }
}

struct OKLabHarmoniesView: View {
    @Binding var color: OKLabColorValue
    var onInteraction: (() -> Void)? = nil

    var body: some View {
        let harmonies = color.harmonies()
        VStack(alignment: .leading, spacing: 8) {
            Text("Perceptual Color Harmonies")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 8) {
                ForEach(harmonies) { harm in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(harm.color)
                            .frame(height: 36)
                            .onTapGesture {
                                onInteraction?()
                                color = harm
                            }
                        Text(harm.hexString)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(6)
    }
}
