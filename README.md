# Grasp

**Air-gapped spatial knowledge for your pocket.**  
Grasp is an iPhone app that turns the camera into a private document and scene vault: capture, understand with on-device AI, and search—without sending your frames to a server.

[![Swift](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)](https://swift.org)
[![iOS](https://img.shields.io/badge/iOS-26-007AFF?logo=apple&logoColor=white)](https://developer.apple.com/ios/)
[![MLX Swift](https://img.shields.io/badge/MLX-Swift-34C759)](https://github.com/ml-explore/mlx-swift)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![CI](https://github.com/kakashi3lite/Grasp/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/kakashi3lite/Grasp/actions/workflows/ci.yml)

---

## Why Grasp?

Subscriptions and cloud OCR are the default. Grasp is built for people who want **ownership**: one-time purchase, **local inference** via [MLX Swift](https://github.com/ml-explore/mlx-swift), and **SwiftData** storage so captures stay on the device you hold.

- **On-device VLM** — Vision-language inference runs locally; no standing connection required after the initial model setup.
- **Thermal-aware** — Inference is serialized and respects system thermal state so the phone stays usable.
- **Memory-conscious** — Images are decoded and resized with streaming paths where it matters; the FIFO queue keeps memory predictable.
- **Semantic search** — Natural-language style discovery over your vault using on-device embeddings and fallbacks.

---

## Architecture at a glance

| Area | What it does |
| --- | --- |
| **Inference** | MLX Swift VLM pipeline; streaming decode paths for camera input |
| **Memory** | SwiftData models, external thumbnail storage, bounded queues |
| **Thermal** | `ThermalMonitor` bridges `NotificationCenter` to `AsyncStream`; work pauses when the system needs headroom |
| **Concurrency** | Swift 6–ready code paths; `VLMInferenceActor` and a FIFO queue for ordered inference |
| **Search** | `NLEmbedding` semantic search with a two-phase fallback strategy |

Source layout: `Grasp/Models`, `Grasp/Managers`, `Grasp/Views`, plus `GraspTests` and `GraspUITests`.

---

## Requirements

| | |
| --- | --- |
| **Xcode** | 26+ (matches `LastUpgradeCheck` / iOS SDK in the project) |
| **SDK** | iOS 26.x (deployment target is set in the Xcode project) |
| **Device** | Physical iPhone recommended (camera, Neural Engine). **A17 Pro** or newer is ideal for MLX performance |

---

## Getting started

1. **Clone** this repository.  
2. **Open** `Grasp.xcodeproj` in Xcode (Swift Package Manager dependencies resolve via the checked-in `Package.resolved`).  
3. **Select** your team and a **physical device** for camera and ML workloads.  
4. **Build and run.** On first launch, the app may **download model weights** over the network; after that, core flows can run without cloud inference.

### Continuous integration

[`.github/workflows/ci.yml`](.github/workflows/ci.yml) builds the app for the **iOS Simulator** and runs **`GraspTests`** on pushes and pull requests to `main`. It uses the **latest Xcode** available on GitHub’s `macos-15` runner; your project targets **iOS 26.4**, so if a hosted runner does not yet ship that SDK, run the same `xcodebuild` command on a Mac with **Xcode 26.4+** or use a self-hosted runner until images catch up.

---

## Privacy

Processing is designed to stay **on-device**. Grasp does not rely on a Grasp-operated backend for core capture → understand → store flows. For wording suitable for stores and reviewers, see [`Docs/PRIVACY_POLICY.md`](Docs/PRIVACY_POLICY.md) and [`Docs/APP_STORE_REVIEW_NOTES.md`](Docs/APP_STORE_REVIEW_NOTES.md).

---

## Documentation

| Document | Purpose |
| --- | --- |
| [`Docs/PRIVACY_POLICY.md`](Docs/PRIVACY_POLICY.md) | Privacy policy template |
| [`Docs/APP_STORE_REVIEW_NOTES.md`](Docs/APP_STORE_REVIEW_NOTES.md) | Reviewer-facing technical notes |
| [`Docs/QA_DESTRUCTION_MATRIX.md`](Docs/QA_DESTRUCTION_MATRIX.md) | Stress and edge-case QA scenarios |

---

## Pricing (App Store)

**$39.99** lifetime — one purchase, ongoing use as shipped in the store listing.

---

## License

Released under the [MIT License](LICENSE).

---

## Credits

- **[MLX Swift](https://github.com/ml-explore/mlx-swift)** — on-device ML on Apple Silicon  
- **Apple frameworks** — SwiftUI, SwiftData, Vision, Natural Language, and system APIs  

---

<p align="center">
  <sub>Grasp V1.0 · Built with Swift 6 and MLX Swift</sub>
</p>
