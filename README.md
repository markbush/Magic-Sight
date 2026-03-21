# 🪄 Magic Sight

### *Resurrecting the 90s for the Spatial Era*

**Magic Sight** is an open-source engine and application built for **iOS 26, and iPadOS 26**. It uses advanced computer vision to decode traditional "Magic Eye" (autostereogram) images and transform them into interactive, high-fidelity 3D Spatial Scenes.

-----

## 🌟 Overview

In the 1990s, autostereograms required a "parallel viewing" technique to see hidden 3D shapes. **Magic Sight** removes the squinting. By calculating the mathematical disparity encoded in the repeating patterns, the app generates a high-resolution depth map and re-projects the image into native Apple 3D formats.

* **iPhone/iPad:** View hidden objects as **Spatial Scenes** with real-time parallax.
* **Export:** Save results as standard **Spatial Photos (.heic)** compatible with the native Photos app.

-----

## 🛠 Technology Stack (v26.0)

This project serves as a reference implementation for several cutting-edge Apple frameworks:

| Framework | Implementation |
| :--- | :--- |
| **Spatial Scene API** | Powers the depth-sensitive "look-around" effect on iOS Lock Screens. |
| **Metal** | Custom compute shaders for instantaneous SAD (Sum of Absolute Differences) processing. |
| **ImageIO** | Handles the encoding of stereoscopic pairs into Spatial HEIF metadata. |

-----

## 🧮 How the "Magic" Works

The core logic of Magic Sight follows a deterministic three-stage pipeline:

1.  **Period Detection:** The engine samples multiple image rows and uses a gradient-based analysis of pixel differences to identify the steepest rise, accurately determining the base pattern width ($W$).
2.  **Disparity Mapping:** For every pixel $P$ at $(x, y)$, we find the matching pixel $P'$ in the adjacent pattern. The horizontal shift $\Delta x$ is converted into a depth value $Z$:
    $$Z = \frac{f \cdot B}{\Delta x}$$
    *(Where $f$ is the virtual focal length and $B$ is the baseline shift).*
3.  **Mesh Refinement:** A bilateral filter is applied via the Neural Engine to smooth the 3D surface while maintaining crisp object edges.

-----

## 🚀 Getting Started

### Prerequisites

* **Xcode 17.4+**
* **Target Devices:** iPhone 15 Pro or newer, or iPad Pro (M-series).
* **OS:** iOS 26.0+, iPadOS 26.0+.

### Installation

1.  Clone the repository:
    `git clone https://github.com/yourusername/MagicSight.git`
2.  Open `MagicSight.xcodeproj`.
3.  Select your target device and hit **Run**.

-----

## 📄 License

This project is licensed under the **Apache License 2.0**. It is permissive for both educational and commercial use, provided that the original copyright and patent grants are respected. See `LICENSE` for details.
