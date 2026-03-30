# QA Destruction Matrix — Grasp

Five high-risk scenarios. Each should have an automated or manual pass before release.

## 1. AsyncStream race

**Goal:** No use-after-free or double-completion when thermal or inference streams overlap.  
**How:** Rapid thermal transitions while inference is queued; assert no crashes and FIFO ordering preserved.

## 2. Memory pressure

**Goal:** No jetsam under repeated full-resolution capture + inference.  
**How:** Instruments Allocations + Memory Graph; simulate memory warning; verify caches drop and app survives.

## 3. File atomicity

**Goal:** Model or cache writes never leave half-written files that crash the parser.  
**How:** Write to temp + `rename` pattern where applicable; kill app mid-download; relaunch must recover or re-download cleanly.

## 4. Thermal background continuity

**Goal:** When device gets hot, work pauses or queues without corrupting state.  
**How:** Stress test while blocking fans; verify UI remains responsive and queue drains when safe.

## 5. Airplane Mode + Spotlight deep-link

**Goal:** Offline behavior is safe; deep links do not assume network.  
**How:** Enable Airplane Mode; exercise vault/search and any URL schemes; no blank screens or crashes.

## 6. FIFO queue depth (memory bound)

**Goal:** Rapid capture cannot grow the pending inference queue without limit (`GraspMaxPendingInferenceJobs` in `Configuration/GraspConfiguration.plist`).  
**How:** Stress-test capture faster than inference; expect a user-visible error once the cap is hit, not jetsam.

## 7. Core Spotlight index / de-index observability

**Goal:** Every successful VLM extraction is indexed; vault deletes remove Spotlight entries; failures are visible during QA without guessing.  
**How:** In **Console.app**, filter **subsystem** `com.grasp.vault` and **category** `spotlight`. After processing a capture, expect a success line (UUID redacted in non-debug streams; thumbnail byte count public). After deleting from the vault, expect a de-index success with a count. If indexing fails, an error line appears—investigate before release.
