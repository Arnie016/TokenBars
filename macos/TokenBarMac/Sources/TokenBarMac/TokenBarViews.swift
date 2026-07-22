import AppKit
import SwiftUI
import UniformTypeIdentifiers

enum TokenBarDestination: String, CaseIterable, Identifiable {
    case story = "Builder Story"
    case threads = "Threads"
    case usage = "Usage"
    case proof = "Proof"
    case opportunities = "Opportunities"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .story: "sparkles.rectangle.stack"
        case .threads: "rectangle.3.group"
        case .usage: "chart.xyaxis.line"
        case .proof: "checkmark.seal"
        case .opportunities: "paperplane"
        }
    }
}

struct TokenBarRootView: View {
    @EnvironmentObject private var model: TokenBarModel
    @State private var selection: TokenBarDestination? = .story

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                TokenBarBrand()
                    .padding(.horizontal, 14)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                List(TokenBarDestination.allCases, selection: $selection) { destination in
                    Label(destination.rawValue, systemImage: destination.icon)
                        .font(.system(size: 13, weight: .medium))
                        .tag(destination)
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)

                Spacer(minLength: 10)

                VStack(alignment: .leading, spacing: 9) {
                    SectionLabel(text: "Local evidence")
                    HStack {
                        Circle()
                            .fill(model.profile.sourceURL == nil ? TokenBarTheme.amber : TokenBarTheme.green)
                            .frame(width: 7, height: 7)
                        Text(model.profile.sourceURL == nil ? "Awaiting analysis" : "Private · on this Mac")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(TokenBarTheme.secondary)
                    }
                    Text(model.activityMessage)
                        .font(.system(size: 11))
                        .foregroundStyle(TokenBarTheme.secondary)
                        .lineLimit(2)
                }
                .padding(16)
            }
            .background(TokenBarTheme.sidebar)
            .navigationSplitViewColumnWidth(min: 210, ideal: 228, max: 248)
        } detail: {
            Group {
                switch selection ?? .story {
                case .story: BuilderStoryView()
                case .threads: ThreadsView()
                case .usage: UsageView()
                case .proof: ProofView()
                case .opportunities: OpportunitiesView()
                }
            }
            .background(TokenBarTheme.canvas)
        }
        .tint(TokenBarTheme.green)
        .background(TokenBarTheme.canvas)
        .alert("TokenBar needs attention", isPresented: Binding(
            get: { model.lastError != nil },
            set: { if !$0 { model.lastError = nil } }
        )) {
            Button("OK", role: .cancel) { model.lastError = nil }
        } message: {
            Text(model.lastError ?? "Unknown error")
        }
    }
}

private struct TokenBarBrand: View {
    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(TokenBarTheme.text)
                    .frame(width: 30, height: 30)
                Image(systemName: "circle.hexagongrid.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(TokenBarTheme.canvas)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("TokenBar")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(TokenBarTheme.text)
                Text("Builder intelligence")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(TokenBarTheme.secondary)
            }
            Spacer()
        }
    }
}

private struct PageChrome<Trailing: View>: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    let trailing: Trailing

    init(eyebrow: String, title: String, subtitle: String, @ViewBuilder trailing: () -> Trailing) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading, spacing: 5) {
                SectionLabel(text: eyebrow)
                Text(title)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(TokenBarTheme.text)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(TokenBarTheme.secondary)
            }
            Spacer(minLength: 20)
            trailing
        }
    }
}

private struct BuilderStoryView: View {
    @EnvironmentObject private var model: TokenBarModel
    @State private var appeared = false

    private var accent: Color { TokenBarTheme.accent(for: model.profile.identityTitle) }
    private var strongest: BuilderDimension? { model.profile.dimensions.max { $0.score < $1.score } }
    private var growth: BuilderDimension? { model.profile.dimensions.min { $0.score < $1.score } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageChrome(
                    eyebrow: "Your builder card",
                    title: "Your week, in one read",
                    subtitle: "One identity shape, three conclusions, and the next useful move."
                ) {
                    Button {
                        model.refreshIdentity()
                    } label: {
                        Label(model.isAnalyzing ? "Analyzing…" : "Analyze this week", systemImage: model.isAnalyzing ? "ellipsis" : "sparkles")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(accent)
                    .disabled(model.isAnalyzing)
                }

                TokenBarPanel {
                    HStack(spacing: 24) {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 8) {
                                TokenBarPill(label: "Archetype", value: model.profile.archetype, tint: accent)
                                TokenBarPill(label: "Stance", value: model.profile.stance, tint: TokenBarTheme.cyan)
                            }
                            Text(model.profile.identityTitle)
                                .font(.system(size: 36, weight: .semibold))
                                .foregroundStyle(TokenBarTheme.text)
                                .lineLimit(3)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(model.profile.subtitle)
                                .font(.system(size: 15, weight: .regular))
                                .foregroundStyle(TokenBarTheme.secondary)
                                .lineSpacing(4)
                                .lineLimit(3)
                                .frame(maxWidth: 590, alignment: .leading)
                            HStack(spacing: 18) {
                                MetricInline(value: "\(model.profile.proofScore)", label: "proof")
                                MetricInline(value: "\(model.profile.loopScore)", label: "loop")
                                MetricInline(value: "\(model.profile.usage.sessions)", label: "sessions")
                            }
                        }
                        Spacer(minLength: 10)
                        BuilderRadarChart(dimensions: model.profile.dimensions, accent: accent)
                            .frame(width: 300, height: 235)
                    }
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)

                HStack(alignment: .top, spacing: 14) {
                    StoryBeat(
                        index: "01",
                        title: strongest.map { "You win through \($0.name.lowercased())." } ?? "Your edge is forming.",
                        copy: strongest?.note ?? "Run an analysis to identify the pattern that carries your work.",
                        value: strongest.map { "\($0.score)" } ?? "--",
                        tint: accent
                    )
                    StoryBeat(
                        index: "02",
                        title: growth.map { "Train \($0.name.lowercased()) next." } ?? "The next frontier is unknown.",
                        copy: model.profile.growthEdge,
                        value: growth.map { "\($0.score)" } ?? "--",
                        tint: TokenBarTheme.amber
                    )
                    StoryBeat(
                        index: "03",
                        title: "Your week had weight.",
                        copy: "\(model.profile.usage.sessions) sessions across \(model.profile.usage.activeDays) active days. Private until you publish a proof.",
                        value: model.profile.usage.last7,
                        tint: TokenBarTheme.cyan
                    )
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 18)

                HStack(alignment: .top, spacing: 14) {
                    TokenBarPanel {
                        VStack(alignment: .leading, spacing: 14) {
                            SectionLabel(text: "What the evidence says")
                            ForEach(Array(model.profile.signatureMoves.prefix(4).enumerated()), id: \.offset) { index, move in
                                HStack(alignment: .top, spacing: 11) {
                                    Text(String(format: "%02d", index + 1))
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .foregroundStyle(accent)
                                    Text(move)
                                        .font(.system(size: 13))
                                        .foregroundStyle(TokenBarTheme.text)
                                        .lineSpacing(3)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    TokenBarPanel {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionLabel(text: "Unexpected signal")
                            if let fact = model.profile.facts.first {
                                Text(fact.value)
                                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                                    .foregroundStyle(accent)
                                Text(fact.label)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(TokenBarTheme.text)
                                Text(fact.copy)
                                    .font(.system(size: 12))
                                    .foregroundStyle(TokenBarTheme.secondary)
                                    .lineSpacing(3)
                            } else {
                                Text("Analyze a week to reveal the small, strange signals that make the profile yours.")
                                    .foregroundStyle(TokenBarTheme.secondary)
                            }
                        }
                        .frame(width: 250, alignment: .leading)
                    }
                }
            }
            .padding(30)
            .frame(maxWidth: 1120, alignment: .leading)
        }
        .background(TokenBarTheme.canvas)
        .onAppear {
            withAnimation(.easeOut(duration: 0.55)) { appeared = true }
        }
    }
}

private struct MetricInline: View {
    let value: String
    let label: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(value)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(TokenBarTheme.text)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(TokenBarTheme.secondary)
        }
    }
}

private struct BuilderRadarChart: View {
    let dimensions: [BuilderDimension]
    let accent: Color
    @State private var appeared = false

    private var signals: [BuilderDimension] { Array(dimensions.prefix(6)) }

    var body: some View {
        VStack(spacing: 4) {
            if signals.count >= 3 {
                Canvas { context, size in
                    let center = CGPoint(x: size.width / 2, y: size.height / 2 + 3)
                    let radius = min(size.width, size.height) * 0.35
                    let count = signals.count

                    func point(index: Int, scale: CGFloat) -> CGPoint {
                        let angle = -CGFloat.pi / 2 + (2 * CGFloat.pi * CGFloat(index) / CGFloat(count))
                        return CGPoint(
                            x: center.x + cos(angle) * radius * scale,
                            y: center.y + sin(angle) * radius * scale
                        )
                    }

                    for level in 1...4 {
                        var grid = Path()
                        for index in 0..<count {
                            let value = point(index: index, scale: CGFloat(level) / 4)
                            index == 0 ? grid.move(to: value) : grid.addLine(to: value)
                        }
                        grid.closeSubpath()
                        context.stroke(grid, with: .color(TokenBarTheme.border.opacity(0.8)), lineWidth: 0.8)
                    }

                    for index in 0..<count {
                        var axis = Path()
                        axis.move(to: center)
                        axis.addLine(to: point(index: index, scale: 1))
                        context.stroke(axis, with: .color(TokenBarTheme.border.opacity(0.7)), lineWidth: 0.7)
                    }

                    var profile = Path()
                    for (index, signal) in signals.enumerated() {
                        let animatedScale = appeared ? CGFloat(signal.score) / 100 : 0.08
                        let value = point(index: index, scale: animatedScale)
                        index == 0 ? profile.move(to: value) : profile.addLine(to: value)
                    }
                    profile.closeSubpath()
                    context.fill(profile, with: .color(accent.opacity(0.20)))
                    context.stroke(profile, with: .color(accent), lineWidth: 2.2)

                    for (index, signal) in signals.enumerated() {
                        let labelPoint = point(index: index, scale: 1.20)
                        let label = signal.name == "Product instinct" ? "Product" : signal.name
                        context.draw(
                            Text(label.uppercased())
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(TokenBarTheme.secondary),
                            at: labelPoint,
                            anchor: .center
                        )
                    }
                }
                .animation(.easeOut(duration: 0.65), value: appeared)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(signals.map { "\($0.name) \($0.score)" }.joined(separator: ", "))
            } else {
                Image(nsImage: NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath))
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 118, height: 118)
            }

            if let strongest = signals.max(by: { $0.score < $1.score }) {
                HStack(spacing: 7) {
                    Capsule().fill(accent).frame(width: 24, height: 4)
                    Text("\(strongest.name.uppercased()) \(strongest.score)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(TokenBarTheme.text)
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.55).delay(0.12)) { appeared = true }
        }
    }
}

private struct StoryBeat: View {
    let index: String
    let title: String
    let copy: String
    let value: String
    let tint: Color

    var body: some View {
        TokenBarPanel {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(index)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(tint)
                    Spacer()
                    Text(value)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(TokenBarTheme.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(TokenBarTheme.text)
                Text(copy)
                    .font(.system(size: 12))
                    .foregroundStyle(TokenBarTheme.secondary)
                    .lineSpacing(3)
                    .lineLimit(5)
            }
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        }
    }
}

private struct DimensionRow: View {
    let dimension: BuilderDimension
    let tint: Color
    let animate: Bool

    var body: some View {
        HStack(spacing: 13) {
            Text(dimension.name)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(TokenBarTheme.text)
                .frame(width: 112, alignment: .leading)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(TokenBarTheme.raised).frame(height: 5)
                    Capsule().fill(tint).frame(width: animate ? geometry.size.width * CGFloat(dimension.score) / 100 : 0, height: 5)
                        .animation(.easeOut(duration: 0.7).delay(0.12), value: animate)
                }
            }
            .frame(height: 5)
            Text("\(dimension.score)")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(TokenBarTheme.text)
                .frame(width: 28, alignment: .trailing)
            Text(dimension.note)
                .font(.system(size: 11))
                .foregroundStyle(TokenBarTheme.secondary)
                .lineLimit(1)
                .frame(width: 320, alignment: .leading)
        }
        .frame(height: 22)
    }
}

private struct ThreadsView: View {
    @EnvironmentObject private var model: TokenBarModel
    @State private var draftingThread: CodexThread?

    private func threads(in lane: CodexThreadLane) -> [CodexThread] {
        Array(model.codexThreads.filter { $0.lane() == lane }.prefix(7))
    }

    private var activeGoalCount: Int { model.codexThreads.filter { $0.goalStatus == "active" }.count }
    private var forkCount: Int { model.codexThreads.filter(\.isFork).count }
    private var changedWorkspaceCount: Int {
        Set(model.codexThreads.filter { $0.gitReviewState == "changed" }.map(\.cwd)).count
    }
    private var automationCount: Int { model.codexThreads.filter(\.isAutomation).count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageChrome(
                    eyebrow: "Local Codex control",
                    title: "Threads worth finishing",
                    subtitle: "Goals, forks, review state, and follow-up drafts from the Codex work already on this Mac."
                ) {
                    Button {
                        model.refreshThreads()
                    } label: {
                        Label(model.isLoadingThreads ? "Reading…" : "Refresh", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.isLoadingThreads)
                }

                HStack(spacing: 12) {
                    ThreadSummary(value: "\(activeGoalCount)", label: "active goals", tint: TokenBarTheme.green)
                    ThreadSummary(value: "\(forkCount)", label: "forked threads", tint: TokenBarTheme.cyan)
                    ThreadSummary(value: "\(changedWorkspaceCount)", label: "repos to review", tint: TokenBarTheme.amber)
                    ThreadSummary(value: "\(automationCount)", label: "automation threads", tint: TokenBarTheme.secondary)
                }

                TokenBarPanel {
                    HStack(alignment: .top, spacing: 0) {
                        ForEach(CodexThreadLane.allCases) { lane in
                            let index = CodexThreadLane.allCases.firstIndex(of: lane) ?? 0
                            ThreadLaneColumn(lane: lane, threads: threads(in: lane)) { thread in
                                draftingThread = thread
                            }
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                                .padding(.horizontal, index == 0 ? 0 : 18)
                            if index < CodexThreadLane.allCases.count - 1 {
                                Divider().overlay(TokenBarTheme.border)
                            }
                        }
                    }
                }

                HStack(spacing: 8) {
                    Image(systemName: "lock.shield")
                        .foregroundStyle(TokenBarTheme.green)
                    Text("Thread lineage, Git counts, drafts, paths, IDs, and tokens stay on this Mac. Codex's database remains read-only.")
                        .font(.system(size: 11))
                        .foregroundStyle(TokenBarTheme.secondary)
                }
            }
            .padding(30)
            .frame(maxWidth: 1180, alignment: .leading)
        }
        .background(TokenBarTheme.canvas)
        .sheet(item: $draftingThread) { thread in
            ThreadDraftSheet(thread: thread, initialDraft: model.threadDraft(for: thread.id))
                .environmentObject(model)
        }
    }
}

private struct ThreadSummary: View {
    let value: String
    let label: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Text(value)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(tint)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(TokenBarTheme.secondary)
            Spacer()
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(TokenBarTheme.panel)
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(TokenBarTheme.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }
}

private struct ThreadLaneColumn: View {
    @EnvironmentObject private var model: TokenBarModel
    let lane: CodexThreadLane
    let threads: [CodexThread]
    let onDraft: (CodexThread) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(lane.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(TokenBarTheme.text)
                    Text(lane.subtitle.uppercased())
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(TokenBarTheme.secondary)
                }
                Spacer()
                Text("\(threads.count)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(TokenBarTheme.secondary)
            }
            .padding(.bottom, 12)

            if threads.isEmpty {
                Text(lane == .focus ? "No active goal in the local index." : "Nothing in this lane.")
                    .font(.system(size: 11))
                    .foregroundStyle(TokenBarTheme.secondary)
                    .padding(.vertical, 18)
            } else {
                ForEach(threads) { thread in
                    CodexThreadRow(thread: thread, onDraft: { onDraft(thread) })
                    if thread.id != threads.last?.id {
                        Divider().overlay(TokenBarTheme.border)
                    }
                }
            }
        }
    }
}

private struct CodexThreadRow: View {
    @EnvironmentObject private var model: TokenBarModel
    let thread: CodexThread
    let onDraft: () -> Void

    private var compactTokens: String {
        let value = Double(thread.tokensUsed)
        if value >= 1_000_000_000 { return String(format: "%.2fB", value / 1_000_000_000) }
        if value >= 1_000_000 { return String(format: "%.1fM", value / 1_000_000) }
        if value >= 1_000 { return String(format: "%.1fK", value / 1_000) }
        return "\(thread.tokensUsed)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                if thread.goalStatus == "active" {
                    ThreadSignalChip(text: "GOAL", tint: TokenBarTheme.green)
                }
                if let parent = thread.parentShortID {
                    ThreadSignalChip(text: "FORK \(parent)", tint: TokenBarTheme.cyan)
                } else if thread.childThreadCount > 0 {
                    ThreadSignalChip(text: "\(thread.childThreadCount) FORKS", tint: TokenBarTheme.cyan)
                }
                if thread.isAutomation {
                    ThreadSignalChip(text: "AUTO", tint: TokenBarTheme.secondary)
                }
                if thread.gitReviewState == "changed" {
                    ThreadSignalChip(text: "\(thread.changedFileCount) FILES", tint: TokenBarTheme.amber)
                } else if thread.gitReviewState == "clean" {
                    ThreadSignalChip(text: "CLEAN", tint: TokenBarTheme.green)
                }
                Spacer(minLength: 0)
            }

            Text(thread.displayTitle)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(TokenBarTheme.text)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                Label(thread.workspace, systemImage: "folder")
                    .lineLimit(1)
                if let branch = thread.gitBranch, !branch.isEmpty {
                    Text("·")
                    Label(branch, systemImage: "arrow.triangle.branch")
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                Text(compactTokens)
                    .foregroundStyle(TokenBarTheme.cyan)
            }
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(TokenBarTheme.secondary)

            HStack(spacing: 5) {
                Text(thread.shortID)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(TokenBarTheme.secondary)
                Spacer()
                if !model.threadDraft(for: thread.id).isEmpty {
                    Circle().fill(TokenBarTheme.amber).frame(width: 5, height: 5).help("Saved follow-up draft")
                }
                ThreadIconButton(icon: "text.badge.plus", help: "Draft a persistent /side follow-up") {
                    onDraft()
                }
                ThreadIconButton(icon: "number", help: "Copy session ID") {
                    model.copy(thread.id, confirmation: "Session ID copied")
                }
                ThreadIconButton(icon: "folder.badge.plus", help: "Copy workspace path") {
                    model.copy(thread.cwd, confirmation: "Workspace path copied")
                }
                ThreadIconButton(icon: "link", help: "Copy Codex deep link") {
                    model.copy(thread.deepLink?.absoluteString ?? thread.id, confirmation: "Codex deep link copied")
                }
                ThreadIconButton(icon: "arrow.up.right.square", help: "Open in Codex") {
                    model.open(thread.deepLink)
                }
            }
        }
        .padding(.vertical, 11)
    }
}

private struct ThreadSignalChip: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.system(size: 7, weight: .bold, design: .rounded))
            .foregroundStyle(tint)
            .padding(.horizontal, 5)
            .frame(height: 16)
            .background(tint.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}

private struct ThreadDraftSheet: View {
    @EnvironmentObject private var model: TokenBarModel
    @Environment(\.dismiss) private var dismiss
    let thread: CodexThread
    @State private var draft: String

    init(thread: CodexThread, initialDraft: String) {
        self.thread = thread
        _draft = State(initialValue: initialDraft)
    }

    private var sideChatText: String {
        let focus = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        return focus.isEmpty ? thread.sideChatPrompt : "\(thread.sideChatPrompt)\n\nFocus for this follow-up:\n\(focus)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Side-chat follow-up")
                        .font(.system(size: 20, weight: .semibold))
                    Text(thread.displayTitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(TokenBarTheme.secondary)
                        .lineLimit(2)
                }
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark") }
                    .buttonStyle(.plain)
            }

            TextEditor(text: $draft)
                .font(.system(size: 13))
                .scrollContentBackground(.hidden)
                .padding(10)
                .background(TokenBarTheme.raised)
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(TokenBarTheme.border, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 7))

            HStack(spacing: 8) {
                Label("Saved only on this Mac", systemImage: "lock")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(TokenBarTheme.secondary)
                Spacer()
                Button("Save draft") {
                    model.saveThreadDraft(draft, for: thread.id)
                    dismiss()
                }
                .buttonStyle(.bordered)
                Button("Copy /side and open Codex") {
                    model.saveThreadDraft(draft, for: thread.id)
                    model.copy(sideChatText, confirmation: "Side-chat follow-up copied")
                    model.open(thread.deepLink)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(22)
        .frame(width: 560, height: 390)
        .background(TokenBarTheme.panel)
    }
}

private struct ThreadIconButton: View {
    let icon: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .medium))
                .frame(width: 20, height: 20)
        }
        .buttonStyle(.plain)
        .foregroundStyle(TokenBarTheme.secondary)
        .background(TokenBarTheme.raised)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .help(help)
    }
}

private struct UsageView: View {
    @EnvironmentObject private var model: TokenBarModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageChrome(
                    eyebrow: "Usage",
                    title: "The pace behind the work",
                    subtitle: "Volume is context, not identity. TokenBar uses it as one bounded signal."
                ) {
                    HStack(spacing: 8) {
                        Button("Reload identity") { model.reload() }
                            .buttonStyle(.bordered)
                        Button(model.isLoadingCosts ? "Reading ccusage…" : "Load local costs") {
                            model.refreshUsageCosts()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(model.isLoadingCosts)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        SectionLabel(text: "ccusage cost snapshot")
                        Spacer()
                        Text(model.costUsage.period)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(TokenBarTheme.secondary)
                    }
                    HStack(spacing: 14) {
                        UsageMetric(label: "Latest day", value: model.costUsage.latestCost, note: "Estimated API-equivalent cost", tint: TokenBarTheme.green)
                        UsageMetric(label: "Codex", value: model.costUsage.codexCost, note: "Codex share of latest day", tint: TokenBarTheme.cyan)
                        UsageMetric(label: "Tokens", value: model.costUsage.latestTokens, note: "Latest local usage day", tint: TokenBarTheme.amber)
                        UsageMetric(label: "All logs", value: model.costUsage.observedCost, note: "Observed local history", tint: TokenBarTheme.coral)
                    }
                    Label("Read locally with ccusage offline. Nothing is uploaded or shared.", systemImage: "lock.shield")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(TokenBarTheme.secondary)
                }

                HStack(spacing: 14) {
                    UsageMetric(label: "Today", value: model.profile.usage.today, note: "Local token movement", tint: TokenBarTheme.green)
                    UsageMetric(label: "Last 7 days", value: model.profile.usage.last7, note: "Current work rhythm", tint: TokenBarTheme.cyan)
                    UsageMetric(label: "Last 30 days", value: model.profile.usage.last30, note: "Longer operating range", tint: TokenBarTheme.amber)
                    UsageMetric(label: "Next 7 days", value: model.profile.usage.projectedNext7, note: "Projection, not fact", tint: TokenBarTheme.coral)
                }

                TokenBarPanel {
                    HStack(spacing: 0) {
                        UsageContext(value: "\(model.profile.usage.sessions)", label: "sessions indexed")
                        Divider().frame(height: 54)
                        UsageContext(value: "\(model.profile.usage.activeDays)/30", label: "active days")
                        Divider().frame(height: 54)
                        UsageContext(value: model.profile.usage.model, label: "top local model")
                        Divider().frame(height: 54)
                        UsageContext(value: "\(model.profile.proofScore)", label: "proof score")
                    }
                }

                TokenBarPanel {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionLabel(text: "TokenBar commentary")
                        Text(commentary)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(TokenBarTheme.text)
                            .lineSpacing(5)
                        Text("The useful question is not how many tokens moved. It is how often those sessions left behind a result another person can inspect.")
                            .font(.system(size: 13))
                            .foregroundStyle(TokenBarTheme.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(30)
            .frame(maxWidth: 1120, alignment: .leading)
        }
    }

    private var commentary: String {
        guard model.profile.usage.last7 != "--" else { return "Analyze a week and TokenBar will turn raw pace into a readable work rhythm." }
        return "\(model.profile.usage.last7) in seven days. Ambitious. Slightly unreasonable. The proof score of \(model.profile.proofScore) decides whether that motion became evidence."
    }
}

private struct UsageMetric: View {
    let label: String
    let value: String
    let note: String
    let tint: Color

    var body: some View {
        TokenBarPanel {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: label)
                Text(value)
                    .font(.system(size: 29, weight: .semibold, design: .rounded))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(note)
                    .font(.system(size: 11))
                    .foregroundStyle(TokenBarTheme.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct UsageContext: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(TokenBarTheme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(TokenBarTheme.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ProofView: View {
    @EnvironmentObject private var model: TokenBarModel
    @State private var confirmingRevocation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageChrome(
                    eyebrow: "Selective proof",
                    title: "Share the result, not the surveillance",
                    subtitle: "Your report stays local. Publishing a safe profile remains a separate, explicit action."
                ) {
                    if let report = model.profile.reportURL {
                        Button("Open full local report") { model.open(report) }
                            .buttonStyle(.bordered)
                    }
                }

                TokenBarPanel {
                    HStack(alignment: .top, spacing: 24) {
                        VStack(alignment: .leading, spacing: 12) {
                            TokenBarPill(label: "Share state", value: model.receipt.hasShareSurface ? model.receipt.shareMode : "private", tint: model.receipt.hasShareSurface ? TokenBarTheme.green : TokenBarTheme.amber)
                            Text(model.profile.identityTitle)
                                .font(.system(size: 26, weight: .semibold))
                                .foregroundStyle(TokenBarTheme.text)
                            Text(model.receipt.token)
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .foregroundStyle(TokenBarTheme.secondary)
                            if model.receipt.isLocalPreview {
                                Label("This proof link is a local preview, not a public deployment.", systemImage: "desktopcomputer")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(TokenBarTheme.amber)
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 6) {
                            Text("\(model.profile.proofScore)")
                                .font(.system(size: 48, weight: .semibold, design: .rounded))
                                .foregroundStyle(TokenBarTheme.green)
                            Text("PROOF SCORE")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(TokenBarTheme.secondary)
                        }
                    }
                }

                HStack(alignment: .top, spacing: 14) {
                    TokenBarPanel {
                        VStack(alignment: .leading, spacing: 14) {
                            SectionLabel(text: "Safe share actions")
                            ProofAction(icon: "doc.on.doc", title: "Copy proof link", note: "Copies the current opt-in proof surface", isEnabled: model.receipt.hasShareSurface) {
                                if let url = model.receipt.publicProfileURL ?? model.receipt.proofCardURL {
                                    model.copy(url.absoluteString, confirmation: "Proof link copied")
                                }
                            }
                            ProofAction(icon: "safari", title: "Open proof profile", note: "Inspect exactly what another person would see", isEnabled: model.receipt.hasShareSurface) {
                                model.open(model.receipt.publicProfileURL ?? model.receipt.proofCardURL)
                            }
                            ProofAction(icon: "doc.richtext", title: "Open local dossier", note: "The richer private report never needs to leave this Mac", isEnabled: model.profile.reportURL != nil) {
                                model.open(model.profile.reportURL)
                            }
                            Divider().overlay(TokenBarTheme.border)
                            ProofAction(
                                icon: model.isRevoking ? "ellipsis" : "eye.slash",
                                title: model.isRevoking ? "Removing public proof…" : "Unpublish this proof",
                                note: "Remove its public card, profile, feed, and rankings entry; keep local reports",
                                tint: TokenBarTheme.coral,
                                isEnabled: model.receipt.hasShareSurface && !model.isRevoking
                            ) {
                                confirmingRevocation = true
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    TokenBarPanel {
                        VStack(alignment: .leading, spacing: 13) {
                            SectionLabel(text: "Privacy contract")
                            PrivacyLine(text: "Raw transcripts excluded")
                            PrivacyLine(text: "Source code excluded")
                            PrivacyLine(text: "Credentials excluded")
                            PrivacyLine(text: "Sharing requires your action")
                            Divider().overlay(TokenBarTheme.border)
                            Text("A TBAR token is a proof pointer. It is not an access key to your machine or your original sessions.")
                                .font(.system(size: 11))
                                .foregroundStyle(TokenBarTheme.secondary)
                                .lineSpacing(3)
                        }
                        .frame(width: 280, alignment: .leading)
                    }
                }
            }
            .padding(30)
            .frame(maxWidth: 1120, alignment: .leading)
        }
        .confirmationDialog(
            "Unpublish this Builder Identity proof?",
            isPresented: $confirmingRevocation,
            titleVisibility: .visible
        ) {
            Button("Unpublish proof", role: .destructive) {
                model.revokeCurrentProof()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The public proof card, profile, For You entry, and rankings entry will be removed. Your local identity JSON, report, PDF, Skill.md, and usage history stay on this Mac.")
        }
    }
}

private struct ProofAction: View {
    let icon: String
    let title: String
    let note: String
    var tint: Color = TokenBarTheme.green
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .frame(width: 22)
                    .foregroundStyle(tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(TokenBarTheme.text)
                    Text(note).font(.system(size: 11)).foregroundStyle(TokenBarTheme.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(TokenBarTheme.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
    }
}

private struct PrivacyLine: View {
    let text: String
    var body: some View {
        Label(text, systemImage: "checkmark.circle.fill")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(TokenBarTheme.text)
            .symbolRenderingMode(.palette)
            .foregroundStyle(TokenBarTheme.green, TokenBarTheme.raised)
    }
}

private struct OpportunitiesView: View {
    @EnvironmentObject private var model: TokenBarModel
    @State private var showingImporter = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageChrome(
                    eyebrow: "Project invitations",
                    title: "Turn a proposal into a bounded Codex loop",
                    subtitle: "Import a brief someone shared. TokenBar adds your Builder Identity context and prepares the first accountable work loop."
                ) {
                    Button {
                        showingImporter = true
                    } label: {
                        Label("Import project brief", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(TokenBarTheme.green)
                }

                if model.invitations.isEmpty {
                    TokenBarPanel {
                        VStack(spacing: 14) {
                            Image(systemName: "paperplane")
                                .font(.system(size: 28, weight: .medium))
                                .foregroundStyle(TokenBarTheme.cyan)
                            Text("No proposed work yet")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(TokenBarTheme.text)
                            Text("Import a Markdown, JSON, or text brief. It remains local until you deliberately share an outcome.")
                                .font(.system(size: 13))
                                .foregroundStyle(TokenBarTheme.secondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 440)
                            HStack(spacing: 10) {
                                Button("Preview a sample") { model.previewSampleInvitation() }
                                    .buttonStyle(.borderedProminent)
                                    .tint(TokenBarTheme.cyan)
                                Button("Choose a brief") { showingImporter = true }
                                    .buttonStyle(.bordered)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 250)
                    }
                } else {
                    ForEach(model.invitations) { invitation in
                        InvitationRow(invitation: invitation)
                    }
                }

                TokenBarPanel {
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: "lock.shield")
                            .foregroundStyle(TokenBarTheme.green)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Local opportunity queue")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(TokenBarTheme.text)
                            Text("TokenBar stores the imported brief and its review state on this Mac. Accepting copies a structured kickoff prompt and opens Codex when installed; it does not post, clone, or execute work without you.")
                                .font(.system(size: 11))
                                .foregroundStyle(TokenBarTheme.secondary)
                                .lineSpacing(3)
                        }
                    }
                }
            }
            .padding(30)
            .frame(maxWidth: 1120, alignment: .leading)
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.plainText, .json, UTType(filenameExtension: "md") ?? .plainText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first { model.importBrief(from: url) }
            case .failure(let error):
                model.lastError = error.localizedDescription
            }
        }
    }
}

private struct InvitationRow: View {
    @EnvironmentObject private var model: TokenBarModel
    let invitation: ProjectInvitation

    private var fit: (label: String, score: Int, note: String) {
        model.opportunityFit(for: invitation)
    }

    var body: some View {
        TokenBarPanel {
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 9) {
                    HStack(spacing: 8) {
                        TokenBarPill(label: "Status", value: invitation.status, tint: invitation.status == "in progress" ? TokenBarTheme.green : TokenBarTheme.amber)
                        TokenBarPill(label: "Fit", value: "\(fit.score) · \(fit.label)", tint: TokenBarTheme.cyan)
                        Text(invitation.proposer)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(TokenBarTheme.secondary)
                    }
                    Text(invitation.title)
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(TokenBarTheme.text)
                    Text(invitation.summary)
                        .font(.system(size: 12))
                        .foregroundStyle(TokenBarTheme.secondary)
                        .lineSpacing(3)
                        .lineLimit(4)
                    HStack(alignment: .top, spacing: 9) {
                        Image(systemName: "scope")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(TokenBarTheme.cyan)
                        Text(fit.note)
                            .font(.system(size: 11))
                            .foregroundStyle(TokenBarTheme.secondary)
                            .lineSpacing(3)
                            .lineLimit(3)
                    }
                    .padding(.top, 3)
                }
                Spacer(minLength: 20)
                VStack(spacing: 9) {
                    Button("Accept + open Codex") { model.accept(invitation) }
                        .buttonStyle(.borderedProminent)
                        .tint(TokenBarTheme.green)
                    Button("Copy kickoff") {
                        model.copy(model.kickoffPrompt(for: invitation), confirmation: "Codex kickoff copied")
                    }
                    .buttonStyle(.bordered)
                    Button(invitation.status == "sample" ? "Close sample" : "Remove from queue") {
                        model.remove(invitation)
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(TokenBarTheme.secondary)
                }
                .frame(width: 160)
            }
        }
    }
}
