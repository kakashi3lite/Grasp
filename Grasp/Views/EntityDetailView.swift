import SwiftUI

/// Absolute control over the data. 
/// Features the Hacker Toggle and a massive Export button.
/// All text uses semantic font styles for full Dynamic Type support.
struct EntityDetailView: View {

    let entity: CapturedEntity
    @State private var showRawJSON = false

    /// Scales the terminal traffic-light dots with Dynamic Type.
    @ScaledMetric(relativeTo: .caption) private var trafficDotSize: CGFloat = 10

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                thumbnailSection
                
                hackerToggle
                
                if showRawJSON {
                    terminalBox
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    ResultCardView(entity: entity)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                exportButton
                    .padding(.top, 16)
            }
            .padding(20)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(entity.title.uppercased())
                    .font(.system(.headline, design: .monospaced).bold())
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showRawJSON)
    }

    // MARK: - Thumbnail

    private var thumbnailSection: some View {
        Group {
            if let img = UIImage(data: entity.thumbnail) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .black.opacity(0.6), radius: 15, y: 10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            }
        }
    }

    // MARK: - The Hacker Toggle

    private var hackerToggle: some View {
        HStack {
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .imageScale(.medium)
                .foregroundStyle(showRawJSON ? Color.emerald : .gray)
            
            Text("RAW DATA")
                .font(.system(.subheadline, design: .monospaced).bold())
                .foregroundStyle(showRawJSON ? .white : .gray)
            
            Spacer()
            
            Toggle("", isOn: $showRawJSON)
                .labelsHidden()
                .tint(Color.emerald)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(UIColor.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Terminal Box

    private var terminalBox: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Circle().fill(.red).frame(width: trafficDotSize, height: trafficDotSize)
                Circle().fill(.yellow).frame(width: trafficDotSize, height: trafficDotSize)
                Circle().fill(.green).frame(width: trafficDotSize, height: trafficDotSize)
                Spacer()
                Text("vlm_output.json")
                    .font(.system(.caption2, design: .monospaced).bold())
                    .foregroundStyle(.gray)
            }
            .padding(12)
            .background(Color(UIColor.secondarySystemBackground))
            
            Divider().background(Color.white.opacity(0.1))
            
            Text(formattedJSON)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Color.emerald)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(UIColor.secondarySystemBackground), lineWidth: 2)
        )
    }

    // MARK: - Massive Export Button

    private var exportButton: some View {
        Menu {
            ShareLink("Export as CSV", item: csvRow)
            ShareLink("Export as Text", item: formattedTextExport)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "square.and.arrow.up.fill")
                    .imageScale(.large)
                Text("EXPORT DATA")
                    .font(.system(.headline, design: .rounded).bold())
                    .tracking(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(Color.white)
            .foregroundStyle(.black)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .white.opacity(0.15), radius: 10, y: 5)
        }
    }

    // MARK: - Export Data Builders

    private var csvRow: String {
        let header = "Title,Category,Summary,Key Entities,Date"
        let fields = [
            entity.title,
            entity.category,
            entity.summary,
            entity.keyEntities.joined(separator: "; "),
            entity.date.formatted(),
        ]
        let escaped = fields
            .map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"" }
            .joined(separator: ",")
        return header + "\n" + escaped
    }

    private var formattedTextExport: String {
        """
        [GRASP EXPORT]
        TITLE: \(entity.title)
        CATEGORY: \(entity.category)
        DATE: \(entity.date.formatted())
        
        SUMMARY:
        \(entity.summary)
        
        ENTITIES:
        \(entity.keyEntities.map { "- \($0)" }.joined(separator: "\n"))
        """
    }

    // MARK: - JSON Pretty-Print

    private var formattedJSON: String {
        let raw = entity.extractedText
        guard
            let data = raw.data(using: .utf8),
            let obj = try? JSONSerialization.jsonObject(with: data),
            let pretty = try? JSONSerialization.data(
                withJSONObject: obj,
                options: [.prettyPrinted, .sortedKeys]
            ),
            let str = String(data: pretty, encoding: .utf8)
        else { return raw }
        return str
    }
}
