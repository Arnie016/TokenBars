import AppKit
import Pow
import SwiftUI
import UniformTypeIdentifiers

enum TokenBarDestination: String, CaseIterable, Identifiable {
    case story = "Builder Story"
    case threads = "Threads"
    case profile = "Profile"
    case storage = "Storage"
    case proof = "Report"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .story: "sparkles.rectangle.stack"
        case .threads: "rectangle.3.group"
        case .profile: "person.crop.circle"
        case .storage: "externaldrive.badge.timemachine"
        case .proof: "checkmark.seal"
        }
    }
}

struct TokenBarRootView: View {
    @EnvironmentObject private var model: TokenBarModel
    @State private var selection: TokenBarDestination? = .story
    @State private var showingSettings = false
    @State private var showingLaunchDeck = true

    var body: some View {
        ZStack {
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

                Button {
                    showingSettings = true
                } label: {
                    Label("Settings", systemImage: "gearshape")
                        .font(.system(size: 12, weight: .medium))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .foregroundStyle(TokenBarTheme.secondary)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

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
                    case .threads: ThreadsHubView()
                    case .profile: ProfileView()
                    case .storage: StorageView()
                    case .proof: ProofView()
                    }
                }
                .background(TokenBarTheme.canvas)
            }
            .tint(TokenBarTheme.green)
            .background(TokenBarTheme.canvas)
            .allowsHitTesting(!showingLaunchDeck)

            if showingLaunchDeck {
                TokenBarLaunchDeck {
                    withAnimation(.easeOut(duration: 0.22)) {
                        showingLaunchDeck = false
                    }
                }
                .transition(.opacity)
                .zIndex(10)
            }
        }
        .alert("TokenBar needs attention", isPresented: Binding(
            get: { model.lastError != nil },
            set: { if !$0 { model.lastError = nil } }
        )) {
            Button("OK", role: .cancel) { model.lastError = nil }
        } message: {
            Text(model.lastError ?? "Unknown error")
        }
        .sheet(isPresented: $showingSettings) {
            TokenBarSettingsView()
                .environmentObject(model)
        }
    }
}

private struct TokenBarLaunchDeck: View {
    @EnvironmentObject private var model: TokenBarModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let enter: () -> Void
    @State private var launching = false
    @State private var appeared = false
    @State private var entrancePulse = 0

    private var strongestDimension: BuilderDimension? {
        model.profile.dimensions.max { $0.score < $1.score }
    }

    var body: some View {
        ZStack {
            TokenBarTheme.canvas.ignoresSafeArea()
            TokenBarFluidField(
                primary: TokenBarTheme.cyan,
                secondary: TokenBarTheme.amber,
                speed: 0.16,
                intensity: 0.58,
                mood: .goodNight
            )
                .ignoresSafeArea()

            VStack(spacing: 26) {
                Spacer()

                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 128, height: 128)
                    .shadow(color: Color.black.opacity(0.44), radius: 24, y: 14)
                    .shadow(color: TokenBarTheme.cyan.opacity(0.24), radius: 28)
                .scaleEffect(launching ? 1.25 : (appeared ? 1 : 0.86))
                .offset(y: launching && !reduceMotion ? -520 : 0)
                .opacity(launching ? 0 : 1)

                VStack(spacing: 10) {
                    SectionLabel(text: "\(model.profile.archetype) · \(model.profile.stance)")
                    Text(model.profile.identityTitle)
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(TokenBarTheme.text)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.72)
                    Text(model.profile.subtitle)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(TokenBarTheme.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .frame(maxWidth: 620)
                }
                .opacity(launching ? 0 : 1)

                HStack(spacing: 16) {
                    LaunchEvidence(
                        label: "Strongest signal",
                        value: strongestDimension.map { "\($0.name) \($0.score)" } ?? "Analysis ready",
                        tint: TokenBarTheme.amber
                    )
                    LaunchEvidence(
                        label: "Evidence",
                        value: "\(model.profile.evidenceSessions) local sessions",
                        tint: TokenBarTheme.cyan
                    )
                    LaunchEvidence(
                        label: "Privacy",
                        value: "On this Mac",
                        tint: TokenBarTheme.green
                    )
                }
                .opacity(launching ? 0 : 1)

                LaunchPrivacyPromise()
                    .opacity(launching ? 0 : 1)

                Button {
                    TokenBarSound.play(.enter)
                    entrancePulse += 1
                    withAnimation(reduceMotion ? .linear(duration: 0.12) : .easeIn(duration: 0.72)) {
                        launching = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.14 : 0.7)) {
                        enter()
                    }
                } label: {
                    HStack(spacing: 10) {
                        Text("Enter TokenBar")
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 190, height: 42)
                }
                .buttonStyle(.borderedProminent)
                .tint(TokenBarTheme.green)
                .keyboardShortcut(.defaultAction)
                .disabled(launching)
                .opacity(launching ? 0 : 1)
                .changeEffect(
                    .shine(duration: 0.72),
                    value: entrancePulse,
                    isEnabled: !reduceMotion
                )

                Spacer()
            }
            .padding(42)
        }
        .onAppear {
            withAnimation(.easeOut(duration: reduceMotion ? 0.1 : 0.55)) { appeared = true }
        }
    }
}

private struct LaunchEvidence: View {
    let label: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(tint)
            Text(value)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(TokenBarTheme.text)
        }
        .frame(minWidth: 112, alignment: .leading)
    }
}

private struct LaunchPrivacyPromise: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(TokenBarTheme.green)

            VStack(alignment: .leading, spacing: 2) {
                Text("NOTHING LEAVES THIS MAC")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(TokenBarTheme.green)
                Text("Entering and analyzing do not upload anything. Sharing a generated profile is always a separate action you control.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(TokenBarTheme.text)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 14)
        .frame(width: 510, height: 58, alignment: .leading)
        .background(TokenBarTheme.nightInk.opacity(0.86))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(TokenBarTheme.green.opacity(0.32), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
    }
}

private struct TokenBarSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var model: TokenBarModel
    @AppStorage("tokenbar.sound.enabled") private var soundEnabled = true
    @AppStorage("tokenbar.haptics.enabled") private var hapticsEnabled = true
    @AppStorage("tokenbar.cinematicSound.enabled") private var cinematicSoundEnabled = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("TokenBar Settings")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(TokenBarTheme.text)
                    Text("Local identity, storage, and account state.")
                        .font(.system(size: 12))
                        .foregroundStyle(TokenBarTheme.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }
            }

            TokenBarPanel {
                VStack(alignment: .leading, spacing: 14) {
                    SettingsRow(
                        icon: "person.crop.circle",
                        title: "Account",
                        value: "Local only",
                        note: "Clerk is not configured. Add publishable and secret keys before enabling sign-in."
                    )
                    Divider().overlay(TokenBarTheme.border)
                    SettingsRow(
                        icon: "lock.shield",
                        title: "Privacy",
                        value: "Raw work stays on this Mac",
                        note: "Public reports use generated aggregates, never transcripts, source code, or credentials."
                    )
                    Divider().overlay(TokenBarTheme.border)
                    SettingsRow(
                        icon: "folder",
                        title: "Reports",
                        value: "~/Library/Application Support/CodexLimitBar/profiles",
                        note: "Builder Identity reports and portable Skill.md files."
                    )
                    Divider().overlay(TokenBarTheme.border)
                    SettingsRow(
                        icon: "rectangle.3.group",
                        title: "Thread boards",
                        value: "~/Library/Application Support/CodexLimitBar/thread-boards.json",
                        note: "\(model.threadBoards.count) saved board\(model.threadBoards.count == 1 ? "" : "s") on this Mac."
                    )
                }
            }

            TokenBarPanel {
                HStack(spacing: 12) {
                    Image(systemName: "speaker.wave.2")
                        .foregroundStyle(TokenBarTheme.cyan)
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Interface sound")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(TokenBarTheme.text)
                        Text("Synthesized locally for entry, inspection, analysis, and completion. Never on hover.")
                            .font(.system(size: 10))
                            .foregroundStyle(TokenBarTheme.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $soundEnabled)
                        .labelsHidden()
                }

                Divider().overlay(TokenBarTheme.border)

                HStack(spacing: 12) {
                    Image(systemName: "hand.tap")
                        .foregroundStyle(TokenBarTheme.amber)
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Trackpad feedback")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(TokenBarTheme.text)
                        Text("A restrained tactile cue for deliberate actions and completed local analysis.")
                            .font(.system(size: 10))
                            .foregroundStyle(TokenBarTheme.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $hapticsEnabled)
                        .labelsHidden()
                }

                Divider().overlay(TokenBarTheme.border)

                HStack(spacing: 12) {
                    Image(systemName: "music.note.list")
                        .foregroundStyle(TokenBarTheme.coral)
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Cinematic accents")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(TokenBarTheme.text)
                        Text("Optional supplied stingers at analysis start and story reveal. Off by default.")
                            .font(.system(size: 10))
                            .foregroundStyle(TokenBarTheme.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $cinematicSoundEnabled)
                        .labelsHidden()
                }

                Divider().overlay(TokenBarTheme.border)

                HStack(spacing: 8) {
                    SectionLabel(text: "Audition")
                    Spacer()
                    SoundPreviewButton(label: "Press", cue: .press)
                    SoundPreviewButton(label: "Page", cue: .page)
                    SoundPreviewButton(label: "Ready", cue: .analysisComplete)
                    SoundPreviewButton(label: "Error", cue: .error)
                }
            }

            TokenBarPanel {
                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel(text: "Useful commands")
                    SettingsCommand(command: "tokenbar usage", note: "Read the local usage story")
                    SettingsCommand(command: "tokenbar report", note: "Refresh Builder Identity")
                    SettingsCommand(command: "tokenbar mcp", note: "Expose the safe profile to Codex")
                }
            }
        }
        .padding(24)
        .frame(width: 650)
        .background(TokenBarTheme.canvas)
    }
}

private struct SoundPreviewButton: View {
    let label: String
    let cue: TokenBarSound.Cue

    var body: some View {
        Button {
            TokenBarSound.play(cue)
            TokenBarHaptics.perform(.selection)
        } label: {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .padding(.horizontal, 9)
                .frame(height: 27)
                .background(TokenBarTheme.raised)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .help("Play the \(label.lowercased()) interaction cue")
    }
}

private struct SettingsRow: View {
    let icon: String
    let title: String
    let value: String
    let note: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(TokenBarTheme.cyan)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(TokenBarTheme.text)
                    Spacer()
                    Text(value)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(TokenBarTheme.secondary)
                        .lineLimit(1)
                }
                Text(note)
                    .font(.system(size: 10))
                    .foregroundStyle(TokenBarTheme.secondary)
            }
        }
    }
}

private struct SettingsCommand: View {
    @EnvironmentObject private var model: TokenBarModel
    let command: String
    let note: String

    var body: some View {
        Button {
            model.copy(command, confirmation: "\(command) copied")
        } label: {
            HStack {
                Text(command)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(TokenBarTheme.text)
                Spacer()
                Text(note)
                    .font(.system(size: 10))
                    .foregroundStyle(TokenBarTheme.secondary)
                Image(systemName: "doc.on.doc")
                    .foregroundStyle(TokenBarTheme.green)
            }
            .padding(.horizontal, 11)
            .frame(height: 34)
            .background(TokenBarTheme.raised)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}

private struct TokenBarBrand: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 31, height: 31)
                .shadow(color: TokenBarTheme.cyan.opacity(0.16), radius: 8, y: 3)
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
    @State private var storyPage = 0
    @State private var selectedDimension: BuilderDimension?
    @State private var analysisDays = 7
    @State private var analysisStartedAt = Date()
    @State private var showAnalysisReady = false

    private var accent: Color { TokenBarTheme.accent(for: model.profile.identityTitle) }
    private var analysisLabel: String {
        switch analysisDays {
        case 1: "day"
        case 30: "month"
        default: "week"
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageChrome(
                    eyebrow: "Builder Story",
                    title: "Watch how you built",
                    subtitle: "Five chapters assembled from private, aggregate Codex evidence."
                ) {
                    HStack(spacing: 8) {
                        Button {
                            model.copyCodexMCPSetup()
                        } label: {
                            Label("Connect Codex", systemImage: "link.badge.plus")
                        }
                        .buttonStyle(.bordered)
                        .help("Copy the command that adds TokenBar's read-only Builder Identity MCP to Codex")

                        Button {
                            model.refreshIdentityBridge()
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                        .buttonStyle(.bordered)
                        .disabled(model.isLoadingIdentityBridge)
                        .help(model.isLoadingIdentityBridge ? "Refreshing safe Builder Identity bundle" : "Refresh safe Builder Identity bundle")
                        .accessibilityLabel("Refresh safe Builder Identity bundle")

                        Picker("Analysis window", selection: $analysisDays) {
                            Text("Day").tag(1)
                            Text("Week").tag(7)
                            Text("Month").tag(30)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 166)
                        .disabled(model.isAnalyzing)

                        Button {
                            analysisStartedAt = Date()
                            showAnalysisReady = false
                            TokenBarSound.play(.analysisStart)
                            TokenBarHaptics.perform(.analysisStart)
                            model.refreshIdentity(days: analysisDays)
                        } label: {
                            Label(
                                model.isAnalyzing ? "Analyzing…" : "Analyze",
                                systemImage: model.isAnalyzing ? "ellipsis" : "sparkles"
                            )
                            .lineLimit(1)
                            .fixedSize()
                        }
                        .buttonStyle(TokenBarPrimaryActionStyle(tint: accent))
                        .disabled(model.isAnalyzing)
                        .opacity(model.isAnalyzing ? 0.72 : 1)
                        .help("Analyze this \(analysisLabel) locally")
                        .accessibilityLabel("Analyze this \(analysisLabel) locally")
                    }
                }

                LocalAnalysisNotice(days: analysisDays, isAnalyzing: model.isAnalyzing, accent: accent)

                BuilderStoryDeck(page: $storyPage) { dimension in
                    selectedDimension = dimension
                }
                .environmentObject(model)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)

                if !model.profile.dimensions.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel(text: "Full scouting report")
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 130), spacing: 10)],
                            spacing: 10
                        ) {
                            ForEach(model.profile.dimensions) { dimension in
                                Button {
                                    selectedDimension = dimension
                                } label: {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Text(dimension.name)
                                                .lineLimit(1)
                                            Spacer()
                                            Text("\(dimension.score)")
                                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                        }
                                        Capsule()
                                            .fill(TokenBarTheme.raised)
                                            .frame(height: 4)
                                            .overlay(alignment: .leading) {
                                                Capsule()
                                                    .fill(dimension.id == model.profile.dimensions.first?.id ? accent : TokenBarTheme.cyan)
                                                    .frame(maxWidth: .infinity)
                                                    .scaleEffect(x: CGFloat(dimension.score) / 100, anchor: .leading)
                                            }
                                    }
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(TokenBarTheme.text)
                                    .padding(12)
                                    .background(TokenBarTheme.panel)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(TokenBarTheme.border, lineWidth: 1)
                                    }
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                                .buttonStyle(.plain)
                                .help("Open the evidence behind \(dimension.name)")
                            }
                        }
                    }
                }
            }
            .padding(30)
            .frame(maxWidth: 1120, alignment: .leading)
        }
        .background(TokenBarTheme.canvas)
        .overlay {
            if model.isAnalyzing || showAnalysisReady {
                BuilderAnalysisTheatre(
                    days: analysisDays,
                    startedAt: analysisStartedAt,
                    accent: accent,
                    isReady: showAnalysisReady
                )
                .transition(.opacity.combined(with: .scale(scale: 0.985)))
                .zIndex(20)
            }
        }
        .animation(.easeInOut(duration: 0.28), value: model.isAnalyzing)
        .animation(.easeInOut(duration: 0.28), value: showAnalysisReady)
        .onAppear {
            withAnimation(.easeOut(duration: 0.55)) { appeared = true }
        }
        .onChange(of: model.isAnalyzing) { wasAnalyzing, isAnalyzing in
            if wasAnalyzing && !isAnalyzing && model.lastError == nil {
                showAnalysisReady = true
                TokenBarSound.play(.analysisComplete)
                TokenBarHaptics.perform(.success)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                    withAnimation(.easeOut(duration: 0.28)) {
                        showAnalysisReady = false
                    }
                }
            } else if wasAnalyzing && !isAnalyzing {
                showAnalysisReady = false
                TokenBarSound.play(.error)
            }
        }
        .sheet(item: $selectedDimension) { dimension in
            BuilderDimensionDetailView(dimension: dimension, accent: accent)
                .environmentObject(model)
        }
    }
}

private struct BuilderAnalysisTheatre: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let days: Int
    let startedAt: Date
    let accent: Color
    let isReady: Bool

    private let stages = [
        ("books.vertical.fill", "Reading the local session index"),
        ("point.3.filled.connected.trianglepath.dotted", "Finding moves you repeat"),
        ("chart.xyaxis.line", "Comparing rhythm across projects"),
        ("text.document.fill", "Writing the next Builder Story"),
    ]

    private var windowLabel: String {
        switch days {
        case 1: "Today"
        case 7: "This week"
        case 30: "This month"
        default: "\(days) days"
        }
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion || isReady)) { context in
            let elapsed = max(0, context.date.timeIntervalSince(startedAt))
            let activeStage = Int(elapsed / 1.8) % stages.count

            ZStack {
                TokenBarTheme.nightInk.opacity(0.98)
                TokenBarFluidField(
                    primary: accent,
                    secondary: TokenBarTheme.nightMist,
                    speed: 0.12,
                    intensity: 0.28,
                    mood: .goodNight
                )

                HStack(spacing: 54) {
                    AnalysisSignalOrb(
                        date: context.date,
                        accent: accent,
                        isReady: isReady,
                        reduceMotion: reduceMotion
                    )
                    .frame(width: 310, height: 310)

                    VStack(alignment: .leading, spacing: 22) {
                        SectionLabel(text: isReady ? "Local analysis complete" : "Local analysis in progress")

                        VStack(alignment: .leading, spacing: 7) {
                            Text(isReady ? "Your story is ready." : "Reading how you build.")
                                .font(.system(size: 38, weight: .bold, design: .rounded))
                                .foregroundStyle(TokenBarTheme.text)
                            Text(
                                isReady
                                    ? "The new edition is saved on this Mac."
                                    : "No upload. No raw transcript leaves this computer."
                            )
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .italic()
                            .foregroundStyle(isReady ? TokenBarTheme.green : accent)
                        }

                        if !isReady {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(Array(stages.enumerated()), id: \.offset) { index, stage in
                                    HStack(spacing: 11) {
                                        ZStack {
                                            Circle()
                                                .fill(index == activeStage ? accent : TokenBarTheme.raised)
                                                .frame(width: 26, height: 26)
                                            Image(systemName: stage.0)
                                                .font(.system(size: 10, weight: .semibold))
                                                .foregroundStyle(index == activeStage ? TokenBarTheme.nightInk : TokenBarTheme.secondary)
                                        }
                                        Text(stage.1)
                                            .font(.system(size: 12, weight: index == activeStage ? .semibold : .medium))
                                            .foregroundStyle(index == activeStage ? TokenBarTheme.text : TokenBarTheme.secondary)
                                    }
                                    .opacity(index == activeStage ? 1 : 0.62)
                                }
                            }
                            .animation(.spring(response: 0.34, dampingFraction: 0.82), value: activeStage)
                        } else {
                            HStack(spacing: 9) {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(TokenBarTheme.green)
                                Text("Opening the refreshed edition")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(TokenBarTheme.text)
                            }
                        }

                        HStack(spacing: 8) {
                            AnalysisFact(label: "Window", value: windowLabel, tint: accent)
                            AnalysisFact(label: "Runs on", value: "This Mac", tint: TokenBarTheme.green)
                            AnalysisFact(label: "Uploaded", value: "Nothing", tint: TokenBarTheme.cyan)
                        }

                        Text("The activity labels describe the local pipeline; they may repeat while the command finishes.")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(TokenBarTheme.secondary)
                    }
                    .frame(maxWidth: 580, alignment: .leading)
                }
                .padding(52)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                isReady
                    ? "Local Builder Story analysis complete. Nothing was uploaded."
                    : "Local Builder Story analysis in progress. Nothing is uploaded."
            )
        }
    }
}

private struct AnalysisSignalOrb: View {
    let date: Date
    let accent: Color
    let isReady: Bool
    let reduceMotion: Bool

    var body: some View {
        ZStack {
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let phase = reduceMotion ? 0 : date.timeIntervalSinceReferenceDate

                for ring in 0..<4 {
                    let radius = CGFloat(52 + (ring * 26))
                    let rect = CGRect(
                        x: center.x - radius,
                        y: center.y - radius,
                        width: radius * 2,
                        height: radius * 2
                    )
                    context.stroke(
                        Path(ellipseIn: rect),
                        with: .color((ring == 1 ? accent : TokenBarTheme.nightMist).opacity(0.13 + Double(ring) * 0.035)),
                        style: StrokeStyle(lineWidth: ring == 1 ? 1.4 : 0.8, dash: ring.isMultiple(of: 2) ? [3, 7] : [])
                    )

                    let angle = phase * (0.42 + Double(ring) * 0.09) + Double(ring)
                    let dot = CGPoint(
                        x: center.x + cos(angle) * radius,
                        y: center.y + sin(angle) * radius
                    )
                    context.fill(
                        Path(ellipseIn: CGRect(x: dot.x - 3, y: dot.y - 3, width: 6, height: 6)),
                        with: .color(ring == 0 ? accent : TokenBarTheme.nightMist.opacity(0.72))
                    )
                }

                var pulse = Path()
                let amplitude: CGFloat = 14
                let width = size.width * 0.68
                let startX = center.x - width / 2
                for index in 0...80 {
                    let progress = CGFloat(index) / 80
                    let x = startX + width * progress
                    let envelope = sin(progress * .pi)
                    let y = center.y + sin((progress * 8 * .pi) + phase * 2.2) * amplitude * envelope
                    index == 0 ? pulse.move(to: CGPoint(x: x, y: y)) : pulse.addLine(to: CGPoint(x: x, y: y))
                }
                context.stroke(pulse, with: .color(accent.opacity(0.68)), lineWidth: 1.3)
            }

            Circle()
                .fill(TokenBarTheme.nightInk.opacity(0.94))
                .frame(width: 112, height: 112)
                .overlay {
                    Circle().stroke(accent.opacity(0.38), lineWidth: 1)
                }
                .shadow(color: accent.opacity(0.30), radius: isReady ? 34 : 18)

            if isReady {
                Image(systemName: "checkmark")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(TokenBarTheme.green)
                    .transition(.scale.combined(with: .opacity))
            } else {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 72, height: 72)
                    .scaleEffect(reduceMotion ? 1 : 0.97 + (sin(date.timeIntervalSinceReferenceDate * 2) * 0.03))
            }
        }
    }
}

private struct AnalysisFact: View {
    let label: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(tint)
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(TokenBarTheme.text)
        }
        .padding(.horizontal, 11)
        .frame(height: 46)
        .background(TokenBarTheme.raised.opacity(0.78))
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }
}

private struct LocalAnalysisNotice: View {
    let days: Int
    let isAnalyzing: Bool
    let accent: Color

    private let stages = [
        "Indexing private sessions",
        "Finding repeated moves",
        "Scoring the signal map",
        "Writing your Builder Story",
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.7, paused: !isAnalyzing)) { context in
            let stageIndex = Int(context.date.timeIntervalSinceReferenceDate / 1.4) % stages.count

            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(TokenBarTheme.border, lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: isAnalyzing ? 0.72 : 1)
                        .stroke(
                            isAnalyzing ? accent : TokenBarTheme.green,
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .rotationEffect(.degrees(isAnalyzing ? context.date.timeIntervalSinceReferenceDate * 90 : 0))
                    Image(systemName: isAnalyzing ? "waveform.path.ecg" : "lock.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(isAnalyzing ? accent : TokenBarTheme.green)
                }
                .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 3) {
                    Text(isAnalyzing ? stages[stageIndex] : "Your analysis stays yours")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .italic(isAnalyzing)
                        .foregroundStyle(isAnalyzing ? accent : TokenBarTheme.text)
                        .contentTransition(.numericText())
                    Text(
                        isAnalyzing
                            ? "\(days)-day window · running entirely on this Mac"
                            : "TokenBar reads local aggregate evidence. Raw prompts, source code, and credentials are never shared unless you separately publish a generated profile."
                    )
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(TokenBarTheme.secondary)
                    .lineLimit(2)
                }

                Spacer()

                TokenBarPill(
                    label: isAnalyzing ? "Status" : "Privacy",
                    value: isAnalyzing ? "Local analysis" : "100% local",
                    tint: isAnalyzing ? accent : TokenBarTheme.green
                )
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 62)
            .background(
                isAnalyzing
                    ? AnyShapeStyle(
                        LinearGradient(
                            colors: [TokenBarTheme.nightInk, accent.opacity(0.12), TokenBarTheme.nightBlue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    : AnyShapeStyle(TokenBarTheme.panel)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isAnalyzing ? accent.opacity(0.45) : TokenBarTheme.border, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .accessibilityElement(children: .combine)
    }
}

private struct BuilderStoryDeck: View {
    @EnvironmentObject private var model: TokenBarModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var page: Int
    let openDimension: (BuilderDimension) -> Void

    private let pageCount = 5

    private var strongest: BuilderDimension? {
        model.profile.dimensions.max { $0.score < $1.score }
    }

    private var growth: BuilderDimension? {
        model.profile.dimensions.min { $0.score < $1.score }
    }

    private var sessions: Int {
        model.profile.evidenceSessions > 0 ? model.profile.evidenceSessions : model.profile.usage.sessions
    }

    private var activeDays: Int {
        model.profile.evidenceActiveDays > 0 ? model.profile.evidenceActiveDays : model.profile.usage.activeDays
    }

    private var accent: Color {
        TokenBarTheme.accent(for: model.profile.identityTitle)
    }

    private var tint: Color {
        [accent, TokenBarTheme.cyan, TokenBarTheme.green, TokenBarTheme.amber, TokenBarTheme.coral][page]
    }

    private var guideCopy: String {
        switch page {
        case 0:
            return "\(sessions) private sessions shaped this edition."
        case 1:
            return strongest.map { "\($0.name) is your sharpest edge right now." }
                ?? "Analyze a build window to reveal your sharpest edge."
        case 2:
            return "Repeated moves, not a personality quiz."
        case 3:
            return "The small details usually tell the better story."
        default:
            return growth.map { "\($0.name) is where your next leap can happen." }
                ?? "Your next leap appears after the next analysis."
        }
    }

    var body: some View {
        ZStack {
            TokenBarTheme.panel
            TokenBarFluidField(
                primary: tint,
                secondary: page.isMultiple(of: 2) ? TokenBarTheme.amber : TokenBarTheme.cyan,
                speed: 0.2,
                intensity: 0.76,
                mood: .goodNight
            )

            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    ForEach(0..<pageCount, id: \.self) { index in
                        Button {
                            move(to: index)
                        } label: {
                            Capsule()
                                .fill(index <= page ? TokenBarTheme.text.opacity(index == page ? 0.96 : 0.48) : Color.white.opacity(0.14))
                                .frame(height: 3)
                        }
                        .buttonStyle(.plain)
                        .help("Open chapter \(index + 1)")
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 18)

                ZStack {
                    storyContent
                        .id(page)
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            )
                        )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                HStack(spacing: 14) {
                    Image(nsImage: NSApplication.shared.applicationIconImage)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 32, height: 32)
                        .changeEffect(.jump(height: 6), value: page, isEnabled: !reduceMotion)
                    Text(guideCopy)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(TokenBarTheme.secondary)
                        .lineLimit(2)

                    Spacer()

                    Text("\(page + 1) / \(pageCount)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(TokenBarTheme.secondary)

                    Button { move(to: page - 1) } label: {
                        Image(systemName: "arrow.left")
                    }
                    .buttonStyle(.borderless)
                    .disabled(page == 0)
                    .help("Previous chapter")

                    Button { move(to: page + 1) } label: {
                        Image(systemName: page == pageCount - 1 ? "arrow.counterclockwise" : "arrow.right")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(tint)
                    .help(page == pageCount - 1 ? "Replay Builder Story" : "Next chapter")
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 18)
            }
        }
        .frame(height: 510)
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(TokenBarTheme.border, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .animation(reduceMotion ? .linear(duration: 0.12) : .easeInOut(duration: 0.38), value: page)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Builder Story chapter \(page + 1) of \(pageCount)")
    }

    @ViewBuilder
    private var storyContent: some View {
        switch page {
        case 0:
            HStack(spacing: 34) {
                VStack(alignment: .leading, spacing: 12) {
                    SectionLabel(text: "\(model.profile.archetype) · \(model.profile.stance)")
                    Text(model.profile.identityTitle)
                        .font(.system(size: 42, weight: .semibold, design: .serif))
                        .foregroundStyle(TokenBarTheme.text)
                        .lineLimit(3)
                        .minimumScaleFactor(0.7)
                    Text(model.profile.subtitle)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .italic()
                        .foregroundStyle(accent.opacity(0.92))
                        .lineSpacing(4)
                        .lineLimit(3)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(sessions)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(tint)
                        Text("sessions")
                            .foregroundStyle(TokenBarTheme.secondary)
                        Text("·")
                            .foregroundStyle(TokenBarTheme.secondary)
                        Text("\(activeDays)")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(TokenBarTheme.cyan)
                        Text("active days")
                            .foregroundStyle(TokenBarTheme.secondary)
                    }
                    .font(.system(size: 11, weight: .semibold))
                }
                .frame(maxWidth: 540, alignment: .leading)

                BuilderFootballCard(
                    title: model.profile.identityTitle,
                    dimensions: model.profile.dimensions,
                    accent: accent,
                    openDimension: openDimension
                )
                .frame(width: 340)
            }
            .padding(34)

        case 1:
            HStack(alignment: .center, spacing: 42) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(strongest.map { "\($0.score)" } ?? "--")
                        .font(.system(size: 112, weight: .bold, design: .rounded))
                        .foregroundStyle(tint)
                    Text("CURRENT FORM")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(tint.opacity(0.82))
                }
                VStack(alignment: .leading, spacing: 14) {
                    SectionLabel(text: "What carries your work")
                    Text(strongest?.name ?? "Signal forming")
                        .font(.system(size: 38, weight: .semibold, design: .serif))
                        .foregroundStyle(TokenBarTheme.text)
                    Text("This is your sharpest edge.")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .italic()
                        .foregroundStyle(tint)
                    Text(strongest?.note ?? "Analyze a week to reveal the pattern that most consistently carries your work.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(TokenBarTheme.secondary)
                        .lineSpacing(5)
                        .lineLimit(5)
                    if let strongest {
                        Button {
                            openDimension(strongest)
                        } label: {
                            Label("See why", systemImage: "arrow.up.right")
                        }
                        .buttonStyle(TokenBarPrimaryActionStyle(tint: tint))
                    }
                }
                .frame(maxWidth: 570, alignment: .leading)
            }
            .padding(44)

        case 2:
            VStack(alignment: .leading, spacing: 20) {
                SectionLabel(text: "What you repeatedly did")
                Text("Moves that keep showing up.")
                    .font(.system(size: 38, weight: .semibold, design: .serif))
                    .foregroundStyle(TokenBarTheme.text)
                if model.profile.signatureMoves.isEmpty {
                    Text("Analyze a week to turn repeated session behavior into inspectable patterns.")
                        .font(.system(size: 16))
                        .foregroundStyle(TokenBarTheme.secondary)
                } else {
                    ForEach(Array(model.profile.signatureMoves.prefix(3).enumerated()), id: \.offset) { index, move in
                        HStack(alignment: .firstTextBaseline, spacing: 18) {
                            Text(String(format: "%02d", index + 1))
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(tint)
                            Text(move)
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundStyle(TokenBarTheme.text)
                                .lineSpacing(4)
                        }
                    }
                }
            }
            .frame(maxWidth: 800, alignment: .leading)
            .padding(44)

        case 3:
            VStack(alignment: .leading, spacing: 14) {
                SectionLabel(text: "The detail you might have missed")
                if let fact = model.profile.facts.first {
                    Text(fact.value)
                        .font(.system(size: 74, weight: .bold, design: .rounded))
                        .foregroundStyle(tint)
                        .minimumScaleFactor(0.72)
                    Text(fact.label)
                        .font(.system(size: 27, weight: .semibold, design: .serif))
                        .foregroundStyle(TokenBarTheme.text)
                    Text(fact.copy)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .italic()
                        .foregroundStyle(tint.opacity(0.90))
                        .lineSpacing(5)
                        .frame(maxWidth: 760, alignment: .leading)
                    HStack(spacing: 18) {
                        ForEach(Array(model.profile.facts.dropFirst().prefix(2))) { nextFact in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(nextFact.value)
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundStyle(TokenBarTheme.text)
                                Text(nextFact.label.uppercased())
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(TokenBarTheme.secondary)
                            }
                        }
                    }
                    .padding(.top, 8)
                } else {
                    Text("Your surprising facts appear after the next analysis.")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(TokenBarTheme.text)
                }
            }
            .frame(maxWidth: 820, alignment: .leading)
            .padding(44)

        default:
            HStack(alignment: .center, spacing: 40) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(growth.map { "\($0.score)" } ?? "--")
                        .font(.system(size: 92, weight: .bold, design: .rounded))
                        .foregroundStyle(tint)
                    Text(growth?.name.uppercased() ?? "NEXT SIGNAL")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(TokenBarTheme.secondary)
                }
                VStack(alignment: .leading, spacing: 14) {
                    SectionLabel(text: "Your next chapter")
                    Text("Build your next advantage.")
                        .font(.system(size: 34, weight: .semibold, design: .serif))
                        .foregroundStyle(TokenBarTheme.text)
                    Text(model.profile.growthEdge)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .italic()
                        .foregroundStyle(tint.opacity(0.90))
                        .lineSpacing(5)
                        .lineLimit(5)

                    HStack(spacing: 10) {
                        Button {
                            model.exportProofPacket()
                        } label: {
                            Label("Download report", systemImage: "arrow.down.doc")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(tint)
                        .disabled(model.profile.sourceURL == nil || model.isExportingProof)

                        if let shareURL = model.receipt.publicProfileURL ?? model.receipt.proofCardURL {
                            Button {
                                model.copy(shareURL.absoluteString, confirmation: "Profile link copied")
                            } label: {
                                Label("Copy profile link", systemImage: "link")
                            }
                            .buttonStyle(.bordered)
                        } else {
                            Button {
                                model.publishCurrentProof()
                            } label: {
                                Label("Create unlisted link", systemImage: "person.crop.square.badge.plus")
                            }
                            .buttonStyle(.bordered)
                            .disabled(model.isPublishingProof || model.profile.sourceURL == nil)
                        }
                    }
                }
                .frame(maxWidth: 620, alignment: .leading)
            }
            .padding(44)
        }
    }

    private func move(to destination: Int) {
        let next = destination >= pageCount ? 0 : max(0, destination)
        TokenBarSound.play(.page)
        TokenBarHaptics.perform(.selection)
        withAnimation(reduceMotion ? .linear(duration: 0.12) : .easeInOut(duration: 0.38)) {
            page = next
        }
    }
}

private struct BuilderDimensionDetailView: View {
    @EnvironmentObject private var model: TokenBarModel
    @Environment(\.dismiss) private var dismiss
    let dimension: BuilderDimension
    let accent: Color

    private var scoreReading: String {
        switch dimension.score {
        case 88...:
            return "Signature strength"
        case 75...:
            return "Dominant pattern"
        case 60...:
            return "Reliable pattern"
        case 45...:
            return "Developing range"
        default:
            return "Next frontier"
        }
    }

    var body: some View {
        ZStack {
            TokenBarTheme.canvas

            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    SectionLabel(text: "Builder scout report")
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 20))
                    .help("Close signal dossier")
                }

                HStack(alignment: .center, spacing: 26) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("\(dimension.score)")
                            .font(.system(size: 94, weight: .bold, design: .rounded))
                            .foregroundStyle(accent)
                        Text(scoreReading.uppercased())
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(TokenBarTheme.secondary)
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text(dimension.name)
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(TokenBarTheme.text)
                        Text(dimension.note)
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .italic()
                            .foregroundStyle(accent.opacity(0.92))
                            .lineSpacing(5)
                    }
                }

                Divider().overlay(TokenBarTheme.border)

                HStack(alignment: .top, spacing: 28) {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionLabel(text: "Why this feels like you")
                        if model.profile.signatureMoves.isEmpty {
                            Text("Analyze a longer window to reveal repeated moves behind this signal.")
                                .foregroundStyle(TokenBarTheme.secondary)
                        } else {
                            ForEach(Array(model.profile.signatureMoves.prefix(4).enumerated()), id: \.offset) { index, move in
                                BuilderEvidenceRow(
                                    index: index + 1,
                                    text: move,
                                    tint: [accent, TokenBarTheme.cyan, TokenBarTheme.amber, TokenBarTheme.green][index]
                                )
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 12) {
                        SectionLabel(text: "The read")
                        Text(scoreReading)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(accent)
                        Text("This is a pattern from the selected local window, not a permanent personality label.")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(TokenBarTheme.secondary)
                            .lineSpacing(3)

                        if let fact = model.profile.facts.first {
                            Divider().overlay(TokenBarTheme.border)
                            Text(fact.value)
                                .font(.system(size: 21, weight: .bold, design: .rounded))
                                .foregroundStyle(TokenBarTheme.amber)
                            Text(fact.copy)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(TokenBarTheme.text)
                                .lineSpacing(3)
                        }

                        Divider().overlay(TokenBarTheme.border)
                        SectionLabel(text: "Next move")
                        Text(dimension.score == model.profile.dimensions.min(by: { $0.score < $1.score })?.score
                             ? model.profile.growthEdge
                             : "Choose one focused project, then compare this signal again after the next build window.")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(TokenBarTheme.text)
                            .lineSpacing(4)
                    }
                    .frame(width: 260, alignment: .leading)
                }

                Spacer()

                HStack(spacing: 10) {
                    Image(nsImage: NSApplication.shared.applicationIconImage)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 28, height: 28)
                    Text("Built from generated aggregates on this Mac. Raw prompts and source code stay outside the story.")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(TokenBarTheme.secondary)
                }
            }
            .padding(28)
        }
        .frame(width: 760, height: 540)
    }
}

private struct BuilderEvidenceRow: View {
    let index: Int
    let text: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            Text(String(format: "%02d", index))
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(tint)
                .frame(width: 22, height: 22)
                .background(tint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 5))

            Text(text)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(TokenBarTheme.text)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(tint.opacity(0.055))
        .overlay {
            RoundedRectangle(cornerRadius: 7)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 7))
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

private struct BuilderFootballCard: View {
    let title: String
    let dimensions: [BuilderDimension]
    let accent: Color
    let openDimension: (BuilderDimension) -> Void

    private var signals: [BuilderDimension] {
        Array(dimensions.prefix(6))
    }

    private var formScore: Int {
        guard !signals.isEmpty else { return 0 }
        return signals.map(\.score).reduce(0, +) / signals.count
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 1) {
                    SectionLabel(text: "Builder form")
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text(signals.isEmpty ? "--" : "\(formScore)")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(accent)
                        Text("AVG")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundStyle(TokenBarTheme.secondary)
                    }
                }

                Spacer()

                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 44, height: 44)
                    .shadow(color: Color.black.opacity(0.35), radius: 8, y: 4)
            }

            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(TokenBarTheme.text)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            BuilderRadarChart(dimensions: signals, accent: accent)
                .frame(height: 180)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3),
                spacing: 6
            ) {
                ForEach(signals) { signal in
                    Button {
                        TokenBarSound.play(.inspect)
                        openDimension(signal)
                    } label: {
                        HStack(spacing: 5) {
                            Text(shortName(for: signal.name))
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundStyle(TokenBarTheme.secondary)
                            Spacer(minLength: 0)
                            Text("\(signal.score)")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(signal.score == signals.map(\.score).max() ? accent : TokenBarTheme.text)
                        }
                        .padding(.horizontal, 8)
                        .frame(height: 28)
                        .background(TokenBarTheme.raised.opacity(0.86))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                    .buttonStyle(.plain)
                    .help("Open the evidence behind \(signal.name)")
                    .accessibilityLabel("\(signal.name), \(signal.score). Open evidence.")
                }
            }

            Text("Tap any attribute to inspect the evidence")
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(TokenBarTheme.secondary)
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [TokenBarTheme.raised, accent.opacity(0.10), TokenBarTheme.panel],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(accent.opacity(0.46), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Builder Form card. Average \(formScore) across \(signals.count) visible signals.")
    }

    private func shortName(for name: String) -> String {
        switch name.lowercased() {
        case "steering": return "STR"
        case "execution": return "EXE"
        case "engineering": return "ENG"
        case "product instinct": return "PRD"
        case "planning": return "PLN"
        case "taste": return "TAS"
        case "research depth": return "RES"
        case "orchestration": return "ORC"
        default: return String(name.prefix(3)).uppercased()
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

private enum ThreadsHubMode: String, CaseIterable, Identifiable {
    case workspace = "My Threads"
    case store = "Thread Store"

    var id: String { rawValue }
}

private struct ThreadsHubView: View {
    @State private var mode: ThreadsHubMode = .workspace

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("Threads mode", selection: $mode) {
                    ForEach(ThreadsHubMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 270)
                .accessibilityLabel("Choose local threads or Thread Store")

                Spacer()

                Text(mode == .workspace ? "Private work on this Mac" : "Portable public handoffs")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(TokenBarTheme.secondary)
            }
            .padding(.horizontal, 30)
            .frame(height: 54)
            .background(TokenBarTheme.sidebar)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(TokenBarTheme.border)
                    .frame(height: 1)
            }

            Group {
                switch mode {
                case .workspace:
                    ThreadsView()
                case .store:
                    OpportunitiesView()
                }
            }
            .id(mode)
            .transition(.opacity.combined(with: .move(edge: .trailing)))
        }
        .background(TokenBarTheme.canvas)
        .animation(.easeInOut(duration: 0.24), value: mode)
        .onChange(of: mode) { _, _ in
            TokenBarSound.play(.inspect)
            TokenBarHaptics.perform(.selection)
        }
    }
}

private struct ThreadsView: View {
    @EnvironmentObject private var model: TokenBarModel
    @State private var draftingThread: CodexThread?
    @State private var inspectingThread: CodexThread?
    @State private var editingBoard: ThreadBoardConfiguration?
    @State private var showingThreadStore = false
    @State private var searchText = ""

    private var board: ThreadBoardConfiguration { model.selectedThreadBoard }
    private var visibleThreads: [CodexThread] {
        let boardQuery = board.workspaceFilter.lowercased()
        let searchQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return model.codexThreads.filter { thread in
            guard board.includeAutomations || !thread.isAutomation else { return false }
            let matchesBoard = boardQuery.isEmpty
                || thread.workspace.lowercased().contains(boardQuery)
                || thread.cwd.lowercased().contains(boardQuery)
                || thread.displayTitle.lowercased().contains(boardQuery)
            let matchesSearch = searchQuery.isEmpty
                || thread.displayTitle.lowercased().contains(searchQuery)
                || thread.workspace.lowercased().contains(searchQuery)
                || thread.shortID.lowercased().contains(searchQuery)
                || (thread.model ?? "").lowercased().contains(searchQuery)
                || thread.goalStatus.lowercased().contains(searchQuery)
            return matchesBoard && matchesSearch
        }
    }
    private func threads(in lane: CodexThreadLane) -> [CodexThread] {
        Array(visibleThreads.filter { $0.lane() == lane }.prefix(7))
    }

    private var activeGoalCount: Int { visibleThreads.filter { $0.goalStatus == "active" }.count }
    private var forkCount: Int { visibleThreads.filter(\.isFork).count }
    private var changedWorkspaceCount: Int {
        Set(visibleThreads.filter { $0.gitReviewState == "changed" }.map(\.cwd)).count
    }
    private var automationCount: Int { visibleThreads.filter(\.isAutomation).count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageChrome(
                    eyebrow: "Local Codex control",
                    title: board.name,
                    subtitle: board.workspaceFilter.isEmpty
                        ? "A saved view of the Codex work already on this Mac."
                        : "Filtered to work matching “\(board.workspaceFilter)”."
                ) {
                    Button {
                        model.refreshThreads()
                    } label: {
                        Label(model.isLoadingThreads ? "Reading…" : "Refresh", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(TokenBarTheme.boardAccent(board.accentName))
                    .disabled(model.isLoadingThreads)
                }

                TokenBarPanel {
                    HStack(spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(TokenBarTheme.secondary)
                            TextField("Search title, project, model, or session ID", text: $searchText)
                                .textFieldStyle(.plain)
                                .font(.system(size: 12, weight: .medium))
                            if !searchText.isEmpty {
                                Button { searchText = "" } label: {
                                    Image(systemName: "xmark.circle.fill")
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(TokenBarTheme.secondary)
                                .help("Clear search")
                            }
                        }
                        .padding(.horizontal, 11)
                        .frame(height: 34)
                        .background(TokenBarTheme.raised)
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                        Picker("Board", selection: Binding(
                            get: { model.selectedThreadBoardID },
                            set: { model.selectThreadBoard($0) }
                        )) {
                            ForEach(model.threadBoards) { board in
                                Text(board.name).tag(board.id)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 150)

                        Button {
                            editingBoard = ThreadBoardConfiguration(
                                id: UUID(),
                                name: "New board",
                                queuedTitle: "Queue",
                                focusTitle: "Now",
                                recentTitle: "Fresh",
                                reviewTitle: "Revisit",
                                doneTitle: "Done",
                                workspaceFilter: "",
                                includeAutomations: true,
                                accentName: "green"
                            )
                        } label: {
                            Image(systemName: "plus")
                        }
                        .buttonStyle(.bordered)
                        .help("Create another saved thread board")
                        .accessibilityLabel("Create thread board")

                        Button {
                            editingBoard = board
                        } label: {
                            Image(systemName: "slider.horizontal.3")
                        }
                        .buttonStyle(.bordered)
                        .help("Rename this board, rename lanes, or filter work")
                        .accessibilityLabel("Customize thread board")

                        Button {
                            showingThreadStore = true
                        } label: {
                            Label("Board templates", systemImage: "square.grid.2x2")
                        }
                        .buttonStyle(.bordered)
                        .help("Install a reusable thread-control board")
                    }
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
                            ThreadLaneColumn(
                                lane: lane,
                                title: board.title(for: lane),
                                subtitle: lane.subtitle,
                                threads: threads(in: lane)
                            ) { thread in
                                draftingThread = thread
                            } onInspect: { thread in
                                inspectingThread = thread
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
                    Text("Boards and drafts stay on this Mac. TokenBar reads Codex thread state but never rewrites Codex's database.")
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
        .sheet(item: $inspectingThread) { thread in
            ThreadDetailSheet(
                thread: thread,
                onDraft: {
                    inspectingThread = nil
                    DispatchQueue.main.async { draftingThread = thread }
                }
            )
            .environmentObject(model)
        }
        .sheet(item: $editingBoard) { board in
            ThreadBoardEditor(
                board: board,
                canDelete: model.threadBoards.count > 1 && model.threadBoards.contains(where: { $0.id == board.id }),
                onSave: { model.saveThreadBoard($0) },
                onDelete: { model.deleteThreadBoard(board.id) }
            )
        }
        .sheet(isPresented: $showingThreadStore) {
            ThreadStoreSheet { kit in
                model.saveThreadBoard(kit.board())
                showingThreadStore = false
            }
        }
    }
}

private struct ThreadStoreKit: Identifiable {
    let id: String
    let name: String
    let caption: String
    let symbol: String
    let tint: Color
    let laneTitles: [String]
    let includesAutomations: Bool
    let seats: Int
    let accentName: String

    func board() -> ThreadBoardConfiguration {
        ThreadBoardConfiguration(
            id: UUID(),
            name: name,
            queuedTitle: laneTitles[0],
            focusTitle: laneTitles[1],
            recentTitle: laneTitles[2],
            reviewTitle: laneTitles[3],
            doneTitle: laneTitles[4],
            workspaceFilter: "",
            includeAutomations: includesAutomations,
            accentName: accentName
        )
    }

    static let catalog: [ThreadStoreKit] = [
        ThreadStoreKit(
            id: "crew-room",
            name: "Crew Room",
            caption: "Ten named seats, explicit owners, and visible handoffs for a serious build.",
            symbol: "person.3.sequence.fill",
            tint: TokenBarTheme.cyan,
            laneTitles: ["Briefing", "Leading", "In flight", "Handoffs", "Landed"],
            includesAutomations: true,
            seats: 10,
            accentName: "cyan"
        ),
        ThreadStoreKit(
            id: "launch-room",
            name: "Launch Room",
            caption: "Keep the promise, the shipping work, and release proof in one view.",
            symbol: "paperplane.fill",
            tint: TokenBarTheme.amber,
            laneTitles: ["Intake", "Promise", "Shipping", "Release proof", "Live"],
            includesAutomations: false,
            seats: 4,
            accentName: "amber"
        ),
        ThreadStoreKit(
            id: "research-desk",
            name: "Research Desk",
            caption: "Separate open questions from evidence and decisions worth keeping.",
            symbol: "books.vertical.fill",
            tint: TokenBarTheme.green,
            laneTitles: ["Inbox", "Questions", "Evidence", "Decisions", "Published"],
            includesAutomations: false,
            seats: 3,
            accentName: "green"
        ),
        ThreadStoreKit(
            id: "recovery-bay",
            name: "Recovery Bay",
            caption: "Collect stalled work, isolate the blocker, and finish with a verification pass.",
            symbol: "wrench.and.screwdriver.fill",
            tint: Color(red: 0.74, green: 0.60, blue: 0.96),
            laneTitles: ["Triage", "Rescue now", "Unblock", "Verify", "Recovered"],
            includesAutomations: true,
            seats: 5,
            accentName: "coral"
        ),
    ]
}

private struct ThreadStoreSheet: View {
    @Environment(\.dismiss) private var dismiss
    let install: (ThreadStoreKit) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Thread Store")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(TokenBarTheme.text)
                    Text("Install a working board, then rename it around your project. Every kit stays local.")
                        .font(.system(size: 12))
                        .foregroundStyle(TokenBarTheme.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }
            }

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 14),
                GridItem(.flexible(), spacing: 14),
            ], spacing: 14) {
                ForEach(ThreadStoreKit.catalog) { kit in
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Image(systemName: kit.symbol)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(kit.tint)
                                .frame(width: 36, height: 36)
                                .background(kit.tint.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 7))
                            Spacer()
                            Text("\(kit.seats) SEATS")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(TokenBarTheme.secondary)
                        }

                        VStack(alignment: .leading, spacing: 5) {
                            Text(kit.name)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(TokenBarTheme.text)
                            Text(kit.caption)
                                .font(.system(size: 11))
                                .foregroundStyle(TokenBarTheme.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        HStack(spacing: 5) {
                            ForEach(0..<kit.seats, id: \.self) { index in
                                Circle()
                                    .fill(index == 0 ? kit.tint : TokenBarTheme.raised)
                                    .overlay(
                                        Text(index == 0 ? "L" : "\(index + 1)")
                                            .font(.system(size: 7, weight: .bold, design: .monospaced))
                                            .foregroundStyle(index == 0 ? Color.black : TokenBarTheme.secondary)
                                    )
                                    .frame(width: 22, height: 22)
                            }
                        }
                        .accessibilityLabel("\(kit.seats) collaboration seats")

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 5)], spacing: 5) {
                            ForEach(kit.laneTitles, id: \.self) { lane in
                                Text(lane.uppercased())
                                    .font(.system(size: 7, weight: .bold))
                                    .foregroundStyle(TokenBarTheme.secondary)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 5)
                                    .background(TokenBarTheme.raised)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                        }

                        Button {
                            install(kit)
                        } label: {
                            Label("Install board", systemImage: "arrow.down.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(kit.tint)
                    }
                    .padding(16)
                    .background(TokenBarTheme.panel)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(TokenBarTheme.border, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            HStack(spacing: 7) {
                Image(systemName: "person.crop.circle.badge.clock")
                    .foregroundStyle(TokenBarTheme.amber)
                Text("Seat layouts work now for ownership and handoffs. Live presence and invitations require the signed-in workspace backend.")
                    .font(.system(size: 10))
                    .foregroundStyle(TokenBarTheme.secondary)
            }
        }
        .padding(24)
        .frame(width: 760)
        .background(TokenBarTheme.canvas)
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
    let title: String
    let subtitle: String
    let threads: [CodexThread]
    let onDraft: (CodexThread) -> Void
    let onInspect: (CodexThread) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(TokenBarTheme.text)
                    Text(subtitle.uppercased())
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
                    CodexThreadRow(
                        thread: thread,
                        onDraft: { onDraft(thread) },
                        onInspect: { onInspect(thread) }
                    )
                    if thread.id != threads.last?.id {
                        Divider().overlay(TokenBarTheme.border)
                    }
                }
            }
        }
    }
}

private struct ThreadBoardEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ThreadBoardConfiguration
    let canDelete: Bool
    let onSave: (ThreadBoardConfiguration) -> Void
    let onDelete: () -> Void

    init(
        board: ThreadBoardConfiguration,
        canDelete: Bool,
        onSave: @escaping (ThreadBoardConfiguration) -> Void,
        onDelete: @escaping () -> Void
    ) {
        _draft = State(initialValue: board)
        self.canDelete = canDelete
        self.onSave = onSave
        self.onDelete = onDelete
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Customize thread board")
                    .font(.system(size: 21, weight: .semibold))
                Text("Name the board, rename its lanes, and optionally focus it on one workspace or keyword.")
                    .font(.system(size: 12))
                    .foregroundStyle(TokenBarTheme.secondary)
            }

            Form {
                TextField("Board name", text: $draft.name)
                TextField("Queue lane", text: $draft.queuedTitle)
                TextField("Active lane", text: $draft.focusTitle)
                TextField("Recent lane", text: $draft.recentTitle)
                TextField("Review lane", text: $draft.reviewTitle)
                TextField("Done lane", text: $draft.doneTitle)
                TextField("Workspace or keyword filter", text: $draft.workspaceFilter)
                Toggle("Include automations", isOn: $draft.includeAutomations)
                Picker("Board color", selection: $draft.accentName) {
                    Text("Mint").tag("green")
                    Text("Cyan").tag("cyan")
                    Text("Amber").tag("amber")
                    Text("Coral").tag("coral")
                }
            }
            .formStyle(.grouped)

            HStack {
                if canDelete {
                    Button("Delete board", role: .destructive) {
                        onDelete()
                        dismiss()
                    }
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save board") {
                    onSave(draft)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 500)
        .background(TokenBarTheme.canvas)
    }
}

private struct CodexThreadRow: View {
    @EnvironmentObject private var model: TokenBarModel
    let thread: CodexThread
    let onDraft: () -> Void
    let onInspect: () -> Void
    @State private var isHovering = false

    private var compactTokens: String {
        let value = Double(thread.tokensUsed)
        if value >= 1_000_000_000 { return String(format: "%.2fB", value / 1_000_000_000) }
        if value >= 1_000_000 { return String(format: "%.1fM", value / 1_000_000) }
        if value >= 1_000 { return String(format: "%.1fK", value / 1_000) }
        return "\(thread.tokensUsed)"
    }

    private func inspectWithCue() {
        TokenBarSound.play(.inspect)
        onInspect()
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
                Button(action: inspectWithCue) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(isHovering ? TokenBarTheme.text : TokenBarTheme.secondary)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .help("Inspect thread \(thread.shortID)")
                .accessibilityLabel("Inspect thread \(thread.shortID)")
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
        .padding(.horizontal, 8)
        .background(isHovering ? TokenBarTheme.raised.opacity(0.8) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
        .onTapGesture(perform: inspectWithCue)
        .onHover { isHovering = $0 }
        .help("Inspect thread \(thread.shortID)")
    }
}

private struct ThreadDetailSheet: View {
    @EnvironmentObject private var model: TokenBarModel
    @Environment(\.dismiss) private var dismiss
    let thread: CodexThread
    let onDraft: () -> Void

    private var compactTokens: String {
        let value = Double(thread.tokensUsed)
        if value >= 1_000_000_000 { return String(format: "%.2fB", value / 1_000_000_000) }
        if value >= 1_000_000 { return String(format: "%.1fM", value / 1_000_000) }
        if value >= 1_000 { return String(format: "%.1fK", value / 1_000) }
        return "\(thread.tokensUsed)"
    }

    private var handoffPacket: String {
        """
        TOKENBAR THREAD HANDOFF
        Title: \(thread.displayTitle)
        Session: \(thread.id)
        Project: \(thread.workspace)
        Status: \(thread.goalStatus)
        Model: \(thread.model ?? "unknown")
        Token weight: \(thread.tokensUsed)
        Branch: \(thread.gitBranch ?? "not recorded")

        Continue by inspecting the current repository state. Do not assume the prior session finished cleanly. State what is proven, what remains uncertain, and the smallest verifiable next action before editing.
        """
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                TokenBarTheme.panel
                TokenBarFluidField(
                    primary: TokenBarTheme.accent(for: thread.id),
                    secondary: TokenBarTheme.cyan,
                    speed: 0.22,
                    intensity: 0.68
                )
                .opacity(0.78)
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        ThreadSignalChip(text: thread.goalStatus.uppercased(), tint: TokenBarTheme.accent(for: thread.id))
                        if thread.isAutomation { ThreadSignalChip(text: "AUTOMATION", tint: TokenBarTheme.amber) }
                        Spacer()
                        Button { dismiss() } label: { Image(systemName: "xmark.circle.fill") }
                            .buttonStyle(.plain)
                            .font(.system(size: 18))
                    }
                    Text(thread.displayTitle)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(TokenBarTheme.text)
                        .lineLimit(3)
                    Text("\(thread.workspace) · updated \(thread.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(TokenBarTheme.secondary)
                }
                .padding(24)
            }
            .frame(height: 220)

            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 26) {
                    MetricInline(value: compactTokens, label: "token weight")
                    MetricInline(value: "\(thread.childThreadCount)", label: "forks")
                    MetricInline(value: "\(thread.changedFileCount)", label: "changed files")
                    MetricInline(value: thread.model ?? "Unknown", label: "model")
                }

                Divider().overlay(TokenBarTheme.border)

                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(text: "Portable handoff")
                    Text("A safe context card, not the private transcript. It carries the session anchor and forces the next builder to verify repository truth.")
                        .font(.system(size: 12))
                        .foregroundStyle(TokenBarTheme.secondary)
                }

                HStack(spacing: 9) {
                    Button("Open in Codex") { model.open(thread.deepLink) }
                        .buttonStyle(.borderedProminent)
                    Button("Copy handoff") { model.copy(handoffPacket, confirmation: "Thread handoff copied") }
                        .buttonStyle(.bordered)
                    Button("Copy session ID") { model.copy(thread.id, confirmation: "Session ID copied") }
                        .buttonStyle(.bordered)
                    Button("Draft follow-up") { onDraft() }
                        .buttonStyle(.bordered)
                    Spacer()
                }
            }
            .padding(24)
        }
        .frame(width: 760, height: 500)
        .background(TokenBarTheme.canvas)
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

private struct ProfileView: View {
    @EnvironmentObject private var model: TokenBarModel
    @State private var windowDays = 7.0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageChrome(
                    eyebrow: "\(model.profile.archetype) · \(model.profile.stance)",
                    title: model.profile.identityTitle,
                    subtitle: "Your activity is evidence for the builder you are becoming, not a scoreboard by itself."
                ) {
                    HStack(spacing: 8) {
                        Button {
                            model.copyUsageCommand()
                        } label: {
                            Label("Copy terminal view", systemImage: "terminal")
                        }
                        .buttonStyle(.bordered)
                        Button(model.isLoadingCosts ? "Reading costs…" : "Estimate costs") {
                            model.refreshUsageCosts()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(model.isLoadingCosts)
                    }
                }

                UsageWindowHero(
                    days: model.profile.usage.days,
                    fallback: model.profile.usage,
                    windowDays: $windowDays,
                    proofScore: model.profile.proofScore
                )

                TokenBarPanel {
                    HStack(spacing: 0) {
                        UsageContext(value: "\(model.profile.usage.sessions)", label: "sessions indexed")
                        Divider().frame(height: 54)
                        UsageContext(value: "\(model.profile.usage.activeDays)/30", label: "active days")
                        Divider().frame(height: 54)
                        UsageContext(value: model.profile.usage.model, label: "top local model")
                        Divider().frame(height: 54)
                        UsageContext(value: "\(model.profile.proofScore)", label: "evidence strength")
                    }
                }

                TokenBarPanel {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            SectionLabel(text: "Local cost estimate")
                            Spacer()
                            if model.costUsage.period != "Not loaded" {
                                Text(model.costUsage.period)
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundStyle(TokenBarTheme.secondary)
                            }
                        }
                        if model.costUsage.period == "Not loaded" {
                            Text("Optional. TokenBar can read the local provider logs through ccusage and estimate API-equivalent cost without uploading them.")
                                .font(.system(size: 13))
                                .foregroundStyle(TokenBarTheme.secondary)
                                .lineSpacing(3)
                        } else {
                            HStack(spacing: 14) {
                                UsageMetric(label: "Latest day", value: model.costUsage.latestCost, note: "API-equivalent estimate", tint: TokenBarTheme.green)
                                UsageMetric(label: "Codex share", value: model.costUsage.codexCost, note: "Latest day", tint: TokenBarTheme.cyan)
                                UsageMetric(label: "Latest tokens", value: model.costUsage.latestTokens, note: "Local provider logs", tint: TokenBarTheme.amber)
                                UsageMetric(label: "Observed history", value: model.costUsage.observedCost, note: "All indexed cost days", tint: TokenBarTheme.coral)
                            }
                        }
                        Label("Calculated locally. Nothing is uploaded.", systemImage: "lock.shield")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(TokenBarTheme.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(30)
            .frame(maxWidth: 1120, alignment: .leading)
        }
        .onChange(of: model.profile.usage.days.count) { _, count in
            windowDays = min(max(1, windowDays), Double(max(1, min(30, count))))
        }
    }
}

private struct UsageWindowHero: View {
    let days: [UsageDaySnapshot]
    let fallback: UsageSnapshot
    @Binding var windowDays: Double
    let proofScore: Int

    private var availableDays: Int { max(1, min(30, days.count)) }
    private var selectedDays: Int { min(availableDays, max(1, Int(windowDays.rounded()))) }
    private var recentDays: [UsageDaySnapshot] { Array(days.suffix(availableDays)) }
    private var selectedTotal: Int64 { recentDays.suffix(selectedDays).reduce(0) { $0 + $1.tokens } }
    private var displayValue: String {
        guard !days.isEmpty else {
            if selectedDays <= 1 { return fallback.today }
            if selectedDays <= 7 { return fallback.last7 }
            return fallback.last30
        }
        return compact(selectedTotal)
    }
    private var dateRange: String {
        guard let first = recentDays.suffix(selectedDays).first, let last = recentDays.last else {
            return "Local aggregate"
        }
        if selectedDays == 1 { return String(last.date.suffix(5)) }
        return "\(first.date.suffix(5)) – \(last.date.suffix(5))"
    }
    private var commentary: String {
        if selectedDays == 1 {
            return "\(displayValue) today. A single day is a pulse, not a personality."
        }
        if selectedDays <= 7 {
            return "\(displayValue) across \(selectedDays) days. Enough motion to reveal a working rhythm; evidence strength is \(proofScore)/100."
        }
        return "\(displayValue) across \(selectedDays) days. The useful question is which sessions became something another person can inspect."
    }

    var body: some View {
        TokenBarPanel {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        SectionLabel(text: selectedDays == 1 ? "Today" : "Last \(selectedDays) days")
                        Text(displayValue)
                            .font(.system(size: 62, weight: .semibold, design: .rounded))
                            .foregroundStyle(TokenBarTheme.green)
                            .contentTransition(.numericText())
                            .animation(.snappy(duration: 0.28), value: displayValue)
                        Text(dateRange)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(TokenBarTheme.secondary)
                    }
                    Spacer()
                    Text(commentary)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(TokenBarTheme.text)
                        .lineSpacing(4)
                        .frame(width: 390, alignment: .leading)
                }

                if !recentDays.isEmpty {
                    GeometryReader { geometry in
                        let peak = max(1, recentDays.map(\.tokens).max() ?? 1)
                        HStack(alignment: .bottom, spacing: 4) {
                            ForEach(Array(recentDays.enumerated()), id: \.element.id) { index, day in
                                let isSelected = index >= recentDays.count - selectedDays
                                Capsule()
                                    .fill(isSelected ? TokenBarTheme.green : TokenBarTheme.raised)
                                    .frame(
                                        width: max(4, (geometry.size.width - CGFloat(recentDays.count - 1) * 4) / CGFloat(recentDays.count)),
                                        height: max(5, geometry.size.height * CGFloat(day.tokens) / CGFloat(peak))
                                    )
                                    .animation(.easeOut(duration: 0.32), value: selectedDays)
                                    .help("\(day.date): \(compact(day.tokens))")
                            }
                        }
                    }
                    .frame(height: 76)
                }

                VStack(spacing: 7) {
                    Slider(
                        value: $windowDays,
                        in: 1...Double(availableDays),
                        step: 1
                    )
                    .disabled(availableDays < 2)
                    .tint(TokenBarTheme.green)
                    HStack {
                        Text("1 day")
                        Spacer()
                        Text("\(availableDays) days")
                    }
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(TokenBarTheme.secondary)
                }
            }
        }
    }

    private func compact(_ value: Int64) -> String {
        let number = Double(value)
        if number >= 1_000_000_000 {
            return String(format: "%.2fB", number / 1_000_000_000)
                .replacingOccurrences(of: ".00B", with: "B")
        }
        if number >= 1_000_000 {
            return String(format: "%.1fM", number / 1_000_000)
                .replacingOccurrences(of: ".0M", with: "M")
        }
        if number >= 1_000 {
            return String(format: "%.1fK", number / 1_000)
                .replacingOccurrences(of: ".0K", with: "K")
        }
        return "\(value)"
    }
}

private struct StorageView: View {
    @EnvironmentObject private var model: TokenBarModel
    @State private var pendingTrash: StorageItemSnapshot?
    @State private var selectedStorage: StorageItemSnapshot?

    private var mappedBytes: Int64 { model.storageItems.reduce(0) { $0 + $1.bytes } }
    private var reclaimableBytes: Int64 {
        model.storageItems.filter(\.isTrashable).reduce(0) { $0 + $1.bytes }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageChrome(
                    eyebrow: "Local storage map",
                    title: "See what the experiments left behind",
                    subtitle: "Inspect generated weight by workspace. Source folders and reports are protected."
                ) {
                    Button {
                        model.refreshStorage()
                    } label: {
                        Label(model.isScanningStorage ? "Scanning…" : "Scan again", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.isScanningStorage)
                }

                HStack(spacing: 14) {
                    StorageHeadline(
                        value: storageSize(mappedBytes),
                        label: "mapped locally",
                        note: "\(model.storageItems.count) known storage areas",
                        tint: TokenBarTheme.cyan
                    )
                    StorageHeadline(
                        value: storageSize(reclaimableBytes),
                        label: "reviewable",
                        note: "recognized generated folders only",
                        tint: TokenBarTheme.green
                    )
                    StorageHeadline(
                        value: "\(model.storageItems.filter { !$0.isTrashable }.count)",
                        label: "protected",
                        note: "reports, receipts, sessions, and logs",
                        tint: TokenBarTheme.amber
                    )
                }

                if model.isScanningStorage && model.storageItems.isEmpty {
                    TokenBarPanel {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("Reading file sizes on this Mac. Nothing is uploaded.")
                                .font(.system(size: 13))
                                .foregroundStyle(TokenBarTheme.secondary)
                        }
                    }
                } else if model.storageItems.isEmpty {
                    TokenBarPanel {
                        Text("No known generated storage areas were found yet.")
                            .font(.system(size: 13))
                            .foregroundStyle(TokenBarTheme.secondary)
                    }
                } else {
                    TokenBarPanel {
                        VStack(alignment: .leading, spacing: 18) {
                            SectionLabel(text: "Weight map")
                            StorageBubbleMap(
                                items: Array(model.storageItems.prefix(12)),
                                selectedID: selectedStorage?.id
                            ) { selectedStorage = $0 }
                            if let selectedStorage {
                                StorageSelectionInspector(item: selectedStorage) {
                                    model.revealStorageItem(selectedStorage)
                                } trash: {
                                    pendingTrash = selectedStorage
                                }
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                            Text("Select a bubble to inspect it. Circle size follows disk weight; green areas are recognized generated folders, while protected evidence stays inspect-only.")
                                .font(.system(size: 11))
                                .foregroundStyle(TokenBarTheme.secondary)
                        }
                    }

                    LazyVStack(alignment: .leading, spacing: 10) {
                        SectionLabel(text: "Review before cleaning")
                        ForEach(model.storageItems) { item in
                            StorageItemRow(item: item) {
                                model.revealStorageItem(item)
                            } trash: {
                                pendingTrash = item
                            }
                        }
                    }
                }

                Label(
                    "TokenBar never empties Trash and never removes source folders. Every cleanup action names one generated folder and asks first.",
                    systemImage: "lock.shield"
                )
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(TokenBarTheme.secondary)
            }
            .padding(30)
            .frame(maxWidth: 1120, alignment: .leading)
        }
        .onAppear {
            if model.storageItems.isEmpty { model.refreshStorage() }
        }
        .confirmationDialog(
            pendingTrash.map { "Move \($0.name) to Trash?" } ?? "Move generated folder to Trash?",
            isPresented: Binding(
                get: { pendingTrash != nil },
                set: { if !$0 { pendingTrash = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let item = pendingTrash {
                Button("Move \(storageSize(item.bytes)) to Trash", role: .destructive) {
                    model.moveStorageItemToTrash(item)
                    pendingTrash = nil
                }
            }
            Button("Cancel", role: .cancel) { pendingTrash = nil }
        } message: {
            Text("Only this recognized generated folder will move to macOS Trash. TokenBar will not empty Trash or touch source files.")
        }
    }
}

private struct StorageHeadline: View {
    let value: String
    let label: String
    let note: String
    let tint: Color

    var body: some View {
        TokenBarPanel {
            VStack(alignment: .leading, spacing: 7) {
                Text(value)
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .foregroundStyle(tint)
                Text(label.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(TokenBarTheme.text)
                Text(note)
                    .font(.system(size: 11))
                    .foregroundStyle(TokenBarTheme.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct StorageBubbleMap: View {
    let items: [StorageItemSnapshot]
    let selectedID: String?
    let onSelect: (StorageItemSnapshot) -> Void
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 6)

    private var peak: Double { Double(max(1, items.map(\.bytes).max() ?? 1)) }

    var body: some View {
        LazyVGrid(columns: columns, alignment: .center, spacing: 14) {
            ForEach(items) { item in
                let ratio = sqrt(Double(max(1, item.bytes)) / peak)
                let diameter = 58 + 48 * ratio
                Button {
                    withAnimation(.snappy(duration: 0.22)) { onSelect(item) }
                } label: {
                    VStack(spacing: 7) {
                        ZStack {
                            Circle()
                                .fill(
                                    item.isTrashable
                                        ? TokenBarTheme.green.opacity(selectedID == item.id ? 0.3 : 0.18)
                                        : TokenBarTheme.cyan.opacity(selectedID == item.id ? 0.24 : 0.13)
                                )
                            Circle()
                                .stroke(
                                    item.isTrashable ? TokenBarTheme.green : TokenBarTheme.cyan,
                                    lineWidth: selectedID == item.id ? 2.4 : 1.2
                                )
                            Text(storageSize(item.bytes))
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(TokenBarTheme.text)
                        }
                        .frame(width: diameter, height: diameter)
                        .shadow(color: (item.isTrashable ? TokenBarTheme.green : TokenBarTheme.cyan).opacity(selectedID == item.id ? 0.22 : 0), radius: 14)
                        Text(item.name)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(selectedID == item.id ? TokenBarTheme.text : TokenBarTheme.secondary)
                            .lineLimit(1)
                            .frame(maxWidth: 120)
                    }
                    .frame(width: 130, height: 132)
                }
                .buttonStyle(.plain)
                .help("\(item.workspace) · \(item.path)")
                .accessibilityLabel("Inspect \(item.name), \(storageSize(item.bytes))")
            }
        }
    }
}

private struct StorageSelectionInspector: View {
    let item: StorageItemSnapshot
    let reveal: () -> Void
    let trash: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(item.isTrashable ? TokenBarTheme.green.opacity(0.16) : TokenBarTheme.cyan.opacity(0.13))
                Image(systemName: item.isTrashable ? "shippingbox.fill" : "lock.shield.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(item.isTrashable ? TokenBarTheme.green : TokenBarTheme.cyan)
            }
            .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(item.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(TokenBarTheme.text)
                    TokenBarPill(
                        label: item.isTrashable ? "Generated" : "Protected",
                        value: item.workspace,
                        tint: item.isTrashable ? TokenBarTheme.green : TokenBarTheme.cyan
                    )
                }
                Text("\(item.fileCount) files · \(item.path)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(TokenBarTheme.secondary)
                    .lineLimit(2)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                Text(storageSize(item.bytes))
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(TokenBarTheme.text)
                HStack(spacing: 7) {
                    Button("Reveal", action: reveal)
                        .buttonStyle(.bordered)
                    if item.isTrashable {
                        Button("Review Trash", role: .destructive, action: trash)
                            .buttonStyle(.bordered)
                    }
                }
            }
        }
        .padding(14)
        .background(TokenBarTheme.raised.opacity(0.7))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(TokenBarTheme.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }
}

private struct StorageItemRow: View {
    let item: StorageItemSnapshot
    let reveal: () -> Void
    let trash: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(item.isTrashable ? TokenBarTheme.green.opacity(0.13) : TokenBarTheme.raised)
                Image(systemName: item.isTrashable ? "shippingbox.fill" : "folder.fill")
                    .foregroundStyle(item.isTrashable ? TokenBarTheme.green : TokenBarTheme.cyan)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(item.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(TokenBarTheme.text)
                    TokenBarPill(
                        label: item.kind,
                        value: item.workspace,
                        tint: item.isTrashable ? TokenBarTheme.green : TokenBarTheme.cyan
                    )
                }
                Text("\(item.fileCount) files · \(item.path)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(TokenBarTheme.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text(storageSize(item.bytes))
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(TokenBarTheme.text)
            Button(action: reveal) {
                Image(systemName: "magnifyingglass")
            }
            .buttonStyle(.bordered)
            .help("Reveal in Finder")
            if item.isTrashable {
                Button(role: .destructive, action: trash) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.bordered)
                .help("Review and move this generated folder to Trash")
            }
        }
        .padding(13)
        .background(TokenBarTheme.panel)
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(TokenBarTheme.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }
}

private func storageSize(_ bytes: Int64) -> String {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
    formatter.countStyle = .file
    formatter.includesUnit = true
    formatter.isAdaptive = true
    return formatter.string(fromByteCount: bytes)
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
    @State private var confirmingPublication = false
    @State private var confirmingRevocation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageChrome(
                    eyebrow: "Builder Identity report",
                    title: "Read it. Download it. Share only if you choose.",
                    subtitle: "The full report is already on this Mac. A public link is optional and never includes raw sessions."
                ) {
                    HStack(spacing: 10) {
                        if let report = model.profile.reportURL {
                            Button("Open report") { model.open(report) }
                                .buttonStyle(.bordered)
                        }
                        Button {
                            model.exportProofPacket()
                        } label: {
                            Label(model.isExportingProof ? "Preparing…" : "Download report", systemImage: "square.and.arrow.down")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(TokenBarTheme.green)
                        .disabled(model.isExportingProof || model.profile.sourceURL == nil)
                        .help("Download a portable ZIP with the report, safe profile data, and a verification file")
                    }
                }

                TokenBarPanel {
                    HStack(alignment: .top, spacing: 24) {
                        VStack(alignment: .leading, spacing: 12) {
                            TokenBarPill(label: "Visibility", value: model.receipt.hasShareSurface ? model.receipt.shareMode : "private", tint: model.receipt.hasShareSurface ? TokenBarTheme.green : TokenBarTheme.amber)
                            Text(model.profile.identityTitle)
                                .font(.system(size: 26, weight: .semibold))
                                .foregroundStyle(TokenBarTheme.text)
                            if model.profile.reportToken.hasPrefix("TBAR-") {
                                Button {
                                    model.copy(model.profile.reportToken, confirmation: "Report ID copied")
                                } label: {
                                    HStack(spacing: 9) {
                                        Text(model.profile.reportToken)
                                            .font(.system(size: 24, weight: .semibold, design: .monospaced))
                                        Image(systemName: "doc.on.doc")
                                    }
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(TokenBarTheme.cyan)
                                .help("Copy the ID for this generated report")
                                Text("This ID belongs to the report. It cannot open your files or access your Mac.")
                                    .font(.system(size: 11))
                                    .foregroundStyle(TokenBarTheme.secondary)
                            } else {
                                Text("No identity token yet")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(TokenBarTheme.secondary)
                            }
                            if !model.receipt.runID.isEmpty {
                                Button {
                                    model.copy(model.receipt.runID, confirmation: "Report run ID copied")
                                } label: {
                                    Label("Run \(model.receipt.runID)", systemImage: "number")
                                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(TokenBarTheme.cyan)
                                .help("Copy the server action run ID")
                            }
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
                            Text("EVIDENCE STRENGTH")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(TokenBarTheme.secondary)
                        }
                    }
                }

                TokenBarPanel {
                    HStack(spacing: 18) {
                        VStack(alignment: .leading, spacing: 5) {
                            SectionLabel(text: "Refresh from Terminal")
                            Text("Run one short command. TokenBar analyzes local Codex evidence, updates this report, and places the new TBAR report ID here automatically.")
                                .font(.system(size: 12))
                                .foregroundStyle(TokenBarTheme.secondary)
                        }
                        Spacer()
                        Button {
                            model.copyClaimCommand()
                        } label: {
                            HStack(spacing: 10) {
                                Text("tokenbar report")
                                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                Image(systemName: "doc.on.doc")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .help("Copy tokenbar report")
                    }
                }

                HStack(alignment: .top, spacing: 14) {
                    TokenBarPanel {
                        VStack(alignment: .leading, spacing: 14) {
                            if model.receipt.hasShareSurface {
                                SectionLabel(text: "Your shared profile")
                                ProofAction(icon: "doc.on.doc", title: "Copy profile link", note: "Share this generated profile without the private sessions behind it", isEnabled: true) {
                                    if let url = model.receipt.publicProfileURL ?? model.receipt.proofCardURL {
                                        model.copy(url.absoluteString, confirmation: "Profile link copied")
                                    }
                                }
                                ProofAction(icon: "safari", title: "Preview public profile", note: "See exactly what another person can view", isEnabled: true) {
                                    model.open(model.receipt.publicProfileURL ?? model.receipt.proofCardURL)
                                }
                                ProofAction(icon: "doc.richtext", title: "Open private report", note: "The richer local report remains on this Mac", isEnabled: model.profile.reportURL != nil) {
                                    model.open(model.profile.reportURL)
                                }
                                Divider().overlay(TokenBarTheme.border)
                                ProofAction(
                                    icon: model.isRevoking ? "ellipsis" : "eye.slash",
                                    title: model.isRevoking ? "Removing public profile…" : "Make profile private",
                                    note: "Remove the public link and rankings entry; keep every local report",
                                    tint: TokenBarTheme.coral,
                                    isEnabled: !model.isRevoking
                                ) {
                                    confirmingRevocation = true
                                }
                            } else {
                                SectionLabel(text: "Optional public link")
                                Text(model.profile.identityTitle)
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(TokenBarTheme.text)
                                    .lineLimit(2)
                                Text("Create an unlisted profile that only people with the link can open. It will not appear in the public feed or rankings.")
                                    .font(.system(size: 12))
                                    .foregroundStyle(TokenBarTheme.secondary)
                                    .lineSpacing(3)
                                HStack(spacing: 18) {
                                    MetricInline(value: "\(model.profile.proofScore)", label: "proof")
                                    MetricInline(value: "\(model.profile.loopScore)", label: "loop")
                                    MetricInline(
                                        value: "\(model.profile.evidenceSessions > 0 ? model.profile.evidenceSessions : model.profile.usage.sessions)",
                                        label: "analyzed"
                                    )
                                }
                                Divider().overlay(TokenBarTheme.border)
                                PrivacyLine(text: "Generated title, evidence summary, and aggregate usage")
                                PrivacyLine(text: "A safety receipt proving private data was excluded")
                                PrivacyLine(text: "Owner name and region hidden by default")
                                Button {
                                    confirmingPublication = true
                                } label: {
                                    Label(model.isPublishingProof ? "Creating link…" : "Create private link", systemImage: model.isPublishingProof ? "ellipsis" : "link.badge.plus")
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(TokenBarTheme.green)
                                .disabled(model.isPublishingProof || model.profile.sourceURL == nil)
                                .help(model.profile.sourceURL == nil ? "Analyze your Builder Identity before publishing" : "Review and confirm the privacy boundary before publishing")
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    TokenBarPanel {
                        VStack(alignment: .leading, spacing: 13) {
                            SectionLabel(text: "Never included")
                            PrivacyLine(text: "Raw transcripts excluded")
                            PrivacyLine(text: "Source code excluded")
                            PrivacyLine(text: "Credentials excluded")
                            PrivacyLine(text: "Sharing requires your action")
                            Divider().overlay(TokenBarTheme.border)
                            Text("A TBAR token points to generated report data. It is not an access key.")
                                .font(.system(size: 11))
                                .foregroundStyle(TokenBarTheme.secondary)
                                .lineSpacing(3)
                        }
                        .frame(width: 280, alignment: .leading)
                    }
                }

                if model.receipt.hasShareSurface, !model.receipt.completedStages.isEmpty {
                    DisclosureGroup("Technical verification") {
                        ProofReceiptPanel(receipt: model.receipt) {
                            model.copy(model.receipt.verificationSummary, confirmation: "Verification receipt copied")
                        }
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(TokenBarTheme.secondary)
                }
            }
            .padding(30)
            .frame(maxWidth: 1120, alignment: .leading)
        }
        .confirmationDialog(
            "Create an unlisted Builder Identity profile?",
            isPresented: $confirmingPublication,
            titleVisibility: .visible
        ) {
            Button("Create private link") {
                model.publishCurrentProof()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("TokenBar will upload only generated identity fields, aggregate usage, selected scores, and a privacy receipt. Your owner name and region are hidden. Raw prompts, transcripts, source code, local paths, credentials, and private files stay on this Mac.")
        }
        .confirmationDialog(
            "Make this Builder Identity profile private?",
            isPresented: $confirmingRevocation,
            titleVisibility: .visible
        ) {
            Button("Remove public link", role: .destructive) {
                model.revokeCurrentProof()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The public proof card, profile, For You entry, and rankings entry will be removed. Your local identity JSON, report, PDF, Skill.md, and usage history stay on this Mac.")
        }
    }

}

private struct ProofReceiptPanel: View {
    let receipt: ProofReceipt
    let copyReceipt: () -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        TokenBarPanel {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        SectionLabel(text: "Verified action receipt")
                        Text("The server action is inspectable, persisted, and reloadable.")
                            .font(.system(size: 12))
                            .foregroundStyle(TokenBarTheme.secondary)
                    }
                    Spacer()
                    Button(action: copyReceipt) {
                        Label("Copy receipt", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                }

                LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                    ForEach(Array(receipt.completedStages.enumerated()), id: \.offset) { index, stage in
                        HStack(spacing: 10) {
                            ZStack {
                                Circle().fill(TokenBarTheme.green.opacity(0.16))
                                Image(systemName: "checkmark")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(TokenBarTheme.green)
                            }
                            .frame(width: 24, height: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(String(format: "%02d", index + 1))
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundStyle(TokenBarTheme.secondary)
                                Text(stageTitle(stage))
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(TokenBarTheme.text)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(10)
                        .background(TokenBarTheme.raised)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }

                Divider().overlay(TokenBarTheme.border)
                HStack(alignment: .top, spacing: 24) {
                    ReceiptFact(
                        label: "Sent",
                        value: receipt.uploadedMaterial.isEmpty
                            ? "Generated proof and aggregate identity fields"
                            : receipt.uploadedMaterial
                    )
                    ReceiptFact(
                        label: "Stayed local",
                        value: receipt.neverPublic.prefix(4).joined(separator: ", ")
                    )
                    ReceiptFact(
                        label: "Ownership",
                        value: receipt.ownerBound ? "Device-bound revoke key" : "Not recorded"
                    )
                }
            }
        }
    }

    private func stageTitle(_ stage: String) -> String {
        switch stage {
        case "request-received": "Request received"
        case "local-boundary-check": "Privacy checked"
        case "identity-validation": "Identity validated"
        case "proof-card-built": "Proof assembled"
        case "persisted": "Receipt persisted"
        case "ready": "Ready to inspect"
        case "revoked": "Proof revoked"
        default: stage.replacingOccurrences(of: "-", with: " ").capitalized
        }
    }
}

private struct ReceiptFact: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(TokenBarTheme.secondary)
            Text(value.isEmpty ? "Not recorded" : value)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(TokenBarTheme.text)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

private struct ThreadStoreListing: Identifiable {
    let id: String
    let title: String
    let maker: String
    let category: String
    let summary: String
    let symbol: String
    let tint: Color
    let seats: Int
    let checkpoint: String
    let nextMove: String

    var handoff: String {
        """
        TOKENBAR PORTABLE THREAD
        Title: \(title)
        Released by: \(maker)
        Category: \(category)
        Collaboration seats: \(seats)

        PURPOSE
        \(summary)

        VERIFIED CHECKPOINT
        \(checkpoint)

        NEXT MOVE
        \(nextMove)

        This package contains a public handoff summary, not a private transcript. Inspect the destination repository before editing and preserve the original builder's stated constraints.
        """
    }

    static let catalog: [ThreadStoreListing] = [
        ThreadStoreListing(
            id: "hackathon-control-room",
            title: "Hackathon Control Room",
            maker: "TokenBar Studio",
            category: "Ship",
            summary: "A six-seat release thread for turning a prototype into one judge-ready story, build, verification receipt, and submission handoff.",
            symbol: "trophy.fill",
            tint: TokenBarTheme.amber,
            seats: 6,
            checkpoint: "Product story, runnable artifact, privacy boundary, and final proof are kept in separate lanes.",
            nextMove: "Choose one missing judge claim, assign an owner, and close it with a reproducible check."
        ),
        ThreadStoreListing(
            id: "slack-release-relay",
            title: "Slack Release Relay",
            maker: "Community preview",
            category: "Community",
            summary: "A multiplayer-style handoff for collecting requests, turning one into a bounded implementation thread, and returning a concise release note.",
            symbol: "bubble.left.and.bubble.right.fill",
            tint: TokenBarTheme.cyan,
            seats: 10,
            checkpoint: "Request, decision, implementation, review, and announcement each have a visible owner.",
            nextMove: "Copy the release context, connect the real Slack source later, and test one request end to end."
        ),
        ThreadStoreListing(
            id: "devops-recovery-deck",
            title: "DevOps Recovery Deck",
            maker: "TokenBar Reliability",
            category: "DevOps",
            summary: "An incident thread that makes symptoms, hypotheses, commands, rollback boundaries, and recovered evidence inspectable without exposing secrets.",
            symbol: "wrench.and.screwdriver.fill",
            tint: TokenBarTheme.coral,
            seats: 5,
            checkpoint: "Every proposed command is separated from observed output and the rollback path remains visible.",
            nextMove: "Attach one sanitized incident summary and verify the smallest recovery action in a disposable environment."
        ),
        ThreadStoreListing(
            id: "research-relay",
            title: "Research Relay",
            maker: "Open Research preview",
            category: "Research",
            summary: "A portable research session that separates sources, claims, failed routes, open questions, and the next falsifiable experiment.",
            symbol: "books.vertical.fill",
            tint: TokenBarTheme.green,
            seats: 4,
            checkpoint: "The public package contains citations and decisions, while private notes and credentials remain local.",
            nextMove: "Select one uncertain claim and hand it to a fresh Codex task with explicit evidence requirements."
        ),
    ]
}

private struct OpportunitiesView: View {
    @EnvironmentObject private var model: TokenBarModel
    @State private var showingImporter = false
    @State private var searchText = ""
    @State private var selectedListing: ThreadStoreListing?

    private var listings: [ThreadStoreListing] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return ThreadStoreListing.catalog }
        return ThreadStoreListing.catalog.filter {
            $0.title.lowercased().contains(query)
                || $0.category.lowercased().contains(query)
                || $0.summary.lowercased().contains(query)
                || $0.maker.lowercased().contains(query)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageChrome(
                    eyebrow: "Thread Store preview",
                    title: "Install context. Continue the work.",
                    subtitle: "Inspect portable project threads, copy a privacy-safe handoff, and continue in Codex without pretending a summary is the private session."
                ) {
                    Button {
                        showingImporter = true
                    } label: {
                        Label("Release a thread", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(TokenBarTheme.green)
                }

                ZStack(alignment: .bottomLeading) {
                    TokenBarTheme.panel
                    TokenBarFluidField(
                        primary: TokenBarTheme.cyan,
                        secondary: TokenBarTheme.amber,
                        speed: 0.26,
                        intensity: 0.76
                    )
                    .opacity(0.88)
                    HStack(alignment: .bottom, spacing: 28) {
                        VStack(alignment: .leading, spacing: 12) {
                            TokenBarPill(label: "Format", value: "Portable thread", tint: TokenBarTheme.cyan)
                            Text("The App Store model, for work in motion.")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundStyle(TokenBarTheme.text)
                                .frame(maxWidth: 640, alignment: .leading)
                            Text("Browse a checkpoint, inspect its contract, then take the next shift. Live publishers, presence, and permissions will require the signed-in service; these preview packages are local and explicit.")
                                .font(.system(size: 13))
                                .foregroundStyle(TokenBarTheme.secondary)
                                .lineSpacing(4)
                                .frame(maxWidth: 670, alignment: .leading)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 5) {
                            Text("4")
                                .font(.system(size: 44, weight: .bold, design: .rounded))
                                .foregroundStyle(TokenBarTheme.green)
                            Text("PREVIEW THREADS")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(TokenBarTheme.secondary)
                        }
                    }
                    .padding(26)
                }
                .frame(minHeight: 260)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(TokenBarTheme.border, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                HStack(spacing: 9) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(TokenBarTheme.secondary)
                    TextField("Search shipping, DevOps, community, research…", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, weight: .medium))
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: { Image(systemName: "xmark.circle.fill") }
                            .buttonStyle(.plain)
                            .foregroundStyle(TokenBarTheme.secondary)
                    }
                }
                .padding(.horizontal, 14)
                .frame(height: 42)
                .background(TokenBarTheme.panel)
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(TokenBarTheme.border, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 7))

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                    ForEach(listings) { listing in
                        ThreadStoreCard(listing: listing) { selectedListing = listing }
                    }
                }

                if listings.isEmpty {
                    Text("No thread packages match “\(searchText)”.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(TokenBarTheme.secondary)
                        .frame(maxWidth: .infinity, minHeight: 100)
                }

                if !model.invitations.isEmpty {
                    SectionLabel(text: "Your local release drafts")
                    ForEach(model.invitations) { invitation in InvitationRow(invitation: invitation) }
                }

                TokenBarPanel {
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: "lock.shield")
                            .foregroundStyle(TokenBarTheme.green)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Portable now. Multiplayer next.")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(TokenBarTheme.text)
                            Text("Release currently creates a local draft from Markdown or JSON. A production store still needs signed publishers, immutable package versions, explicit licenses, moderation, and revocable access. TokenBar will not label local samples as live community threads.")
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
        .sheet(item: $selectedListing) { listing in
            ThreadStoreDetailSheet(listing: listing)
                .environmentObject(model)
        }
    }
}

private struct ThreadStoreCard: View {
    let listing: ThreadStoreListing
    let inspect: () -> Void
    @State private var hovering = false

    var body: some View {
        Button {
            TokenBarSound.play(.inspect)
            inspect()
        } label: {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(listing.tint.opacity(0.16))
                        Image(systemName: listing.symbol)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(listing.tint)
                    }
                    .frame(width: 46, height: 46)
                    Spacer()
                    Text("\(listing.seats) SEATS")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(TokenBarTheme.secondary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(listing.category.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(listing.tint)
                    Text(listing.title)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(TokenBarTheme.text)
                    Text(listing.summary)
                        .font(.system(size: 11))
                        .foregroundStyle(TokenBarTheme.secondary)
                        .lineSpacing(3)
                        .lineLimit(3)
                }

                HStack {
                    Text(listing.maker)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(TokenBarTheme.secondary)
                    Spacer()
                    Label("Inspect", systemImage: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(listing.tint)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 230, alignment: .topLeading)
            .background(hovering ? TokenBarTheme.raised : TokenBarTheme.panel)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(hovering ? listing.tint.opacity(0.7) : TokenBarTheme.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityLabel("Inspect \(listing.title) thread package")
    }
}

private struct ThreadStoreDetailSheet: View {
    @EnvironmentObject private var model: TokenBarModel
    @Environment(\.dismiss) private var dismiss
    let listing: ThreadStoreListing

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                TokenBarTheme.panel
                TokenBarFluidField(
                    primary: listing.tint,
                    secondary: TokenBarTheme.amber,
                    speed: 0.24,
                    intensity: 0.72
                )
                .opacity(0.82)
                VStack(alignment: .leading, spacing: 9) {
                    HStack {
                        TokenBarPill(label: listing.category, value: "\(listing.seats) seats", tint: listing.tint)
                        Spacer()
                        Button { dismiss() } label: { Image(systemName: "xmark.circle.fill") }
                            .buttonStyle(.plain)
                            .font(.system(size: 18))
                    }
                    Image(systemName: listing.symbol)
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(listing.tint)
                    Text(listing.title)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(TokenBarTheme.text)
                    Text(listing.maker)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(TokenBarTheme.secondary)
                }
                .padding(24)
            }
            .frame(height: 250)

            VStack(alignment: .leading, spacing: 18) {
                Text(listing.summary)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(TokenBarTheme.text)
                    .lineSpacing(4)

                HStack(alignment: .top, spacing: 14) {
                    ThreadStoreFact(label: "Verified checkpoint", value: listing.checkpoint, tint: TokenBarTheme.green)
                    ThreadStoreFact(label: "Next shift", value: listing.nextMove, tint: listing.tint)
                }

                HStack(spacing: 9) {
                    Button("Copy thread context") {
                        model.copy(listing.handoff, confirmation: "Portable thread context copied")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(listing.tint)
                    Button("Copy + open Codex") {
                        model.copy(listing.handoff, confirmation: "Portable thread context copied")
                        model.openCodex()
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                    Label("No private transcript included", systemImage: "lock.shield")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(TokenBarTheme.secondary)
                }
            }
            .padding(24)
        }
        .frame(width: 780, height: 590)
        .background(TokenBarTheme.canvas)
    }
}

private struct ThreadStoreFact: View {
    let label: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            SectionLabel(text: label)
            Text(value)
                .font(.system(size: 12))
                .foregroundStyle(TokenBarTheme.secondary)
                .lineSpacing(3)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
        .background(tint.opacity(0.08))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(tint.opacity(0.25), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 7))
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
