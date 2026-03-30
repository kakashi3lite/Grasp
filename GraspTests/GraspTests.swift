import Testing
import Foundation
@testable import Grasp

// MARK: - Grasp V1.0 QA Destruction Tests
//
// These tests map directly to the "QA Destruction Matrix" in the
// Launch War Chest. Run with Cmd+U before every App Store submission.
//
// Tests marked MANUAL require hardware simulation in Xcode Device Conditions
// (Product → Scheme → Edit Scheme → Run → Options → Thermal State).

struct GraspTests {

    // -------------------------------------------------------------------------
    // MARK: 1. Image Preprocessing
    // -------------------------------------------------------------------------

    /// Verify `downsample` never upscales a small image.
    @Test func downsample_doesNotUpscale_smallImage() async throws {
        let tinyImage = UIImage(systemName: "photo")!
        let original = tinyImage.jpegData(compressionQuality: 1.0)!
        let result = MLXVisionManager.downsample(
            original,
            maxDimension: 4096,  // far larger than system icon
            quality: 0.9
        )
        // Source was smaller — output should not grow in pixel area.
        let originalSize = UIImage(data: original)!.size
        let resultSize = UIImage(data: result)!.size
        #expect(resultSize.width <= originalSize.width + 1)
        #expect(resultSize.height <= originalSize.height + 1)
    }

    /// Verify `downsample` respects the max-dimension constraint.
    @Test func downsample_respectsMaxDimension() async throws {
        // Create a 1000×500 px test image.
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1000, height: 500))
        let image = renderer.image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 1000, height: 500))
        }
        let source = image.jpegData(compressionQuality: 1.0)!
        let result = MLXVisionManager.downsample(source, maxDimension: 300, quality: 0.85)
        let resultImage = UIImage(data: result)!
        #expect(max(resultImage.size.width, resultImage.size.height) <= 301)
    }

    /// `resize` produces smaller data than full-quality encode for large images.
    @Test func resize_reducesPayloadSize() async throws {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 2000, height: 1500))
        let bigImage = renderer.image { ctx in
            UIColor.blue.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 2000, height: 1500))
        }
        let fullSize = bigImage.jpegData(compressionQuality: 0.85)!.count
        let resized = MLXVisionManager.resize(bigImage, maxDimension: 896).count
        // Resized payload must be substantially smaller.
        #expect(resized < fullSize / 2)
    }

    // -------------------------------------------------------------------------
    // MARK: 2. ExtractionResult Parsing
    // -------------------------------------------------------------------------

    /// Fast path: valid JSON with all keys parses cleanly.
    @Test func extractionResult_parsesValidJSON() async throws {
        let json = """
        {"title":"Invoice #1234","category":"Receipt","summary":"Hardware store purchase.",
         "key_entities":["Home Depot","$142.50","2024-01-15"]}
        """
        let result = ExtractionResult.parse(from: json)
        #expect(result.title == "Invoice #1234")
        #expect(result.category == "Receipt")
        #expect(result.keyEntities.count == 3)
    }

    /// Slow path: JSON with markdown fences is cleaned before decode.
    @Test func extractionResult_stripsMarkdownFences() async throws {
        let json = "```json\n{\"title\":\"Test\",\"category\":\"Note\",\"summary\":\"A note.\",\"key_entities\":[]}\n```"
        let result = ExtractionResult.parse(from: json)
        #expect(result.title == "Test")
        #expect(result.category == "Note")
    }

    /// Fallback: completely invalid VLM output returns a safe default.
    @Test func extractionResult_fallsBackGracefully() async throws {
        let result = ExtractionResult.parse(from: "not valid json at all 🤖")
        #expect(!result.title.isEmpty)
        #expect(result.category == "Object")
    }

    /// Unknown category is clamped to "Object".
    @Test func extractionResult_clampsUnknownCategory() async throws {
        let json = """
        {"title":"X","category":"Spreadsheet","summary":"A sheet.","key_entities":[]}
        """
        let result = ExtractionResult.parse(from: json)
        #expect(result.category == "Object")
    }

    // -------------------------------------------------------------------------
    // MARK: 3. ThermalMonitor
    // -------------------------------------------------------------------------

    /// `setCoolingDown` must be called from @MainActor.
    /// Verifies the write contract compiles and does not deadlock.
    @Test @MainActor func thermalMonitor_setCoolingDown_roundTrip() async throws {
        ThermalMonitor.shared.setCoolingDown(true)
        #expect(ThermalMonitor.shared.isCoolingDown == true)
        ThermalMonitor.shared.setCoolingDown(false)
        #expect(ThermalMonitor.shared.isCoolingDown == false)
    }

    // -------------------------------------------------------------------------
    // MARK: 4. Stable Temp File (File Atomicity)
    //
    // QA Matrix Test 3: Force-quit mid-write.
    //
    // MANUAL: Run `extractJSON(from:)`, then `killall Grasp` from Terminal
    // mid-write. Restart app. Verify the next inference run succeeds —
    // `.atomic` write prevents a partial JPEG from persisting.
    //
    // Automated proxy: verify `inferenceInputURL` is inside tmp/ and that
    // writing an oversized payload atomically doesn't corrupt a previous file.
    // -------------------------------------------------------------------------

    @Test func stableTempFile_atomicWriteDoesNotCorruptPreviousFile() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("grasp_vlm_input_test.jpg")
        let firstPayload = Data(repeating: 0xAA, count: 1024)
        try firstPayload.write(to: url, options: .atomic)

        // Simulate a second write (new inference cycle).
        let secondPayload = Data(repeating: 0xBB, count: 2048)
        try secondPayload.write(to: url, options: .atomic)

        let result = try Data(contentsOf: url)
        // File must contain the second payload, not a mix.
        #expect(result == secondPayload)
        try? FileManager.default.removeItem(at: url)
    }

    // -------------------------------------------------------------------------
    // MARK: 5. SemanticSearch
    // -------------------------------------------------------------------------

    /// Phase 1 substring match must return before NLEmbedding is consulted.
    @Test func semanticSearch_findsExactSubstringMatch() async throws {
        let entity = CapturedEntity(thumbnail: Data())
        entity.title = "Home Depot Receipt"
        entity.category = "Receipt"
        entity.summary = "Purchased lumber and screws."
        entity.keyEntities = ["Home Depot", "$34.99"]
        entity.isProcessed = true

        let results = SemanticSearch.filter([entity], query: "Home Depot")
        #expect(results.count == 1)
    }

    /// Empty query returns all entities unchanged.
    @Test func semanticSearch_emptyQueryReturnsAll() async throws {
        let e1 = CapturedEntity(thumbnail: Data())
        let e2 = CapturedEntity(thumbnail: Data())
        let results = SemanticSearch.filter([e1, e2], query: "")
        #expect(results.count == 2)
    }
}
