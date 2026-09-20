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
- **`UI/Components/OKLabColorPickerView.swift`**: Perceptual OKLab/OKLCH color picker component for category badge customization.

---

## 📄 License

Distributed under the MIT License. See [`LICENSE`](LICENSE) for more information.

Copyright © 2026 **GOATsoft**. All rights reserved.
