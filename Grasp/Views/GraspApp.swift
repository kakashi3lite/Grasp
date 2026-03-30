import SwiftData
import SwiftUI

@main
struct GraspApp: App {

    /// Single container shared by SwiftUI (main context) and
    /// the inference actor (background context).
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([CapturedEntity.self])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        do {
            return try ModelContainer(
                for: schema,
                configurations: [config]
            )
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        // [Fix 3] Capture the container locally so the closure
        // doesn't reference `self` before init completes.
        let container = sharedModelContainer
        Task { @MainActor in
            await VLMInferenceActor.shared.configure(container: container)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
