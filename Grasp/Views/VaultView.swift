import CoreSpotlight
import SwiftData
import SwiftUI

/// The "Vault" — The feeling of infinite, organized memory.
struct VaultView: View {

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CapturedEntity.date, order: .reverse)
    private var allEntities: [CapturedEntity]

    @State private var searchText = ""
    /// Founder's pledge and ethics (see `Docs/FOUNDERS_PLEDGE.md`).
    @State private var showAbout = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                // [Fix 2] Converted from ScrollView+LazyVStack to List
                // so `.onDelete` produces the native swipe affordance.
                List {
                    if !processingEntities.isEmpty {
                        Section {
                            ForEach(processingEntities) { entity in
                                EntityRowView(entity: entity)
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                            }
                        } header: {
                            sectionHeader("Processing Queue", icon: "cpu", color: Color.amber)
                        }
                    }

                    Section {
                        if filteredEntities.isEmpty && !searchText.isEmpty {
                            ContentUnavailableView.search(text: searchText)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        } else {
                            ForEach(filteredEntities) { entity in
                                NavigationLink {
                                    EntityDetailView(entity: entity)
                                } label: {
                                    EntityRowView(entity: entity)
                                }
                                .buttonStyle(.plain)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                            }
                            .onDelete(perform: deleteEntities)
                        }
                    } header: {
                        if !searchText.isEmpty {
                            sectionHeader("Results", icon: "magnifyingglass", color: .gray)
                        } else {
                            sectionHeader("Vault", icon: "archivebox.fill", color: .white)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            // [Fix 4] Removed duplicate `.navigationTitle("Memory")` and
            // `.navigationBarTitleDisplayMode(.inline)`. The custom toolbar
            // principal item below is the authoritative title.
            .searchable(text: $searchText, prompt: "Search semantic memory...")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("MEMORY")
                        .font(.system(.headline, design: .monospaced).bold())
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAbout = true
                    } label: {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .accessibilityLabel("About Grasp and founder pledge")
                }
            }
            .sheet(isPresented: $showAbout) {
                AboutGraspView()
                    .preferredColorScheme(.dark)
            }
            .overlay {
                if allEntities.isEmpty {
                    ContentUnavailableView(
                        "Vault is Empty",
                        systemImage: "lock.slash.fill",
                        description: Text("Snap a photo to create a secure memory.")
                    )
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func sectionHeader(_ title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(title.uppercased())
                .font(.system(.caption, design: .monospaced).bold())
                .foregroundStyle(.gray)
            Spacer()
        }
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Computed Collections

    private var processingEntities: [CapturedEntity] {
        allEntities.filter { !$0.isProcessed }
    }

    private var processedEntities: [CapturedEntity] {
        allEntities.filter { $0.isProcessed }
    }

    private var filteredEntities: [CapturedEntity] {
        if searchText.isEmpty { return processedEntities }
        return SemanticSearch.filter(processedEntities, query: searchText)
    }

    // MARK: - Delete & De-index

    /// Deletes entities from SwiftData AND removes their corresponding
    /// Spotlight index entries so stale results don't surface in Search.
    private func deleteEntities(at offsets: IndexSet) {
        let toDelete = offsets.map { filteredEntities[$0] }
        let uuids = toDelete.map { $0.id.uuidString }
        for entity in toDelete {
            modelContext.delete(entity)
        }
        try? modelContext.save()

        // De-index from Core Spotlight (fire-and-forget); log outcome for QA / Console.
        Task {
            do {
                try await CSSearchableIndex.default()
                    .deleteSearchableItems(withIdentifiers: uuids)
                GraspLogger.spotlight.info(
                    "Spotlight de-index OK count=\(uuids.count, privacy: .public)"
                )
            } catch {
                GraspLogger.spotlight.error(
                    "Spotlight de-index failed: \(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }
}

// MARK: - Entity Row

/// Uses semantic font styles (`.body`, `.caption`, `.caption2`)
/// so text scales cleanly with Dynamic Type.  Thumbnail stays
/// fixed — it's visual content, not text.
struct EntityRowView: View {

    let entity: CapturedEntity

    var body: some View {
        HStack(spacing: 16) {
            thumbnailView
            
            VStack(alignment: .leading, spacing: 6) {
                if entity.isProcessed {
                    HStack(alignment: .center, spacing: 8) {
                        Image(systemName: categorySFSymbol)
                            .imageScale(.medium)
                            .foregroundStyle(.gray)
                        
                        Text(entity.title)
                            .font(.system(.body, design: .rounded).bold())
                            .lineLimit(2)
                            .foregroundStyle(.white)
                    }
                    
                    if !entity.summary.isEmpty {
                        Text(entity.summary)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.gray)
                            .lineLimit(2)
                    }
                } else {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.amber)
                            .frame(width: 8, height: 8)
                            .phaseAnimator([false, true]) { content, phase in
                                content.opacity(phase ? 1 : 0.3)
                                    .shadow(color: Color.amber.opacity(phase ? 0.8 : 0), radius: 4)
                            } animation: { _ in .easeInOut(duration: 0.8) }
                            
                        Text("Processing...")
                            .font(.system(.subheadline, design: .monospaced).bold())
                            .foregroundStyle(Color.amber)
                    }
                }
                
                Text(entity.date.formatted(.relative(presentation: .named)))
                    .font(.system(.caption2, design: .monospaced).bold())
                    .foregroundStyle(.gray.opacity(0.5))
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .imageScale(.small)
                .foregroundStyle(.gray.opacity(0.5))
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 5, y: 2)
    }

    // MARK: Helpers

    private var thumbnailView: some View {
        Group {
            if let img = UIImage(data: entity.thumbnail) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle().fill(Color.gray.opacity(0.2))
            }
        }
        .frame(width: 60, height: 60)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    private var categorySFSymbol: String {
        switch entity.category.lowercased() {
        case "receipt":      return "receipt"
        case "document":     return "doc.text.fill"
        case "note", "notes":return "note.text"
        case "object":       return "cube.box.fill"
        default:             return "doc.plaintext.fill"
        }
    }
}
