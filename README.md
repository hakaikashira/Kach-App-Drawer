# Kach-App-Drawer
# 🪟 Floating Glass App Drawer for Rainmeter

A modern, glassmorphic Rainmeter suite that natively scans your Windows system, extracts high-resolution app icons on the fly, and dynamically sorts them based on launch frequency and user priority.

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Rainmeter](https://img.shields.io/badge/rainmeter-4.5%2B-green.svg)
![Platform](https://img.shields.io/badge/platform-Windows%2010%20%7C%2011-0078D6.svg)

---

## ✨ Features

- **🔍 Automatic System Discovery:** Natively scans Start Menu shortcuts, Desktop items, Registry installations, and UWP/Windows Store apps via PowerShell.
- **🖼️ Native High-Res Icon Extraction:** Powered by an embedded C# shell integration (`IShellItemImageFactory`) that extracts crisp PNG icons straight from Windows executables and DLLs.
- **📊 Smart Sorting Engine:** Dynamically calculates app placement using usage tracking, manual priority weights, and desktop flags.
- **💎 Glassmorphism Design:** Translucent, frosted glass panel built with native Rainmeter shapes, complete with hover scaling and smooth scrolling.

---

## 🛠️ Requirements

- **OS:** Windows 10 or Windows 11
- **Rainmeter:** Version 4.5 or higher
- **PowerShell:** Version 5.1+ (Default on Windows 10/11)

---

## 📦 Installation

1. Go to the [Releases](../../releases) tab on this repository.
2. Download the latest `FloatingGlassAppDrawer_v1.0.0.rmskin` package.
3. Double-click the file to install via Rainmeter.
4. Click **Load** to run the app drawer.

---

## ⚙️ Customization

You can tweak layout parameters in `@Resources/Variables.inc`:

| Variable | Default | Description |
| :--- | :--- | :--- |
| `VisibleApps` | `5` | Number of icon slots displayed simultaneously |
| `IconSize` | `36` | Default icon dimensions in pixels |
| `IconHoverSize` | `44` | Enlarged icon size when hovered |
| `CornerRadius` | `18` | Corner rounding of the glass container |

To manually pin favorite apps to the top, edit `@Resources/Data/AppPriority.inc` and assign high values (e.g., `AppName=100000`).

---

## ☕ Support & Donations

This project is 100% free and open-source. If you find it useful, consider supporting development:

- **Tip / Support:** [(https://ko-fi.com/hakaikashira)]
- **Crypto Tips (USDT / ETH on Arbitrum/Ethereum):**
0x895f6576127778b64F4e7356cc21d98465F8D529`

---

## 📜 License

Distributed under the **MIT License**. See `LICENSE` for more information.
