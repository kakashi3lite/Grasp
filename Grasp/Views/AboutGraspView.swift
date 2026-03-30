import SwiftUI

/// In-app mirror of `Docs/FOUNDERS_PLEDGE.md` in the repository.
///
/// **Why duplicate text here?**
/// - The App Store build must show the pledge **offline**.
/// - Keep this view in sync when editing the markdown pledge.
///
/// **Visual contract:** Matches the Grasp design system — deep black, glass cards,
/// monospaced data typography, emerald/amber accents (see `ContentView` color extensions).
struct AboutGraspView: View {

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                // Full-bleed dark canvas; avoids `systemGroupedBackground` which fights dark mode.
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Hero: rounded brand title + monospaced tagline (emerald glow accent).
                        VStack(alignment: .leading, spacing: 8) {
                            Text("GRASP")
                                .font(.system(.largeTitle, design: .rounded).bold())
                                .foregroundStyle(.white)
                                .shadow(color: Color.emerald.opacity(0.25), radius: 12, y: 4)

                            Text("V1.0 · Air-gapped spatial knowledge · On-device MLX Swift inference.")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(Color.emerald)
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        pledgeSection(
                            title: "PRIVACY",
                            icon: "lock.shield.fill",
                            accent: Color.emerald,
                            lines: [
                                "Grasp does not upload your captures to Grasp-operated servers.",
                                "No account is required.",
                                "No third-party analytics SDKs in the shipping app definition (verify each release).",
                            ]
                        )

                        pledgeSection(
                            title: "PRICING",
                            icon: "tag.fill",
                            accent: Color.amber,
                            lines: [
                                "One-time purchase: see the App Store listing.",
                                "No subscription tier.",
                                "No cloud sync for sale.",
                            ]
                        )

                        pledgeSection(
                            title: "HARDWARE",
                            icon: "thermometer.medium",
                            accent: Color.amber,
                            lines: [
                                "Inference respects thermal state — the queue may pause when the device needs headroom.",
                                "Efficiency is prioritized over raw speed when the system is under stress.",
                            ]
                        )

                        pledgeSection(
                            title: "OPENNESS",
                            icon: "text.badge.checkmark",
                            accent: .gray,
                            lines: [
                                "Extraction schema lives in the open source tree (see repository).",
                                "Succession and escrow intent: see Docs/COMMUNITY_GOVERNANCE.md in the repo.",
                            ]
                        )

                        Text("swanandtanavade100@gmail.com")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.gray.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 8)
                    }
                    .padding(24)
                }
            }
            .preferredColorScheme(.dark)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("ABOUT")
                        .font(.system(.headline, design: .monospaced).bold())
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
        }
    }

    // MARK: - Pledge card (glass + accent border)

    /// One pledge block: glassmorphism card, SF Symbol header, monospaced body lines.
    /// Uses `.fixedSize(horizontal: false, vertical: true)` so Dynamic Type (AX5) never clips.
    private func pledgeSection(
        title: String,
        icon: String,
        accent: Color,
        lines: [String]
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .imageScale(.medium)
                    .foregroundStyle(accent)
                Text(title)
                    .font(.system(.caption, design: .monospaced).bold())
                    .foregroundStyle(accent)
                    .tracking(2)
            }

            ForEach(lines, id: \.self) { line in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Image(systemName: "minus")
                        .imageScale(.small)
                        .foregroundStyle(accent.opacity(0.5))
                    Text(line)
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.88))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(accent.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 12, y: 6)
    }
}

#Preview {
    AboutGraspView()
}
