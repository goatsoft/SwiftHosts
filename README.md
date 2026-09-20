<p align="center">
  <img src="logo.jpg" width="160" height="160" alt="SwiftHosts Logo" />
</p>

<h1 align="center">SwiftHosts</h1>

<p align="center">
  <a href="https://swift.org"><img src="https://img.shields.io/badge/Swift-5.9+-FA7343?style=flat-square&logo=swift&logoColor=white" alt="Swift 5.9+"></a>
  <a href="https://apple.com/macos"><img src="https://img.shields.io/badge/macOS-13.0+-000000?style=flat-square&logo=apple&logoColor=white" alt="macOS 13.0+"></a>
  <a href="https://github.com/GOATsoft/swifthosts/releases"><img src="https://img.shields.io/badge/version-v0.1.1-blue.svg?style=flat-square" alt="Version v0.1.1"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-green.svg?style=flat-square" alt="License MIT"></a>
</p>

<p align="center">
  A modern native macOS <code>/etc/hosts</code> file manager built with Swift & SwiftUI.
</p>

---

## 🎨 Open-Source Package: OKLabColorPicker (v0.1.1)

<p align="center">
  <a href="https://github.com/goatsoft/OKLabColorPicker">
    <img src="https://raw.githubusercontent.com/goatsoft/OKLabColorPicker/main/Assets/icon.png" width="140" height="140" alt="OKLabColorPicker Icon" />
  </a>
  <br/>
  <b><a href="https://github.com/goatsoft/OKLabColorPicker">OKLabColorPicker (v0.1.1)</a></b>
</p>

This project includes and uses **[`OKLabColorPicker`](https://github.com/goatsoft/OKLabColorPicker)**, an open-source standalone Swift Package by **GOATsoft** engineered for high-precision, perceptually uniform color picking in OKLab ($L, a, b$) and OKLCH ($L, C, H^\circ$) color spaces.

---

## 🚀 Release Notes (v0.1.1)

### 🎨 Standalone `OKLabColorPicker` Package Release
- **GitHub Release (v0.1.1)**: Officially published [`GOATsoft/OKLabColorPicker`](https://github.com/goatsoft/OKLabColorPicker.git) as an open-source Swift Package (macOS 14+, iOS 17+, visionOS 1+, watchOS 10+, tvOS 17+).
- **Brand Assets & Iconography**: Created and bundled high-resolution macOS glassmorphism OKLab color wheel icon assets (`OKLabIcon`) and README visual header.

### 🎡 Perceptual OKLab/OKLCH Engine Features
- **4 Selection Modes**:
  1. **OKLCH Color Wheel** (`.polarOKLCH`): Smooth 2D radial polar wheel for Chroma & Hue angle with hero glow and real-time lightness slider.
  2. **Cartesian OKLab Sliders** (`.cartesianOKLab`): Precision controls for $L$ (Lightness), $a$ (Green–Red axis), and $b$ (Blue–Yellow axis).
  3. **Perceptual Swatches** (`.perceptualSwatches`): Curated palette of perceptually balanced OKLab color badges.
  4. **Color Harmonies Generator** (`.colorHarmonies`): Automatic generation of complementary, triadic, and analogous ($\pm 30^\circ$) color palettes.
- **WCAG 2.1 Contrast Analytics**: Built-in methods to calculate relative luminance, contrast ratios ($1:1$ to $21:1$), and AA/AAA accessibility compliance.
- **Hex Code Synchronization**: Real-time `#HEX` string parsing, monospaced readout pill, and bidirectional state synchronization.

### 🛠️ SwiftHosts UI & UX Improvements
- **Category Badge Color Customization**: Integrated the OKLab color picker directly into category creation and customization sheets.
- **Xcode Asset Catalog**: Added `OKLabIcon.imageset` to `Assets.xcassets`.
- **Unit Test Coverage**: Automated test suite verifying OKLab $\leftrightarrow$ sRGB conversions, polar coordinate math, hex parsing, color harmonies, and contrast ratios.

---

## ✨ Features

- 🏷️ **Categorized Host Management**: Group entries into custom categories (*Local Dev*, *Staging*, *Blocking*, *Production*) with OKLab perceptual color badges.
- 🎨 **Perceptual OKLab/OKLCH Color Engine**: Integrated 2D OKLCH color wheel, perceptual swatches, and live `#HEX` synchronization powered by the [`OKLabColorPicker`](https://github.com/goatsoft/OKLabColorPicker) engine.
- 🔒 **Secure Authorization**: Seamless session authentication to safely save changes to protected `/etc/hosts` without running as root.
- 🔍 **Instant Search & Filter**: Real-time hostname, IP, and notes filtering with multi-column sorting.
- 📥 **Import & Export**: Effortlessly import or export hosts configurations in standard hosts file format.
- 🖥️ **Native macOS UI**: Designed strictly for macOS using NavigationSplitView, Table grid layout, dark mode support, and keyboard shortcuts.

---

## 🛠️ Building & Running

### Requirements
- macOS 13.0 (Ventura) or later
- Xcode 15.0 or later

### Quick Start

```bash
# Clone the repository
git clone https://github.com/GOATsoft/swifthosts.git
cd swifthosts

# Open in Xcode
open SwiftHosts.xcodeproj
```

Build and run using `⌘R` in Xcode.

---

## 🏗️ Architecture Overview

- **`Domain/Parser/HostsFileParser.swift`**: High-performance parser that preserves original comments, formatting, and entry order.
- **`Domain/Services/HostsManager.swift`**: Observable state coordinator managing in-memory drafts, dirty row state tracking, and elevated privilege operations via `STPrivilegedTask` / `osascript`.
- **`Domain/Models/OKLabColor.swift`**: Re-exports `OKLabColorValue` from the `OKLabColorPicker` package for category color badges.
- **`UI/Components/OKLabColorPickerView.swift`**: Re-exports `OKLabColorPicker` SwiftUI views.

---

## 📄 License

Distributed under the MIT License. See [`LICENSE`](LICENSE) for more information.

Copyright © 2026 **GOATsoft**. All rights reserved.
