# App Store Review Notes — Grasp

This document supports App Review with concise proof points.

## MLX local inference

- Vision-language inference runs **on-device** via **MLX Swift**.  
- No server is required for core capture → understand → store flows.  
- Network use is limited to **first-launch model download** and standard system services.

## Network declaration

- Declare **model download** if applicable (one-time or updates).  
- No third-party analytics or ad SDKs in the shipping binary (verify before each release).

## Memory and thermal safety

- Inference is serialized through a **FIFO actor** to avoid concurrent model pressure.  
- **ThermalMonitor** observes `ProcessInfo` thermal state and can defer work.  
- Large images use **streaming decode** (`CGImageSource`) where implemented.

## Content policy

- The app does not generate harmful content by design; it **describes** camera frames and stored entities.  
- User-generated content stays local unless the user exports it.

## Privacy attestation

- **Data Not Collected** aligns with on-device processing and no account requirement.  
- Camera is used for the stated feature only; see `PRIVACY_POLICY.md`.
