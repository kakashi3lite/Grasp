# Grasp

[![Swift](https://img.shields.io/badge/Swift-6-orange.svg)](https://swift.org)
[![iOS](https://img.shields.io/badge/iOS-26-blue.svg)](https://developer.apple.com/ios/)
[![MLX](https://img.shields.io/badge/MLX-Swift-green.svg)](https://github.com/ml-explore/mlx-swift)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

**Grasp** is an on-device vision-language app for iPhone. It captures text and objects from the camera, runs **local MLX inference**, and keeps your data on the device.

## Architecture

| Layer | Responsibility |
| --- | --- |
| **Inference** | MLX Swift VLM pipeline, streaming image decode |
| **Memory** | SwiftData entities, bounded buffers |
| **Thermal** | Thermal state monitoring, inference throttling |
| **Concurrency** | FIFO inference actor, AsyncStream bridges |
| **Search** | `NLEmbedding` semantic search with fallback |

## Requirements

- **Xcode** 16 or newer  
- **iOS** 26 SDK / deployment target as set in the project  
- **Device:** Apple Silicon iPhone recommended (**A17 Pro** or newer for best MLX performance)

## Privacy

**Data Not Collected — verified.** Processing is local. See `Docs/PRIVACY_POLICY.md` and App Store privacy details.

## Installation

1. Clone this repository.  
2. Open `Grasp.xcodeproj` in Xcode.  
3. Select your development team and a physical device (camera + Neural Engine).  
4. Build and run. **Model weights download on first launch** (network required once).

## Pricing

**$39.99** lifetime (as configured for App Store).

## License

MIT — see [LICENSE](LICENSE).
