import SwiftUI

struct IdentityEvidenceItem: Identifiable {
    let id: String
    let question: String
    let value: String
    let evidence: String
    let symbolName: String
    let tone: Int

    init(
        id: String,
        question: String,
        value: String,
        evidence: String,
        symbolName: String,
        tone: Int
    ) {
        self.id = id
        self.question = question
        self.value = value
        self.evidence = evidence
        self.symbolName = symbolName
        self.tone = tone
    }
}

enum IdentityEvidenceFactory {
    static func profile(
        _ profile: BuilderProfile,
        displayTitle: String,
        rank: BuilderIdentityRank
    ) -> [IdentityEvidenceItem] {
        let strongest = profile.dimensions.max { $0.score < $1.score }
        let growth = profile.dimensions.min { $0.score < $1.score }
        let sessions = profile.evidenceSessions > 0
            ? profile.evidenceSessions
            : profile.usage.sessions
        let activeDays = profile.evidenceActiveDays > 0
            ? profile.evidenceActiveDays
            : profile.usage.activeDays
        let rarity = profile.rarity > 0
            ? String(format: "%.1f%%", profile.rarity)
            : "--"

        return [
            IdentityEvidenceItem(
                id: "identity",
                question: "Which kind of builder are you?",
                value: displayTitle,
                evidence: profile.displayMotto,
                symbolName: "crown",
                tone: 0
            ),
            IdentityEvidenceItem(
                id: "rank",
                question: "How established is the pattern?",
                value: rank.label,
                evidence: "\(sessions) local sessions shaped this edition.",
                symbolName: "flag.checkered",
                tone: 1
            ),
            IdentityEvidenceItem(
                id: "sessions",
                question: "How much work shaped this identity?",
                value: sessions > 0 ? "\(sessions) sessions" : "Not analyzed",
                evidence: "Private Codex sessions indexed on this Mac.",
                symbolName: "rectangle.stack",
                tone: 2
            ),
            IdentityEvidenceItem(
                id: "active-days",
                question: "How long did the pattern hold?",
                value: activeDays > 0 ? "\(activeDays) active days" : "Window pending",
                evidence: "Observed days in the selected local analysis window.",
                symbolName: "calendar",
                tone: 3
            ),
            IdentityEvidenceItem(
                id: "strongest",
                question: "What carries your work?",
                value: strongest.map { "\($0.name) · \($0.score)" } ?? "Signal forming",
                evidence: strongest?.note ?? "Analyze a build window to reveal the strongest repeated signal.",
                symbolName: "waveform.path",
                tone: 4
            ),
            IdentityEvidenceItem(
                id: "growth",
                question: "Where is the next frontier?",
                value: growth.map { "\($0.name) · \($0.score)" } ?? "Frontier unknown",
                evidence: profile.growthEdge,
                symbolName: "scope",
                tone: 5
            ),
            IdentityEvidenceItem(
                id: "proof",
                question: "How much proof survived?",
                value: profile.proofScore > 0 ? "\(profile.proofScore) / 100" : "No score yet",
                evidence: "Aggregate evidence strength from the local report.",
                symbolName: "checkmark.seal",
                tone: 6
            ),
            IdentityEvidenceItem(
                id: "repeat",
                question: "What do you keep doing?",
                value: profile.signatureMoves.first ?? "No repeated move yet",
                evidence: profile.signatureMoves.count > 1
                    ? "\(profile.signatureMoves.count) repeated moves were preserved."
                    : "Repeated behavior appears after analysis.",
                symbolName: "repeat",
                tone: 7
            ),
            IdentityEvidenceItem(
                id: "stance",
                question: "How do you operate?",
                value: profile.stance,
                evidence: "\(profile.archetype) · generated \(profile.generatedAt)",
                symbolName: "point.3.connected.trianglepath.dotted",
                tone: 8
            ),
            IdentityEvidenceItem(
                id: "rarity",
                question: "How unusual is this form?",
                value: rarity,
                evidence: profile.rarity > 0
                    ? "Rarity reported by the generated identity."
                    : "Rarity was not included in this edition.",
                symbolName: "sparkles",
                tone: 9
            ),
        ]
    }

    static func report(_ report: SavedBuilderReport) -> [IdentityEvidenceItem] {
        let rank = BuilderIdentityRank.resolve(
            evidenceScore: report.evidenceScore,
            sessions: report.sessions
        )
        return [
            IdentityEvidenceItem(
                id: "report-identity",
                question: "Which builder form was saved?",
                value: report.presentationTitle,
                evidence: report.presentationMotto,
                symbolName: report.symbolName,
                tone: 0
            ),
            IdentityEvidenceItem(
                id: "report-rank",
                question: "How established was the pattern?",
                value: rank.label,
                evidence: "\(report.sessions) sessions · \(report.activeDays) active days",
                symbolName: "flag.checkered",
                tone: 1
            ),
            IdentityEvidenceItem(
                id: "report-signal",
                question: "What carried the work?",
                value: report.strongestDimension.map { "\($0.name) · \($0.score)" } ?? "Signal not stored",
                evidence: report.strongestDimension?.note ?? "This edition predates dimension evidence.",
                symbolName: "waveform.path",
                tone: 2
            ),
        ]
    }
}

struct BuilderIdentityReportExperience: View {
    @EnvironmentObject private var model: TokenBarModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var page: Int
    let displayTitle: String
    let displayMotto: String
    let rank: BuilderIdentityRank
    let accent: Color
    let openDimension: (BuilderDimension) -> Void

    @State private var selectedEvidence: IdentityEvidenceItem?

    private let chapters = [
        "Identity wall",
        "Narrative",
        "AI modes",
        "Pressure map",
        "Next quest",
    ]

    private var evidence: [IdentityEvidenceItem] {
        IdentityEvidenceFactory.profile(
            model.profile,
            displayTitle: displayTitle,
            rank: rank
        )
    }

    private var strongest: BuilderDimension? {
        model.profile.dimensions.max { $0.score < $1.score }
    }

    private var growth: BuilderDimension? {
        model.profile.dimensions.min { $0.score < $1.score }
    }

    private var rankedDimensions: [BuilderDimension] {
        model.profile.dimensions.sorted { $0.score > $1.score }
    }
    private var identitySeed: Int {
        displayTitle.unicodeScalars.reduce(0) { ($0 &* 31) &+ Int($1.value) }
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                IdentityReportPaper(seed: identitySeed)
                reportContent
                    .id(page)
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        )
                    )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            IdentityChapterRail(
                chapters: chapters,
                selection: $page,
                next: move
            )
        }
        .background(IdentityPaperPalette.paper)
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(IdentityPaperPalette.ink.opacity(0.20), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .shadow(color: Color.black.opacity(0.22), radius: 28, y: 14)
        .animation(reduceMotion ? .linear(duration: 0.1) : .easeInOut(duration: 0.32), value: page)
        .sheet(item: $selectedEvidence) { item in
            IdentityEvidenceDetail(item: item)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Builder identity report, \(chapters[page]), chapter \(page + 1) of \(chapters.count)")
    }

    @ViewBuilder
    private var reportContent: some View {
        switch page {
        case 0:
            identityWall
        case 1:
            narrative
        case 2:
            aiModes
        case 3:
            pressureMap
        default:
            nextQuest
        }
    }

    private var identityWall: some View {
        VStack(alignment: .leading, spacing: 15) {
            IdentityReportMasthead(
                eyebrow: "TokenBar field report",
                title: "What this edition found",
                copy: "Ten questions. Only local aggregate evidence. Open any ticket to inspect what it means.",
                folio: rank.label
            )

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5),
                spacing: 8
            ) {
                ForEach(Array(evidence.enumerated()), id: \.element.id) { index, item in
                    Button {
                        selectedEvidence = item
                    } label: {
                        IdentityEvidenceTicket(item: item, index: index)
                    }
                    .buttonStyle(.plain)
                    .help("Inspect \(item.question)")
                }
            }
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 22)
    }

    private var narrative: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                Text("YOUR NARRATIVE")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(IdentityPaperPalette.orange)
                Text("You are")
                    .font(.system(size: 20, weight: .medium, design: .serif))
                    .foregroundStyle(IdentityPaperPalette.mutedInk)
                Text(displayTitle)
                    .font(.system(size: 43, weight: .bold, design: .serif))
                    .foregroundStyle(IdentityPaperPalette.ink)
                    .lineLimit(3)
                    .minimumScaleFactor(0.66)
                Text(displayMotto)
                    .font(.system(size: 17, weight: .medium, design: .serif))
                    .italic()
                    .foregroundStyle(IdentityPaperPalette.orange)
                    .lineSpacing(4)
                    .lineLimit(4)
                Text(model.profile.subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(IdentityPaperPalette.mutedInk)
                    .lineSpacing(4)
                    .lineLimit(5)
                    .padding(.top, 6)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(36)

            VStack(alignment: .leading, spacing: 0) {
                IdentityNarrativeBand(
                    index: "01",
                    title: strongest?.name ?? "Signal forming",
                    copy: strongest?.note ?? "Analyze a build window to reveal the strongest repeated pattern.",
                    value: strongest.map { "\($0.score)" } ?? "--",
                    tint: IdentityPaperPalette.orange
                ) {
                    if let strongest {
                        openDimension(strongest)
                    }
                }

                IdentityNarrativeBand(
                    index: "02",
                    title: "Repeated move",
                    copy: model.profile.signatureMoves.first ?? "No repeated move has been saved yet.",
                    value: "\(model.profile.signatureMoves.count)",
                    tint: IdentityPaperPalette.blue,
                    action: nil
                )

                IdentityNarrativeBand(
                    index: "03",
                    title: "Operating stance",
                    copy: "\(model.profile.archetype) · \(model.profile.stance)",
                    value: "\(model.profile.proofScore)",
                    tint: IdentityPaperPalette.gold,
                    action: nil
                )
            }
            .frame(width: 410)
            .background(IdentityPaperPalette.paperShadow.opacity(0.55))
        }
        .overlay(alignment: .center) {
            Rectangle()
                .fill(IdentityPaperPalette.ink.opacity(0.14))
                .frame(width: 1)
        }
    }

    private var aiModes: some View {
        VStack(alignment: .leading, spacing: 18) {
            IdentityReportMasthead(
                eyebrow: "How you use AI",
                title: "Your operating modes",
                copy: "Memorable names for measured dimensions, not a personality quiz.",
                folio: "\(rankedDimensions.count) signals"
            )

            if rankedDimensions.isEmpty {
                IdentityReportEmptyState(
                    title: "No modes mapped yet",
                    copy: "Analyze a local build window to turn repeated behavior into inspectable operating modes."
                )
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12),
                    ],
                    spacing: 12
                ) {
                    ForEach(Array(rankedDimensions.prefix(4).enumerated()), id: \.element.id) { index, dimension in
                        Button {
                            openDimension(dimension)
                        } label: {
                            IdentityModePlate(
                                title: modeTitle(for: dimension, index: index),
                                dimension: dimension,
                                index: index
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, 36)
        .padding(.vertical, 26)
    }

    private var pressureMap: some View {
        HStack(spacing: 0) {
            IdentityPressureColumn(
                eyebrow: "What is already working",
                title: "Your leverage",
                dimensions: Array(rankedDimensions.prefix(3)),
                tint: IdentityPaperPalette.blue,
                select: openDimension
            )
            IdentityPressureColumn(
                eyebrow: "What deserves pressure",
                title: "Your frontier",
                dimensions: Array(rankedDimensions.suffix(3).reversed()),
                tint: IdentityPaperPalette.orange,
                select: openDimension
            )
        }
        .overlay(alignment: .center) {
            Rectangle()
                .fill(IdentityPaperPalette.ink.opacity(0.16))
                .frame(width: 1)
        }
    }

    private var nextQuest: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 28) {
                VStack(alignment: .leading, spacing: 13) {
                    Text("NEXT QUEST")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(IdentityPaperPalette.orange)
                    Text("Build the next advantage.")
                        .font(.system(size: 42, weight: .bold, design: .serif))
                        .foregroundStyle(IdentityPaperPalette.ink)
                    Text(model.profile.growthEdge)
                        .font(.system(size: 18, weight: .medium, design: .serif))
                        .italic()
                        .foregroundStyle(IdentityPaperPalette.orange)
                        .lineSpacing(5)
                        .lineLimit(5)
                    Text("This recommendation is derived from the weakest saved dimension and the generated local growth edge. It is a direction, not a claim of completion.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(IdentityPaperPalette.mutedInk)
                        .lineSpacing(4)
                        .frame(maxWidth: 620, alignment: .leading)
                }

                Spacer()

                IdentityQuestSeal(
                    score: growth?.score,
                    name: growth?.name ?? "Frontier forming"
                )
            }
            .padding(40)

            Spacer(minLength: 16)

            HStack(spacing: 18) {
                IdentityQuestAction(
                    symbol: "arrow.down.doc",
                    title: "Keep the edition",
                    copy: "Export the generated local report."
                ) {
                    model.exportProofPacket()
                }
                .disabled(model.profile.sourceURL == nil || model.isExportingProof)

                IdentityQuestAction(
                    symbol: "checkmark.shield",
                    title: "Inspect the proof",
                    copy: "\(model.profile.proofScore) / 100 evidence strength · local aggregate only"
                ) {
                    if let strongest {
                        openDimension(strongest)
                    }
                }
                .disabled(strongest == nil)

                IdentityQuestAction(
                    symbol: "arrow.counterclockwise",
                    title: "Return to the wall",
                    copy: "Review every question in this edition."
                ) {
                    move(0)
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 34)
        }
    }

    private func modeTitle(for dimension: BuilderDimension, index: Int) -> String {
        let name = dimension.name.lowercased()
        if name.contains("plan") || name.contains("scope") {
            return "Chaos Cartographer"
        }
        if name.contains("steer") || name.contains("prompt") || name.contains("direct") {
            return "Signal Captain"
        }
        if name.contains("ship") || name.contains("finish") || name.contains("deliver") {
            return "Last-Mile Sovereign"
        }
        if name.contains("recover") || name.contains("repair") || name.contains("debug") {
            return "Failure Warden"
        }
        if name.contains("proof") || name.contains("evidence") || name.contains("verify") {
            return "Proof Smuggler"
        }
        return [
            "Frame Breaker",
            "Systems Corsair",
            "Architect's Veto",
            "Thread Conductor",
        ][index % 4]
    }

    private func move(_ destination: Int) {
        let bounded = min(max(destination, 0), chapters.count - 1)
        withAnimation(reduceMotion ? .linear(duration: 0.1) : .easeInOut(duration: 0.32)) {
            page = bounded
        }
    }
}

struct AssignedIdentityTexture: View {
    let style: BuilderIdentityStyle

    private var palette: (primary: Color, secondary: Color) {
        TokenBarTheme.identityPalette(style.paletteIndex)
    }

    private var seed: Int {
        style.id.unicodeScalars.reduce(0) { ($0 &* 31) &+ Int($1.value) }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    TokenBarTheme.panel,
                    palette.primary.opacity(0.28),
                    palette.secondary.opacity(0.12),
                    TokenBarTheme.canvas,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Canvas { context, size in
                switch abs(seed % 3) {
                case 0:
                    let center = CGPoint(x: size.width * 0.78, y: size.height * 0.42)
                    stride(from: CGFloat(26), through: max(size.width, size.height), by: 24).forEach { radius in
                        let rect = CGRect(
                            x: center.x - radius,
                            y: center.y - radius,
                            width: radius * 2,
                            height: radius * 2
                        )
                        context.stroke(
                            Path(ellipseIn: rect),
                            with: .color(palette.primary.opacity(0.12)),
                            lineWidth: 1
                        )
                    }
                case 1:
                    let spacing: CGFloat = 22
                    stride(from: -size.height, through: size.width, by: spacing).forEach { offset in
                        var path = Path()
                        path.move(to: CGPoint(x: offset, y: 0))
                        path.addLine(to: CGPoint(x: offset + size.height, y: size.height))
                        context.stroke(
                            path,
                            with: .color(palette.secondary.opacity(0.11)),
                            lineWidth: 1
                        )
                    }
                default:
                    let spacing: CGFloat = 28
                    stride(from: CGFloat(0), through: size.width, by: spacing).forEach { x in
                        stride(from: CGFloat(0), through: size.height, by: spacing).forEach { y in
                            let wave = sin(Double(x + y + CGFloat(seed % 97)) * 0.04)
                            let diameter = CGFloat(2.5 + abs(wave) * 5)
                            context.fill(
                                Path(ellipseIn: CGRect(x: x, y: y, width: diameter, height: diameter)),
                                with: .color(palette.primary.opacity(0.14))
                            )
                        }
                    }
                }
            }

            LinearGradient(
                colors: [Color.clear, TokenBarTheme.canvas.opacity(0.64)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct IdentityEvidenceRail: View {
    let title: String
    let items: [IdentityEvidenceItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title.uppercased())
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(IdentityPaperPalette.orange)
                Spacer()
                Text("LOCAL FIELD NOTES")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(TokenBarTheme.secondary)
            }
            HStack(spacing: 10) {
                ForEach(Array(items.prefix(3).enumerated()), id: \.element.id) { index, item in
                    IdentityEvidenceTicket(item: item, index: index, compact: true)
                }
            }
        }
    }
}

struct IdentityReportEditionCard: View {
    let report: SavedBuilderReport
    @State private var hovered = false

    private var evidence: [IdentityEvidenceItem] {
        IdentityEvidenceFactory.report(report)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                IdentityHalftoneTexture(
                    seed: report.emblemSignature,
                    tint: IdentityPaperPalette.orange,
                    density: 0.34
                )
                LinearGradient(
                    colors: [Color.clear, IdentityPaperPalette.paper.opacity(0.74)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                HStack {
                    Image(systemName: report.symbolName)
                        .font(.system(size: 27, weight: .bold))
                        .foregroundStyle(IdentityPaperPalette.ink)
                    Spacer()
                    Text(report.windowLabel.uppercased())
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(IdentityPaperPalette.ink)
                }
                .padding(14)
            }
            .frame(height: 72)

            IdentityPerforation()

            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text(report.generatedAt.formatted(date: .abbreviated, time: .omitted))
                    Spacer()
                    Text(report.shareURL == nil ? "LOCAL" : "LINKED")
                }
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(IdentityPaperPalette.orange)

                Text(report.presentationTitle)
                    .font(.system(size: 21, weight: .bold, design: .serif))
                    .foregroundStyle(IdentityPaperPalette.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)

                Text(report.presentationMotto)
                    .font(.system(size: 10, weight: .medium, design: .serif))
                    .italic()
                    .foregroundStyle(IdentityPaperPalette.mutedInk)
                    .lineLimit(2)

                HStack(spacing: 12) {
                    Label("\(report.sessions)", systemImage: "rectangle.stack")
                    Label("\(report.windowDays)d", systemImage: "calendar")
                    if let strongest = report.strongestDimension {
                        Label("\(strongest.score)", systemImage: "waveform.path")
                    }
                }
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(IdentityPaperPalette.ink.opacity(0.74))
            }
            .padding(15)
        }
        .frame(maxWidth: .infinity, minHeight: 254, alignment: .topLeading)
        .background(IdentityPaperPalette.paper)
        .overlay {
            RoundedRectangle(cornerRadius: 5)
                .stroke(
                    hovered ? IdentityPaperPalette.orange : IdentityPaperPalette.ink.opacity(0.22),
                    lineWidth: hovered ? 1.5 : 1
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .shadow(color: Color.black.opacity(hovered ? 0.20 : 0.10), radius: hovered ? 18 : 8, y: 8)
        .scaleEffect(hovered ? 1.012 : 1)
        .animation(.snappy(duration: 0.22), value: hovered)
        .onHover { hovered = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(report.presentationTitle), \(report.windowLabel)")
    }
}

struct BuilderCohortLens: View {
    let profile: BuilderProfile
    let displayTitle: String
    let reports: [SavedBuilderReport]

    private var comparisonReports: [SavedBuilderReport] {
        var latestByIdentity: [String: SavedBuilderReport] = [:]
        for report in reports.sorted(by: { $0.generatedAt > $1.generatedAt }) {
            let key = report.presentationTitle.lowercased()
            if latestByIdentity[key] == nil, key != displayTitle.lowercased() {
                latestByIdentity[key] = report
            }
        }
        return Array(latestByIdentity.values)
    }

    private var cohortSize: Int { comparisonReports.count + 1 }

    private var rank: Int {
        1 + comparisonReports.filter { $0.evidenceScore > profile.proofScore }.count
    }

    private var percentileLabel: String {
        guard cohortSize >= 3 else { return "Waiting for a valid cohort" }
        let topShare = Int(ceil((Double(rank) / Double(cohortSize)) * 100))
        return "Top \(topShare)% in this local set"
    }

    private var averageProof: Int? {
        guard !comparisonReports.isEmpty else { return nil }
        return comparisonReports.map(\.evidenceScore).reduce(0, +) / comparisonReports.count
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("COHORT LENS")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(IdentityPaperPalette.orange)
                Text(percentileLabel)
                    .font(.system(size: 25, weight: .bold, design: .serif))
                    .foregroundStyle(IdentityPaperPalette.ink)
                Text(
                    cohortSize >= 3
                        ? "Rank \(rank) of \(cohortSize) distinct identities by evidence strength."
                        : "Add \(max(0, 3 - cohortSize)) more distinct identity report\(3 - cohortSize == 1 ? "" : "s") before TokenBar calculates a comparison."
                )
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(IdentityPaperPalette.mutedInk)
                .lineSpacing(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)

            CohortMeasure(
                value: "\(cohortSize)",
                label: "distinct identities",
                copy: "Latest edition per identity"
            )
            CohortMeasure(
                value: "\(profile.proofScore)",
                label: "your evidence",
                copy: averageProof.map { "Set average \($0)" } ?? "No peer average yet"
            )
            CohortMeasure(
                value: cohortSize >= 3 ? "\(rank) / \(cohortSize)" : "--",
                label: "actual rank",
                copy: "Never estimated or fabricated"
            )
        }
        .background(
            LinearGradient(
                colors: [IdentityPaperPalette.paper, IdentityPaperPalette.paperShadow.opacity(0.52)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .overlay {
            RoundedRectangle(cornerRadius: 5)
                .stroke(IdentityPaperPalette.ink.opacity(0.20), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .accessibilityElement(children: .contain)
    }
}

struct IdentityEvolutionTrack: View {
    let reports: [SavedBuilderReport]

    private var editions: [SavedBuilderReport] {
        let calendar = Calendar.current
        var latestByMonth: [Date: SavedBuilderReport] = [:]
        for report in reports.sorted(by: { $0.generatedAt < $1.generatedAt }) {
            let components = calendar.dateComponents([.year, .month], from: report.generatedAt)
            guard let month = calendar.date(from: components) else { continue }
            latestByMonth[month] = report
        }
        return latestByMonth
            .sorted { $0.key < $1.key }
            .suffix(7)
            .map(\.value)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("IDENTITY EVOLUTION")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(IdentityPaperPalette.orange)
                    Text("How your working form changed")
                        .font(.system(size: 20, weight: .bold, design: .serif))
                        .foregroundStyle(IdentityPaperPalette.ink)
                }
                Spacer()
                Text("Each point is the latest saved edition in that month.")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(IdentityPaperPalette.mutedInk)
            }

            if editions.isEmpty {
                Text("Save identity reports across build windows to reveal the history here.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(IdentityPaperPalette.mutedInk)
                    .frame(maxWidth: .infinity, minHeight: 128, alignment: .center)
            } else {
                GeometryReader { proxy in
                    let count = max(1, editions.count)
                    let step = count == 1 ? 0 : (proxy.size.width - 72) / CGFloat(count - 1)

                    ZStack(alignment: .topLeading) {
                        Rectangle()
                            .fill(IdentityPaperPalette.ink.opacity(0.24))
                            .frame(width: max(0, proxy.size.width - 72), height: 2)
                            .offset(x: 36, y: 26)

                        ForEach(Array(editions.enumerated()), id: \.element.id) { index, report in
                            let tint = IdentityPaperPalette.tone(report.emblemSignature)
                            VStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(IdentityPaperPalette.paper)
                                    Circle()
                                        .stroke(tint, lineWidth: 2)
                                    Image(systemName: report.symbolName)
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(tint)
                                }
                                .frame(width: 30, height: 30)
                                Text(report.generatedAt.formatted(.dateTime.month(.abbreviated).year()))
                                    .font(.system(size: 8, weight: .black, design: .monospaced))
                                    .foregroundStyle(tint)
                                Text(report.presentationTitle)
                                    .font(.system(size: 11, weight: .bold, design: .serif))
                                    .foregroundStyle(IdentityPaperPalette.ink)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.68)
                                if let strongest = report.strongestDimension {
                                    Text("Because \(strongest.name) led at \(strongest.score)")
                                        .font(.system(size: 8, weight: .medium))
                                        .foregroundStyle(IdentityPaperPalette.mutedInk)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                }
                            }
                            .frame(width: 132)
                            .position(
                                x: count == 1 ? proxy.size.width / 2 : 36 + (CGFloat(index) * step),
                                y: 54
                            )
                            .help("\(report.presentationTitle), \(report.sessions) sessions, \(report.windowLabel)")
                        }
                    }
                }
                .frame(height: 104)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                colors: [IdentityPaperPalette.paper, IdentityPaperPalette.paperShadow.opacity(0.46)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay {
            RoundedRectangle(cornerRadius: 5)
                .stroke(IdentityPaperPalette.ink.opacity(0.20), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }
}

private struct CohortMeasure: View {
    let value: String
    let label: String
    let copy: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 25, weight: .black, design: .rounded))
                .foregroundStyle(IdentityPaperPalette.orange)
            Text(label.uppercased())
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(IdentityPaperPalette.ink)
            Text(copy)
                .font(.system(size: 8.5, weight: .medium))
                .foregroundStyle(IdentityPaperPalette.mutedInk)
                .lineLimit(2)
        }
        .padding(18)
        .frame(width: 155, alignment: .leading)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(IdentityPaperPalette.ink.opacity(0.14))
                .frame(width: 1)
        }
    }
}

private enum IdentityPaperPalette {
    static let paper = Color(red: 0.965, green: 0.940, blue: 0.850)
    static let paperShadow = Color(red: 0.905, green: 0.855, blue: 0.720)
    static let ink = Color(red: 0.075, green: 0.078, blue: 0.088)
    static let mutedInk = Color(red: 0.27, green: 0.27, blue: 0.29)
    static let orange = Color(red: 0.93, green: 0.28, blue: 0.13)
    static let blue = Color(red: 0.08, green: 0.33, blue: 0.47)
    static let gold = Color(red: 0.67, green: 0.43, blue: 0.09)

    static func tone(_ index: Int) -> Color {
        [orange, blue, gold, ink][abs(index) % 4]
    }
}

private struct IdentityReportPaper: View {
    var seed = 0

    var body: some View {
        ZStack {
            IdentityPaperPalette.paper
            HStack(spacing: 0) {
                IdentityHalftoneTexture(seed: 11 &+ seed, tint: IdentityPaperPalette.orange, density: 0.36)
                    .frame(width: 42)
                Spacer()
                IdentityHalftoneTexture(seed: 29 &+ seed, tint: IdentityPaperPalette.orange, density: 0.36)
                    .frame(width: 42)
            }
            Canvas { context, size in
                let spacing: CGFloat = 22
                var path = Path()
                stride(from: -size.height, through: size.width, by: spacing).forEach { offset in
                    path.move(to: CGPoint(x: offset, y: 0))
                    path.addLine(to: CGPoint(x: offset + size.height, y: size.height))
                }
                context.stroke(
                    path,
                    with: .color(IdentityPaperPalette.ink.opacity(0.025)),
                    lineWidth: 0.6
                )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct IdentityHalftoneTexture: View {
    let seed: Int
    let tint: Color
    let density: Double

    var body: some View {
        Canvas { context, size in
            let safeSeed = abs(seed % 10_000)
            let spacing: CGFloat = 6
            let rows = Int(size.height / spacing) + 2
            let columns = Int(size.width / spacing) + 2

            for row in 0..<rows {
                for column in 0..<columns {
                    let sample = abs(
                        sin(Double(column * 17 + safeSeed * 13) * 0.31)
                            + cos(Double(row * 11 + safeSeed * 7) * 0.27)
                    ) / 2
                    let wave = (sin(Double(row + column + safeSeed) * 0.19) + 1) / 2
                    guard (sample * 0.68 + wave * 0.32) < density else { continue }
                    let diameter = CGFloat(1.4 + (sample * 2.1))
                    let rect = CGRect(
                        x: CGFloat(column) * spacing,
                        y: CGFloat(row) * spacing,
                        width: diameter,
                        height: diameter
                    )
                    context.fill(Path(ellipseIn: rect), with: .color(tint.opacity(0.78)))
                }
            }
        }
        .accessibilityHidden(true)
    }
}

private struct IdentityReportMasthead: View {
    let eyebrow: String
    let title: String
    let copy: String
    let folio: String

    var body: some View {
        HStack(alignment: .bottom, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text(eyebrow.uppercased())
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(IdentityPaperPalette.orange)
                Text(title)
                    .font(.system(size: 29, weight: .bold, design: .serif))
                    .foregroundStyle(IdentityPaperPalette.ink)
                Text(copy)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(IdentityPaperPalette.mutedInk)
                    .lineLimit(2)
            }
            Spacer()
            Text(folio.uppercased())
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(IdentityPaperPalette.mutedInk)
        }
    }
}

private struct IdentityEvidenceTicket: View {
    let item: IdentityEvidenceItem
    let index: Int
    var compact = false

    private let rotations = [-1.4, 0.8, -0.5, 1.2, -0.8, 0.6, -1.0, 0.9, -0.4, 1.1]
    private let offsets: [CGFloat] = [3, -2, 2, -3, 1, -1, 3, -2, 2, -1]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                IdentityHalftoneTexture(
                    seed: 31 + item.tone,
                    tint: IdentityPaperPalette.tone(item.tone),
                    density: 0.39
                )
                HStack(spacing: 5) {
                    ForEach(0..<3, id: \.self) { _ in
                        Circle()
                            .fill(IdentityPaperPalette.paper)
                            .frame(width: 7, height: 7)
                    }
                }
                .padding(7)
            }
            .frame(height: compact ? 34 : 46)

            IdentityPerforation()

            VStack(alignment: .leading, spacing: compact ? 5 : 6) {
                HStack {
                    Text(item.question.uppercased())
                        .font(.system(size: compact ? 7 : 7.5, weight: .black, design: .monospaced))
                        .foregroundStyle(IdentityPaperPalette.tone(item.tone))
                        .lineLimit(2)
                    Spacer(minLength: 6)
                    Image(systemName: item.symbolName)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(IdentityPaperPalette.tone(item.tone))
                }

                Text(item.value)
                    .font(.system(size: compact ? 15 : 16, weight: .bold, design: .serif))
                    .foregroundStyle(IdentityPaperPalette.ink)
                    .lineLimit(compact ? 1 : 2)
                    .minimumScaleFactor(0.64)

                Text(item.evidence)
                    .font(.system(size: compact ? 8.5 : 9, weight: .medium))
                    .foregroundStyle(IdentityPaperPalette.mutedInk)
                    .lineSpacing(2)
                    .lineLimit(compact ? 2 : 3)
            }
            .padding(compact ? 10 : 11)
        }
        .frame(maxWidth: .infinity, minHeight: compact ? 118 : 151, maxHeight: compact ? 118 : 151, alignment: .topLeading)
        .background(IdentityPaperPalette.paper)
        .overlay {
            RoundedRectangle(cornerRadius: 3)
                .stroke(IdentityPaperPalette.tone(item.tone).opacity(0.48), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .rotationEffect(.degrees(rotations[index % rotations.count]))
        .offset(y: compact ? 0 : offsets[index % offsets.count])
        .shadow(color: Color.black.opacity(0.11), radius: 7, y: 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

private struct IdentityPerforation: View {
    var body: some View {
        Canvas { context, size in
            var path = Path()
            let dash: CGFloat = 4
            stride(from: 0, through: size.width, by: dash * 2).forEach { x in
                path.move(to: CGPoint(x: x, y: 0.5))
                path.addLine(to: CGPoint(x: min(x + dash, size.width), y: 0.5))
            }
            context.stroke(
                path,
                with: .color(IdentityPaperPalette.ink.opacity(0.28)),
                lineWidth: 1
            )
        }
        .frame(height: 1)
        .accessibilityHidden(true)
    }
}

private struct IdentityChapterRail: View {
    let chapters: [String]
    @Binding var selection: Int
    let next: (Int) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(chapters.enumerated()), id: \.offset) { index, chapter in
                Button {
                    next(index)
                } label: {
                    HStack(spacing: 7) {
                        Text(String(format: "%02d", index + 1))
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                        Text(chapter.uppercased())
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .lineLimit(1)
                    }
                    .foregroundStyle(
                        selection == index
                            ? IdentityPaperPalette.paper
                            : IdentityPaperPalette.ink.opacity(0.70)
                    )
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(
                        selection == index
                            ? IdentityPaperPalette.ink
                            : IdentityPaperPalette.paperShadow.opacity(0.55)
                    )
                }
                .buttonStyle(.plain)
                .help("Open \(chapter)")
            }
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(IdentityPaperPalette.ink.opacity(0.18))
                .frame(height: 1)
        }
    }
}

private struct IdentityNarrativeBand: View {
    let index: String
    let title: String
    let copy: String
    let value: String
    let tint: Color
    let action: (() -> Void)?

    init(
        index: String,
        title: String,
        copy: String,
        value: String,
        tint: Color,
        action: (() -> Void)?
    ) {
        self.index = index
        self.title = title
        self.copy = copy
        self.value = value
        self.tint = tint
        self.action = action
    }

    var body: some View {
        Button {
            action?()
        } label: {
            HStack(alignment: .top, spacing: 13) {
                Text(index)
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(tint)
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(title)
                            .font(.system(size: 17, weight: .bold, design: .serif))
                            .foregroundStyle(IdentityPaperPalette.ink)
                        Spacer()
                        Text(value)
                            .font(.system(size: 23, weight: .black, design: .rounded))
                            .foregroundStyle(tint)
                    }
                    Text(copy)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(IdentityPaperPalette.mutedInk)
                        .lineSpacing(3)
                        .lineLimit(3)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(IdentityPaperPalette.ink.opacity(0.13))
                .frame(height: 1)
        }
    }
}

private struct IdentityModePlate: View {
    let title: String
    let dimension: BuilderDimension
    let index: Int

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                IdentityHalftoneTexture(
                    seed: 70 + index,
                    tint: IdentityPaperPalette.tone(index),
                    density: 0.42
                )
                Text("\(dimension.score)")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(IdentityPaperPalette.paper)
                    .shadow(color: IdentityPaperPalette.ink.opacity(0.45), radius: 2)
            }
            .frame(width: 88)

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 21, weight: .bold, design: .serif))
                    .foregroundStyle(IdentityPaperPalette.ink)
                Text(dimension.name.uppercased())
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(IdentityPaperPalette.tone(index))
                Text(dimension.note)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(IdentityPaperPalette.mutedInk)
                    .lineSpacing(3)
                    .lineLimit(3)
            }
            .padding(.vertical, 15)
            .padding(.trailing, 15)
        }
        .frame(maxWidth: .infinity, minHeight: 132, maxHeight: 132, alignment: .leading)
        .background(IdentityPaperPalette.paperShadow.opacity(0.40))
        .overlay {
            RoundedRectangle(cornerRadius: 4)
                .stroke(IdentityPaperPalette.ink.opacity(0.18), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .contentShape(Rectangle())
    }
}

private struct IdentityPressureColumn: View {
    let eyebrow: String
    let title: String
    let dimensions: [BuilderDimension]
    let tint: Color
    let select: (BuilderDimension) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(eyebrow.uppercased())
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(tint)
            Text(title)
                .font(.system(size: 34, weight: .bold, design: .serif))
                .foregroundStyle(IdentityPaperPalette.ink)

            if dimensions.isEmpty {
                Text("Analyze a local build window to map this side of the report.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(IdentityPaperPalette.mutedInk)
            } else {
                ForEach(Array(dimensions.enumerated()), id: \.element.id) { index, dimension in
                    Button {
                        select(dimension)
                    } label: {
                        HStack(alignment: .top, spacing: 13) {
                            Text(String(format: "%02d", index + 1))
                                .font(.system(size: 8, weight: .black, design: .monospaced))
                                .foregroundStyle(tint)
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(dimension.name)
                                        .font(.system(size: 17, weight: .bold, design: .serif))
                                    Spacer()
                                    Text("\(dimension.score)")
                                        .font(.system(size: 23, weight: .black, design: .rounded))
                                        .foregroundStyle(tint)
                                }
                                Text(dimension.note)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(IdentityPaperPalette.mutedInk)
                                    .lineLimit(3)
                                    .lineSpacing(3)
                            }
                        }
                        .foregroundStyle(IdentityPaperPalette.ink)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(IdentityPaperPalette.ink.opacity(0.14))
                            .frame(height: 1)
                    }
                }
            }
            Spacer()
        }
        .padding(36)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct IdentityQuestSeal: View {
    let score: Int?
    let name: String

    var body: some View {
        ZStack {
            Circle()
                .stroke(IdentityPaperPalette.orange, lineWidth: 2)
            Circle()
                .stroke(
                    IdentityPaperPalette.orange.opacity(0.50),
                    style: StrokeStyle(lineWidth: 1, dash: [3, 4])
                )
                .padding(9)
            VStack(spacing: 3) {
                Text(score.map(String.init) ?? "--")
                    .font(.system(size: 46, weight: .black, design: .rounded))
                Text(name.uppercased())
                    .font(.system(size: 7, weight: .black, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 18)
            }
            .foregroundStyle(IdentityPaperPalette.ink)
        }
        .frame(width: 160, height: 160)
        .rotationEffect(.degrees(-4))
    }
}

private struct IdentityQuestAction: View {
    let symbol: String
    let title: String
    let copy: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(IdentityPaperPalette.orange)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold, design: .serif))
                    Text(copy)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(IdentityPaperPalette.mutedInk)
                        .lineLimit(2)
                }
                Spacer()
            }
            .foregroundStyle(IdentityPaperPalette.ink)
            .padding(15)
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .topLeading)
            .background(IdentityPaperPalette.paperShadow.opacity(0.42))
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(IdentityPaperPalette.ink.opacity(0.19), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct IdentityReportEmptyState: View {
    let title: String
    let copy: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 27, weight: .bold, design: .serif))
                .foregroundStyle(IdentityPaperPalette.ink)
            Text(copy)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(IdentityPaperPalette.mutedInk)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

private struct IdentityEvidenceDetail: View {
    @Environment(\.dismiss) private var dismiss
    let item: IdentityEvidenceItem

    var body: some View {
        ZStack {
            IdentityReportPaper()
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("EVIDENCE TICKET")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(IdentityPaperPalette.orange)
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(IdentityPaperPalette.ink)
                }

                Image(systemName: item.symbolName)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(IdentityPaperPalette.tone(item.tone))
                Text(item.question)
                    .font(.system(size: 15, weight: .bold, design: .serif))
                    .foregroundStyle(IdentityPaperPalette.mutedInk)
                Text(item.value)
                    .font(.system(size: 34, weight: .bold, design: .serif))
                    .foregroundStyle(IdentityPaperPalette.ink)
                    .lineLimit(3)
                    .minimumScaleFactor(0.70)
                Text(item.evidence)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(IdentityPaperPalette.mutedInk)
                    .lineSpacing(5)

                Spacer()

                Label(
                    "Local aggregate evidence. Full prompts, transcripts, source code, paths, and credentials are not shown.",
                    systemImage: "lock.shield"
                )
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(IdentityPaperPalette.ink.opacity(0.72))
            }
            .padding(28)
        }
        .frame(width: 520, height: 390)
    }
}
