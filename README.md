# Grasp

**Air-gapped spatial knowledge for your pocket.** Capture documents and scenes, understand them with **on-device** vision–language inference, and search your vault—without sending camera frames to a Grasp-operated server.

[![Swift](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)](https://swift.org)
[![iOS](https://img.shields.io/badge/iOS-26-007AFF?logo=apple&logoColor=white)](https://developer.apple.com/ios/)
[![MLX Swift](https://img.shields.io/badge/MLX-Swift-34C759)](https://github.com/ml-explore/mlx-swift)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![CI](https://github.com/kakashi3lite/Grasp/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/kakashi3lite/Grasp/actions/workflows/ci.yml)

## Contents

- [Overview](#overview)
- [Features](#features)
- [Architecture](#architecture)
- [Requirements](#requirements)
- [Getting started](#getting-started)
- [Configuration](#configuration)
- [Build, test, and CI](#build-test-and-ci)
- [Privacy](#privacy)
- [Documentation](#documentation)
- [Pricing](#pricing)
- [Founders pledge](#founders-pledge)
- [License](#license)
- [Credits](#credits)

---

## Overview

Grasp targets people who want **ownership** over their data: **one-time purchase**, **local inference** via [MLX Swift](https://github.com/ml-explore/mlx-swift), and **SwiftData** so captures stay on the device. Subscriptions and cloud-first OCR are the default elsewhere; Grasp is the opposite for core flows.

| Principle | What it means in practice |
| --- | --- |
| **On-device** | VLM runs locally; network is not required for capture → extract → store after initial model setup. |
| **No account** | Core features work without sign-in (see privacy docs for store labels). |
| **Hardware respect** | Serialized inference, thermal-aware pausing, bounded FIFO queue, streaming image decode. |

---

## Features

- **On-device VLM** — Structured extraction (title, category, summary, key entities) via a small quantized model.
- **Thermal-aware pipeline** — Work pauses when the system reports serious/critical thermal state; UI reflects cooling.
- **Memory-conscious path** — Downsampling and `CGImageSource` thumbnails so peak memory tracks output size, not raw camera resolution.
- **FIFO inference queue** — One job at a time through `VLMInferenceActor`; configurable max pending jobs.
- **Vault and search** — SwiftData persistence, Core Spotlight indexing, semantic-style filtering with `NLEmbedding` and fallbacks.

---

## Architecture

| Layer | Role |
| --- | --- |
| **Inference** | MLX Swift VLM; stable temp file + atomic write for model input |
| **Concurrency** | Swift 6–friendly isolation; `VLMInferenceActor` + FIFO drain loop |
| **Thermal** | `ProcessInfo` notifications → `AsyncStream`; `ThermalMonitor` for SwiftUI |
| **Persistence** | SwiftData `CapturedEntity`, external thumbnail storage |
| **Discovery** | Core Spotlight + deep link from system search |
| **Diagnostics** | On-device `os.Logger` only (subsystem `com.grasp.vault`). The `spotlight` category records index and de-index success or failure—no titles or summaries in log strings (privacy-safe QA in Console.app). |

**Repository layout**

| Path | Contents |
| --- | --- |
| `Grasp/` | App sources: `Models/`, `Managers/`, `Views/` |
| `Configuration/` | `GraspConfiguration.plist` merged via `INFOPLIST_FILE` (not under `Grasp/` to avoid duplicate `Info.plist` processing) |
| `GraspTests/` | Unit tests (Swift Testing) |
| `GraspUITests/` | UI tests |
| `Docs/` | Privacy, review notes, QA matrix, governance, pledge |

---

## Requirements

| Item | Notes |
| --- | --- |
| **Xcode** | 26+ (matches project SDK) |
| **Deployment** | iOS 26.x (see Xcode project) |
| **Device** | Physical iPhone recommended for camera and MLX; **A17 Pro** or newer is ideal for performance |

---

## Getting started

1. Clone the repository.
2. Open `Grasp.xcodeproj` in Xcode (SPM uses checked-in `Package.resolved`).
3. Select your development team and a **physical device** for camera and ML (simulator is fine for builds/tests that do not need the full pipeline).
4. **Product → Run**. On first launch, **model weights** may download; after that, core flows do not depend on Grasp-operated cloud inference.

---

## Configuration

Runtime tuning lives in [`Configuration/GraspConfiguration.plist`](Configuration/GraspConfiguration.plist). Xcode merges this file into the app’s `Info.plist` via **Build Settings → `INFOPLIST_FILE`**. It is kept **outside** the synchronized `Grasp/` folder so it is not copied as a bundle resource (which would conflict with generated `Info.plist` output).

| Key | Purpose |
| --- | --- |
| `GraspMLXModelID` | HuggingFace / MLX model identifier (default: SmolVLM 4-bit instruct) |
| `GraspMaxPendingInferenceJobs` | Cap on pending FIFO jobs (memory bound under rapid capture) |

---

## Build, test, and CI

**Local**

```bash
xcodebuild \
  -project Grasp.xcodeproj \
  -scheme Grasp \
  -destination 'generic/platform=iOS Simulator' \
  -sdk iphonesimulator \
  -only-testing:GraspTests \
  test
```

Use a concrete simulator destination if `generic` is unsupported on your toolchain (e.g. `-destination 'platform=iOS Simulator,name=iPad (A16),OS=26.4'`).

**CI** — [`.github/workflows/ci.yml`](.github/workflows/ci.yml) runs on pushes and PRs to `main` with the **latest Xcode** available on the runner. If the hosted image lags **iOS 26.4**, run the same command on a Mac with **Xcode 26.4+** or use a self-hosted runner.

---

## Privacy

Processing is designed to stay **on-device**. Grasp does not rely on a Grasp-operated backend for core capture → understand → store flows.

| Resource | Use |
| --- | --- |
| [`Docs/PRIVACY_POLICY.md`](Docs/PRIVACY_POLICY.md) | Policy template |
| [`Docs/APP_STORE_REVIEW_NOTES.md`](Docs/APP_STORE_REVIEW_NOTES.md) | App Review technical notes |

---

## Documentation

### Product and store

| Document | Purpose |
| --- | --- |
| [`Docs/PRIVACY_POLICY.md`](Docs/PRIVACY_POLICY.md) | Privacy policy template |
| [`Docs/APP_STORE_REVIEW_NOTES.md`](Docs/APP_STORE_REVIEW_NOTES.md) | Reviewer-facing notes |
| [`Docs/QA_DESTRUCTION_MATRIX.md`](Docs/QA_DESTRUCTION_MATRIX.md) | High-risk QA scenarios |

### Strategy and governance

| Document | Purpose |
| --- | --- |
| [`Docs/DEEP_SYSTEMS_ANALYSIS.md`](Docs/DEEP_SYSTEMS_ANALYSIS.md) | Five-layer systems analysis |
| [`Docs/MARKET_WHOLESOMENESS_PLAN.md`](Docs/MARKET_WHOLESOMENESS_PLAN.md) | Sustainable growth without breaking core commitments |
| [`Docs/COMMUNITY_GOVERNANCE.md`](Docs/COMMUNITY_GOVERNANCE.md) | Roadmap process, audits, succession intent |
| [`Docs/FOUNDERS_PLEDGE.md`](Docs/FOUNDERS_PLEDGE.md) | Public ethical commitment |
| [`Docs/GITHUB_ROADMAP_LABELS.md`](Docs/GITHUB_ROADMAP_LABELS.md) | Issue labels for transparent roadmap |

---

## Pricing

**$39.99** lifetime — one purchase, ongoing use as described in the App Store listing.

---

## Founders pledge

Full text: [`Docs/FOUNDERS_PLEDGE.md`](Docs/FOUNDERS_PLEDGE.md). A short in-app summary is available from **Vault** → **info** (About).

---

## License

Released under the [MIT License](LICENSE).

---

## Credits

- [MLX Swift](https://github.com/ml-explore/mlx-swift) — on-device ML on Apple Silicon  
- Apple frameworks — SwiftUI, SwiftData, Vision, Natural Language, Core Spotlight, and system APIs  

---

<p align="center"><sub>Grasp V1.0 · Swift 6 · MLX Swift</sub></p>
