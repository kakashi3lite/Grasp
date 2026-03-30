import SwiftUI

/// The Order Quadrant: Hyper-structured, perfect alignment.
/// All text uses semantic font styles (`.caption2`, `.body`, etc.)
/// so the layout scales cleanly with Dynamic Type.
struct ResultCardView: View {

    let entity: CapturedEntity

    /// Scales the decorative category circle with Dynamic Type.
    @ScaledMetric(relativeTo: .title2) private var categoryCircleSize: CGFloat = 48
    @ScaledMetric(relativeTo: .title2) private var categoryEmojiSize: CGFloat = 24

    // [Fix 7] Detect large accessibility sizes to reflow the header.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // MARK: Header
            headerView
                .padding(20)

            Divider()
                .background(Color.white.opacity(0.1))

            // MARK: Summary
            if !entity.summary.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "quote.opening")
                            .imageScale(.small)
                            .foregroundStyle(.gray)
                        Text("SUMMARY")
                            .font(.system(.caption2, design: .monospaced).bold())
                            .foregroundStyle(.gray)
                            .tracking(1)
                    }
                    
                    Text(entity.summary)
                        .font(.system(.body, design: .serif).italic())
                        .foregroundStyle(.white.opacity(0.9))
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
                
                Divider()
                    .background(Color.white.opacity(0.1))
            }

            // MARK: Key Entities
            if !entity.keyEntities.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "list.bullet.rectangle.portrait.fill")
                            .imageScale(.small)
                            .foregroundStyle(Color.emerald)
                        Text("EXTRACTED DATA")
                            .font(.system(.caption2, design: .monospaced).bold())
                            .foregroundStyle(Color.emerald)
                            .tracking(1)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(entity.keyEntities, id: \.self) { item in
                            Label(item, systemImage: "minus")
                                .font(.system(.subheadline, design: .monospaced))
                                .labelStyle(BulletLabelStyle())
                                .foregroundStyle(.white)
                        }
                    }
                }
                .padding(20)
            }
            
            // MARK: Footer
            HStack {
                Spacer()
                Text(entity.date.formatted(date: .abbreviated, time: .shortened).uppercased())
                    .font(.system(.caption2, design: .monospaced).bold())
                    .foregroundStyle(.gray.opacity(0.5))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }

    // MARK: - Header (Adaptive Layout)

    /// [Fix 7] At `.accessibility3` and above, the HStack overflows.
    /// Switch to a VStack so the emoji circle stacks above the title.
    @ViewBuilder
    private var headerView: some View {
        if dynamicTypeSize >= .accessibility3 {
            VStack(alignment: .leading, spacing: 12) {
                categoryCircle
                titleStack
            }
        } else {
            HStack(spacing: 16) {
                categoryCircle
                titleStack
                Spacer()
            }
        }
    }

    private var categoryCircle: some View {
        ZStack {
            Circle()
                .fill(Color(UIColor.tertiarySystemBackground))
                .frame(width: categoryCircleSize, height: categoryCircleSize)
            Text(categoryEmoji)
                .font(.system(size: categoryEmojiSize))
        }
    }

    private var titleStack: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entity.category.uppercased())
                .font(.system(.caption2, design: .monospaced).weight(.bold))
                .foregroundStyle(.gray)
                .tracking(1.5)

            Text(entity.title)
                .font(.system(.title2, design: .rounded).bold())
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Helpers

    private var categoryEmoji: String {
        switch entity.category.lowercased() {
        case "receipt":      return "🧾"
        case "document":     return "📄"
        case "note", "notes":return "📝"
        case "object":       return "📦"
        default:             return "📋"
        }
    }
}

// MARK: - Monospaced Bullet Label Style

/// Renders a small dash icon followed by wrapping text.
/// Uses `.imageScale` instead of fixed pixel sizes so the
/// bullet scales proportionally with Dynamic Type.
private struct BulletLabelStyle: LabelStyle {

    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            configuration.icon
                .imageScale(.small)
                .foregroundStyle(.gray.opacity(0.5))
            configuration.title
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
