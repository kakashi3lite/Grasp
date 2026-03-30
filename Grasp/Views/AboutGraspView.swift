import SwiftUI

/// In-app mirror of `Docs/FOUNDERS_PLEDGE.md` in the repository.
///
/// **Why duplicate text here?**
/// - The App Store build must show the pledge **offline**.
/// - Keep this view in sync when editing the markdown pledge.
struct AboutGraspView: View {

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Grasp V1.0")
                        .font(.system(.title2, design: .monospaced).bold())
                    Text("Air-gapped spatial knowledge. On-device MLX Swift inference.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    pledgeSection(title: "Privacy", lines: [
                        "Grasp does not upload your captures to Grasp-operated servers.",
                        "No account is required.",
                        "No third-party analytics SDKs in the shipping app definition (verify each release).",
                    ])

                    pledgeSection(title: "Pricing", lines: [
                        "One-time purchase: see the App Store listing.",
                        "No subscription tier.",
                        "No cloud sync for sale.",
                    ])

                    pledgeSection(title: "Hardware", lines: [
                        "Inference respects thermal state — the queue may pause when the device needs headroom.",
                        "Efficiency is prioritized over raw speed when the system is under stress.",
                    ])

                    pledgeSection(title: "Openness", lines: [
                        "Extraction schema lives in the open source tree (see repository).",
                        "Succession and escrow intent: see Docs/COMMUNITY_GOVERNANCE.md in the repo.",
                    ])

                    Text("Contact: swanandtanavade100@gmail.com")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func pledgeSection(title: String, lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            ForEach(lines, id: \.self) { line in
                Text("• \(line)")
                    .font(.body)
            }
        }
    }
}

#Preview {
    AboutGraspView()
}
