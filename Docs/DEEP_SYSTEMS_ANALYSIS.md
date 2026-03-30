# Multi-Layer Systems Analysis — Grasp V1.0

Critical assessment across five dimensions. For strategy and governance, see [`MARKET_WHOLESOMENESS_PLAN.md`](MARKET_WHOLESOMENESS_PLAN.md).

---

## 1. Technical integrity

**Strengths**

- Swift 6–friendly isolation: `VLMInferenceActor` serializes MLX work; `ThermalMonitor` bridges UI state on the main actor.
- Memory-aware paths: streaming decode (`CGImageSource`) and bounded resize before queueing inference payloads.
- Thermal handling: event-driven `AsyncStream` from `thermalStateDidChangeNotification` instead of polling.

**Risks**

- **Unbounded queue** was a failure mode for rapid capture; mitigated with a **configurable cap** (see `GraspAppConfiguration` and `Info.plist`).
- **Tests** under-cover actor + MLX integration; prioritize targeted tests and manual QA from [`QA_DESTRUCTION_MATRIX.md`](QA_DESTRUCTION_MATRIX.md).
- **Model / MLX API drift** when upgrading SmolVLM or MLX Swift — keep model ID and prompts versioned.

**Optionality (2027–2030)**

- Keep extraction schema and prompts documented so new VLMs can slot in without cloud dependencies.
- Prefer Apple-first storage (SwiftData) and local automation (Shortcuts) over any network feature.

---

## 2. Economic sustainability

**Unit economics (illustrative)**

- List **$39.99** one-time; after store fee, net per sale is lower — model support and updates from that pool.
- Fixed costs: Apple Developer Program, optional LFS/CDN if you self-host weights later.

**Risks**

- **LTV is capped** — funding ongoing work needs **volume**, **add-ons**, or **team deals**, not subscriptions (by design).
- **Support** can scale poorly without docs and clear scope.

---

## 3. User relationship

**Trust primitives**

- **Air-gap story** is strongest when network use is limited to **model acquisition** and system services — keep docs honest.
- **No account** reduces breach surface and aligns with “Data Not Collected.”
- **Thermal respect** is visible proof of “not mining the device.”

**Sticky without lock-in**

- Value grows through **Spotlight**, **semantic search**, and **structured vault** — not proprietary cloud lock-in.

---

## 4. Ecosystem position

**Differentiation**

- On-device VLM + thermal-aware queue + lifetime positioning vs subscription cloud scanners.

**Risks**

- Incumbents can add **offline modes**; moat is **execution**, **trust**, and **reference-quality** MLX patterns.

**Partnerships**

- Legal-tech and compliance-adjacent channels if exports stay **local** and **user-controlled**.

---

## 5. Societal impact

**Positive**

- Normalizes **local inference** for sensitive documents.
- Reduces dependency on opaque APIs for basic capture → structure workflows.

**Responsibility**

- Avoid overselling accuracy; document limits of small VLMs.
- If Grasp is cited as “ethical AI,” keep audits and reproducible build notes where possible.
