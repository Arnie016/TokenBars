import AppKit
import Pow
import SwiftUI
import UniformTypeIdentifiers

enum TokenBarDestination: String, CaseIterable, Identifiable {
    case story = "Story"
    case timeline = "Timeline"
    case threads = "Threads"
    case profile = "Identity"
    case storage = "Storage"
    case proof = "Reports"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .story: "sparkles.rectangle.stack"
        case .timeline: "point.3.connected.trianglepath.dotted"
        case .threads: "rectangle.3.group"
        case .profile: "person.crop.circle"
        case .storage: "externaldrive.badge.timemachine"
        case .proof: "checkmark.seal"
        }
    }

    static let buildServices: [TokenBarDestination] = [.story, .timeline, .threads]
    static let identityServices: [TokenBarDestination] = [.profile, .proof]
    static let systemServices: [TokenBarDestination] = [.storage]
}

enum TokenBarAnalysisWindow: Int, CaseIterable {
    case day = 1
    case week = 7
    case month = 30

    static func normalizedDays(_ value: Int) -> Int {
        Self(rawValue: value)?.rawValue ?? Self.week.rawValue
    }
}

struct OnboardingQuestion: Identifiable, Hashable {
    let id: String
    let prompt: String
    let context: String
    let options: [String]
}

struct OnboardingAnswerSummary: Identifiable, Hashable {
    let id: String
    let label: String
    let value: String
}

enum OnboardingQuestionFactory {
    static func questions(for profile: BuilderProfile) -> [OnboardingQuestion] {
        let sortedDimensions = profile.dimensions.sorted { $0.score > $1.score }
        let dimensions = sortedDimensions
            .prefix(3)
            .map { "\($0.name) · \($0.score)" }
        let signalOptions = dimensions.isEmpty
            ? ["Planning the work", "Directing the agent", "Finishing the result"]
            : Array(dimensions)

        let evidenceOptions: [String]
        if let nextFrontier = sortedDimensions.last {
            evidenceOptions = [
                "Assigned form · \(profile.displayTitle)",
                "Evidence base · \(profile.evidenceSessions) local sessions",
                "Next frontier · \(nextFrontier.name) · \(nextFrontier.score)",
            ]
        } else {
            evidenceOptions = [
                "The assigned builder form",
                "The evidence behind it",
                "The next useful frontier",
            ]
        }

        let reminderAnchor = profile.facts.first?.label ?? "nudge before drift"
        let reminderOptions = [
            "Budget spikes · warn me before a run gets expensive",
            "Work rhythm · remind me around \(reminderAnchor)",
            "Share review · ask before anything leaves this Mac",
        ]

        return [
            OnboardingQuestion(
                id: "signal",
                prompt: "Which pattern should TokenBar watch first?",
                context: "These choices come from the local analysis. Your answer tunes the app, not the identity you were assigned.",
                options: signalOptions
            ),
            OnboardingQuestion(
                id: "evidence",
                prompt: "What should your first story open with?",
                context: "Choose the part you want to understand first. TokenBar keeps this preference on this Mac.",
                options: evidenceOptions
            ),
            OnboardingQuestion(
                id: "reminder",
                prompt: "Where should TokenBar help before the next run?",
                context: "This sets the first reminder lane from aggregate evidence. It does not upload work or change your assigned identity.",
                options: reminderOptions
            ),
        ]
    }
}

struct TokenBarRootView: View {
    @EnvironmentObject private var model: TokenBarModel
    @AppStorage("tokenbar.onboarding.completed") private var onboardingCompleted = false
    @AppStorage("tokenbar.quietDefaults.v2") private var quietDefaultsApplied = false
    @State private var selection: TokenBarDestination? = .story
    @State private var showingSettings = false
    @State private var showingOnboarding = false

    var body: some View {
        ZStack {
            NavigationSplitView {
                VStack(spacing: 0) {
                TokenBarBrand()
                    .padding(.horizontal, 14)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                List(selection: $selection) {
                    Section("Build") {
                        ForEach(TokenBarDestination.buildServices) { destination in
                            SidebarDestinationRow(destination: destination)
                        }
                    }
                    Section("Identity") {
                        ForEach(TokenBarDestination.identityServices) { destination in
                            SidebarDestinationRow(destination: destination)
                        }
                    }
                    Section("System") {
                        ForEach(TokenBarDestination.systemServices) { destination in
                            SidebarDestinationRow(destination: destination)
                        }
                    }
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
                    case .timeline: BuilderTimelineView()
                    case .threads: ThreadsHubView()
                    case .profile: ProfileView()
                    case .storage: StorageView()
                    case .proof: ProofView()
                    }
                }
                .background(TokenBarAppBackground())
            }
            .tint(TokenBarTheme.cyan)
            .background(TokenBarTheme.canvas)
            .allowsHitTesting(onboardingCompleted && !showingOnboarding)

            if !onboardingCompleted || showingOnboarding {
                TokenBarOnboardingView(isReplay: onboardingCompleted) {
                    withAnimation(.easeOut(duration: 0.22)) {
                        onboardingCompleted = true
                        showingOnboarding = false
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
            TokenBarSettingsView {
                showingOnboarding = true
            }
                .environmentObject(model)
        }
        .onAppear {
            guard !quietDefaultsApplied else { return }
            UserDefaults.standard.set(false, forKey: "tokenbar.sound.enabled")
            UserDefaults.standard.set(false, forKey: "tokenbar.haptics.enabled")
            UserDefaults.standard.set(false, forKey: "tokenbar.cinematicSound.enabled")
            quietDefaultsApplied = true
        }
    }
}

private struct SidebarDestinationRow: View {
    let destination: TokenBarDestination

    var body: some View {
        Label(destination.rawValue, systemImage: destination.icon)
            .font(.system(size: 13, weight: .medium))
            .tag(destination)
    }
}

private struct TokenBarOnboardingView: View {
    @EnvironmentObject private var model: TokenBarModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("tokenbar.analysis.defaultDays") private var defaultAnalysisDays = 7
    @AppStorage("tokenbar.onboarding.answer.signal") private var signalAnswer = ""
    @AppStorage("tokenbar.onboarding.answer.evidence") private var evidenceAnswer = ""
    @AppStorage("tokenbar.onboarding.answer.guardrail") private var guardrailAnswer = ""
    let isReplay: Bool
    let finish: () -> Void
    @State private var phase = OnboardingPhase.intro
    @State private var analysisDays = 7
    @State private var appeared = false
    @State private var analysisProgress = 0.0
    @State private var questionIndex = 0
    @State private var answers: [String: String] = [:]
    @State private var requestedAnalysis = false
    @State private var progressTask: Task<Void, Never>?

    private var hasCodexEvidence: Bool {
        model.profile.sourceURL != nil || model.profile.evidenceSessions > 0 || !model.codexThreads.isEmpty
    }

    private var windowName: String {
        switch analysisDays {
        case 1: "today"
        case 30: "this month"
        default: "this week"
        }
    }

    private var questions: [OnboardingQuestion] {
        OnboardingQuestionFactory.questions(for: model.profile)
    }

    private var revealPreferenceRows: [OnboardingAnswerSummary] {
        [
            OnboardingAnswerSummary(id: "signal", label: "Focus", value: signalAnswer),
            OnboardingAnswerSummary(id: "story", label: "Story", value: evidenceAnswer),
            OnboardingAnswerSummary(id: "reminder", label: "Reminder", value: guardrailAnswer),
        ].filter { !$0.value.isEmpty }
    }

    private var currentQuestion: OnboardingQuestion {
        questions[min(questionIndex, questions.count - 1)]
    }

    private var progressStage: String {
        switch analysisProgress {
        case ..<0.24: "Indexing local sessions"
        case ..<0.52: "Finding repeated decisions"
        case ..<0.80: "Comparing working patterns"
        case ..<1.0: "Writing your private story"
        default: "Analysis complete"
        }
    }

    var body: some View {
        ZStack {
            TokenBarTheme.canvas.ignoresSafeArea()
            TokenBarFluidField(
                primary: TokenBarTheme.coral,
                secondary: TokenBarTheme.cyan,
                speed: 0.12,
                intensity: 0.46,
                mood: .goodNight
            )
                .ignoresSafeArea()

            VStack(spacing: 0) {
                onboardingHeader
                onboardingContent
                    .id(phase)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                onboardingFooter
            }
            .frame(width: 900, height: 680)
            .background(TokenBarTheme.nightInk.opacity(0.90))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.13), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: Color.black.opacity(0.48), radius: 42, y: 22)
            .scaleEffect(appeared ? 1 : 0.975)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            analysisDays = TokenBarAnalysisWindow.normalizedDays(defaultAnalysisDays)
            UserDefaults.standard.set(false, forKey: "tokenbar.sound.enabled")
            UserDefaults.standard.set(false, forKey: "tokenbar.haptics.enabled")
            UserDefaults.standard.set(false, forKey: "tokenbar.cinematicSound.enabled")
            withAnimation(.easeOut(duration: reduceMotion ? 0.1 : 0.55)) { appeared = true }
        }
        .onDisappear {
            progressTask?.cancel()
        }
        .onChange(of: model.isAnalyzing) { wasAnalyzing, isAnalyzing in
            guard requestedAnalysis, wasAnalyzing, !isAnalyzing else { return }
            progressTask?.cancel()
            if model.lastError == nil {
                withAnimation(.easeOut(duration: reduceMotion ? 0.1 : 0.45)) {
                    analysisProgress = 1
                }
                Task {
                    try? await Task.sleep(nanoseconds: reduceMotion ? 120_000_000 : 650_000_000)
                    questionIndex = 0
                    withAnimation(.easeOut(duration: reduceMotion ? 0.1 : 0.32)) {
                        phase = .questions
                    }
                }
            } else {
                requestedAnalysis = false
                withAnimation(.easeOut(duration: 0.2)) {
                    phase = .intro
                    analysisProgress = 0
                }
            }
        }
    }

    private var onboardingHeader: some View {
        HStack(spacing: 18) {
            HStack(spacing: 10) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 34, height: 34)
                VStack(alignment: .leading, spacing: 1) {
                    Text("TokenBar")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(TokenBarTheme.text)
                    Text(isReplay ? "ANALYSIS REVIEW" : "PRIVATE FIRST ANALYSIS")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(TokenBarTheme.amber)
                }
            }

            Spacer()

            HStack(spacing: 7) {
                ForEach(OnboardingPhase.allCases) { item in
                    Capsule()
                        .fill(item.rawValue <= phase.rawValue ? TokenBarTheme.amber : Color.white.opacity(0.12))
                        .frame(width: item == phase ? 34 : 16, height: 4)
                }
            }
            .animation(.easeOut(duration: 0.24), value: phase)

            Text("\(phase.rawValue + 1) / \(OnboardingPhase.allCases.count)")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(TokenBarTheme.secondary)
        }
        .padding(.horizontal, 26)
        .frame(height: 70)
        .background(Color.black.opacity(0.16))
    }

    @ViewBuilder
    private var onboardingContent: some View {
        switch phase {
        case .intro:
            analysisInvitation
        case .reading:
            analysisLoading
        case .questions:
            analysisQuestion
        case .reveal:
            analysisReveal
        }
    }

    private var analysisInvitation: some View {
        VStack(spacing: 22) {
            VStack(spacing: 8) {
                SectionLabel(text: "Private first run")
                Text("Analyze first. Connect later.")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(TokenBarTheme.text)
                Text("TokenBar starts with local Codex evidence, asks three quick questions, then opens the app with budgets, reminders, and stories already shaped around your work.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(TokenBarTheme.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .frame(maxWidth: 610)
            }

            Picker("Analysis window", selection: $analysisDays) {
                Text("Day").tag(1)
                Text("Week").tag(7)
                Text("Month").tag(30)
            }
            .pickerStyle(.segmented)
            .frame(width: 280)

            OnboardingAssemblyRail(phase: phase, progress: analysisProgress, hasCodexEvidence: hasCodexEvidence)
                .frame(maxWidth: 690)

            Button(action: startAnalysis) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [TokenBarTheme.amber, TokenBarTheme.coral],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Circle()
                        .stroke(Color.white.opacity(0.35), lineWidth: 1)
                        .padding(7)
                    VStack(spacing: 10) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 31, weight: .semibold))
                        Text("Analyze my work")
                            .font(.system(size: 16, weight: .bold))
                        Text(windowName.uppercased())
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .opacity(0.72)
                    }
                    .foregroundStyle(TokenBarTheme.canvas)
                }
                .frame(width: 174, height: 174)
                .shadow(color: TokenBarTheme.amber.opacity(0.30), radius: 28, y: 14)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.defaultAction)
            .accessibilityLabel("Analyze my work for \(windowName)")

            HStack(spacing: 24) {
                AnalysisPromise(icon: "terminal", text: hasCodexEvidence ? "Local evidence found" : "Scans local evidence")
                AnalysisPromise(icon: "lock.shield", text: "Raw work stays private")
                AnalysisPromise(icon: "speaker.slash", text: "No sound or haptics")
            }
        }
        .padding(44)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var analysisLoading: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.10), lineWidth: 13)
                Circle()
                    .trim(from: 0, to: analysisProgress)
                    .stroke(
                        AngularGradient(
                            colors: [TokenBarTheme.amber, TokenBarTheme.coral, TokenBarTheme.cyan, TokenBarTheme.amber],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 13, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                Text("\(Int(analysisProgress * 100))%")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundStyle(TokenBarTheme.text)
            }
            .frame(width: 194, height: 194)

            VStack(spacing: 7) {
                Text(progressStage)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(TokenBarTheme.text)
                Text(model.activityMessage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(TokenBarTheme.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 560)
            }

            Text("Nothing is uploaded. Account connection happens later, only when you choose it.")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(TokenBarTheme.secondary)

            OnboardingAssemblyRail(phase: phase, progress: analysisProgress, hasCodexEvidence: hasCodexEvidence)
                .frame(maxWidth: 690)
        }
        .padding(46)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var analysisQuestion: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 7) {
                SectionLabel(text: "Read the result · \(questionIndex + 1) of \(questions.count)")
                Text(currentQuestion.prompt)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(TokenBarTheme.text)
                Text(currentQuestion.context)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(TokenBarTheme.secondary)
                    .lineSpacing(3)
            }

            VStack(spacing: 10) {
                ForEach(Array(currentQuestion.options.enumerated()), id: \.offset) { index, option in
                    Button {
                        answers[currentQuestion.id] = option
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .stroke(
                                        answers[currentQuestion.id] == option
                                            ? TokenBarTheme.amber
                                            : Color.white.opacity(0.22),
                                        lineWidth: 2
                                    )
                                if answers[currentQuestion.id] == option {
                                    Circle()
                                        .fill(TokenBarTheme.amber)
                                        .padding(4)
                                }
                            }
                            .frame(width: 21, height: 21)

                            Text(option)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(TokenBarTheme.text)
                                .multilineTextAlignment(.leading)
                            Spacer()
                            Text(String(UnicodeScalar(65 + index)!))
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                                .foregroundStyle(TokenBarTheme.secondary)
                        }
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
                        .background(
                            answers[currentQuestion.id] == option
                                ? TokenBarTheme.amber.opacity(0.12)
                                : TokenBarTheme.raised.opacity(0.68)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 7)
                                .stroke(
                                    answers[currentQuestion.id] == option
                                        ? TokenBarTheme.amber.opacity(0.72)
                                        : TokenBarTheme.border,
                                    lineWidth: 1
                                )
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(46)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var analysisReveal: some View {
        VStack(spacing: 20) {
            Text("YOUR FIRST EDITION")
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(TokenBarTheme.amber)
            Image(systemName: "seal.fill")
                .font(.system(size: 42))
                .foregroundStyle(TokenBarTheme.coral)
            Text(model.profile.displayTitle)
                .font(.system(size: 43, weight: .bold, design: .serif))
                .foregroundStyle(TokenBarTheme.text)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.68)
                .frame(maxWidth: 660)
            Text(model.profile.displayMotto)
                .font(.system(size: 16, weight: .medium, design: .serif))
                .italic()
                .foregroundStyle(TokenBarTheme.amber)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .frame(maxWidth: 600)
            Text("Assigned from \(model.profile.evidenceSessions) local sessions. Your answers shape presentation, never the identity result.")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(TokenBarTheme.secondary)

            if !revealPreferenceRows.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("FIRST OPERATING PREFS")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(TokenBarTheme.secondary)

                    HStack(spacing: 8) {
                        ForEach(revealPreferenceRows) { row in
                            VStack(alignment: .leading, spacing: 5) {
                                Text(row.label.uppercased())
                                    .font(.system(size: 7, weight: .black, design: .monospaced))
                                    .foregroundStyle(TokenBarTheme.amber)
                                Text(row.value)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(TokenBarTheme.text)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.74)
                            }
                            .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
                            .padding(.horizontal, 12)
                            .background(TokenBarTheme.raised.opacity(0.62))
                            .overlay {
                                RoundedRectangle(cornerRadius: 7)
                                    .stroke(TokenBarTheme.border, lineWidth: 1)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                        }
                    }
                }
                .frame(maxWidth: 660)
                .padding(.top, 5)
            }
        }
        .padding(46)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var onboardingFooter: some View {
        HStack {
            Label("Local analysis first · accounts later", systemImage: "lock")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(TokenBarTheme.secondary)

            Spacer()

            switch phase {
            case .intro, .reading:
                EmptyView()
            case .questions:
                Button {
                    saveCurrentAnswer()
                    if questionIndex < questions.count - 1 {
                        withAnimation(.easeOut(duration: 0.24)) {
                            questionIndex += 1
                        }
                    } else {
                        withAnimation(.easeOut(duration: 0.30)) {
                            phase = .reveal
                        }
                    }
                } label: {
                    Label(
                        questionIndex == questions.count - 1 ? "Reveal my edition" : "Next question",
                        systemImage: "arrow.right"
                    )
                    .frame(minWidth: 150, minHeight: 34)
                }
                .buttonStyle(.borderedProminent)
                .tint(TokenBarTheme.amber)
                .disabled(answers[currentQuestion.id] == nil)
                .keyboardShortcut(.defaultAction)
            case .reveal:
                Button {
                    finish()
                } label: {
                    Label("Enter TokenBar", systemImage: "arrow.right")
                        .frame(minWidth: 150, minHeight: 34)
                }
                .buttonStyle(.borderedProminent)
                .tint(TokenBarTheme.amber)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, 26)
        .frame(height: 72)
        .background(Color.black.opacity(0.18))
    }

    private func startAnalysis() {
        defaultAnalysisDays = analysisDays
        requestedAnalysis = true
        analysisProgress = 0.02
        withAnimation(.easeOut(duration: 0.24)) {
            phase = .reading
        }
        model.refreshIdentity(days: analysisDays)
        progressTask?.cancel()
        progressTask = Task {
            while !Task.isCancelled, model.isAnalyzing {
                try? await Task.sleep(nanoseconds: 110_000_000)
                guard !Task.isCancelled else { return }
                let remaining = max(0, 0.92 - analysisProgress)
                let increment = max(0.008, remaining * 0.055)
                withAnimation(.linear(duration: reduceMotion ? 0.05 : 0.11)) {
                    analysisProgress = min(0.92, analysisProgress + increment)
                }
            }
        }
    }

    private func saveCurrentAnswer() {
        guard let answer = answers[currentQuestion.id] else { return }
        if currentQuestion.id == "signal" {
            signalAnswer = answer
        } else if currentQuestion.id == "evidence" {
            evidenceAnswer = answer
        } else if currentQuestion.id == "reminder" || currentQuestion.id == "guardrail" {
            guardrailAnswer = answer
        }
    }
}

private enum OnboardingPhase: Int, CaseIterable, Identifiable {
    case intro
    case reading
    case questions
    case reveal

    var id: Int { rawValue }
}

private struct AnalysisPromise: View {
    let icon: String
    let text: String

    var body: some View {
        Label(text, systemImage: icon)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(TokenBarTheme.secondary)
    }
}

private struct OnboardingAssemblyRail: View {
    let phase: OnboardingPhase
    let progress: Double
    let hasCodexEvidence: Bool

    private var activeIndex: Int {
        switch phase {
        case .intro: return 0
        case .reading:
            if progress >= 0.78 { return 2 }
            if progress >= 0.36 { return 1 }
            return 0
        case .questions: return 3
        case .reveal: return 5
        }
    }

    private var steps: [(title: String, detail: String, icon: String)] {
        [
            (
                "Account",
                hasCodexEvidence ? "local Mac visible" : "connect later",
                "person.crop.circle.badge.checkmark"
            ),
            ("Evidence", "Codex aggregate only", "folder.badge.gearshape"),
            ("Analyze", "private 100% pass", "sparkles"),
            ("MCQ", "confirm interpretation", "checklist"),
            ("Budget Brief", "guard the next run", "gauge.with.dots.needle.50percent"),
            ("Enter App", "story already shaped", "arrow.right.circle")
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("FIRST-RUN PATH")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(TokenBarTheme.secondary)
                Spacer()
                Text("sound + haptics off")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(TokenBarTheme.secondary)
            }

            HStack(spacing: 8) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    let isComplete = index < activeIndex
                    let isActive = index == activeIndex
                    VStack(alignment: .leading, spacing: 7) {
                        HStack(spacing: 7) {
                            Image(systemName: isComplete ? "checkmark.circle.fill" : step.icon)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(isComplete || isActive ? TokenBarTheme.amber : TokenBarTheme.secondary)
                            Text(step.title)
                                .font(.system(size: 10, weight: .black))
                                .foregroundStyle(isComplete || isActive ? TokenBarTheme.text : TokenBarTheme.secondary)
                                .lineLimit(1)
                        }
                        Text(step.detail)
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(TokenBarTheme.secondary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.75)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, minHeight: 66, alignment: .topLeading)
                    .background(
                        LinearGradient(
                            colors: [
                                (isComplete || isActive ? TokenBarTheme.amber : TokenBarTheme.raised).opacity(isActive ? 0.18 : 0.08),
                                TokenBarTheme.raised.opacity(0.52),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                isActive ? TokenBarTheme.amber.opacity(0.58) : TokenBarTheme.border,
                                lineWidth: 1
                            )
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(12)
        .background(TokenBarTheme.panel.opacity(0.60), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(TokenBarTheme.border, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

private struct OnboardingSourceRow: View {
    let icon: String
    let name: String
    let status: String
    let detail: String
    let tint: Color
    let active: Bool

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .background(tint.opacity(active ? 0.14 : 0.07))
                .clipShape(RoundedRectangle(cornerRadius: 9))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(active ? TokenBarTheme.text : TokenBarTheme.secondary)
                    Text(status.uppercased())
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(tint)
                }
                Text(detail)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(TokenBarTheme.secondary)
            }
            Spacer()
            Image(systemName: active ? "checkmark.circle.fill" : "clock")
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 16)
        .frame(height: 76)
        .background(TokenBarTheme.raised.opacity(active ? 0.78 : 0.42))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(tint.opacity(active ? 0.30 : 0.12), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
    }
}

private struct OnboardingPromise: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(TokenBarTheme.green)
                .frame(width: 20)
            Text(text)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(TokenBarTheme.text)
        }
    }
}

private struct OnboardingToggle: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: icon)
                .foregroundStyle(TokenBarTheme.cyan)
                .frame(width: 21)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(TokenBarTheme.text)
                Text(subtitle)
                    .font(.system(size: 9))
                    .foregroundStyle(TokenBarTheme.secondary)
                    .lineLimit(2)
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.vertical, 10)
    }
}

private struct OnboardingWindowCard: View {
    let days: Int
    let title: String
    let note: String
    @Binding var selectedDays: Int

    private var selected: Bool { selectedDays == days }

    var body: some View {
        Button {
            selectedDays = days
            TokenBarSound.play(.press)
            TokenBarHaptics.perform(.selection)
        } label: {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text(title)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                    Spacer()
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selected ? TokenBarTheme.green : TokenBarTheme.secondary)
                }
                Text("\(days) day\(days == 1 ? "" : "s")")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(selected ? TokenBarTheme.green : TokenBarTheme.cyan)
                Text(note)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(TokenBarTheme.secondary)
            }
            .foregroundStyle(TokenBarTheme.text)
            .padding(15)
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
            .background(selected ? TokenBarTheme.green.opacity(0.10) : TokenBarTheme.raised.opacity(0.60))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(selected ? TokenBarTheme.green.opacity(0.55) : TokenBarTheme.border, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

private struct LaunchEvidence: View {
    let label: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(tint)
            Text(value)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(TokenBarTheme.text)
        }
        .frame(minWidth: 132, alignment: .leading)
    }
}

private struct TokenBarSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var model: TokenBarModel
    @AppStorage("tokenbar.sound.enabled") private var soundEnabled = false
    @AppStorage("tokenbar.haptics.enabled") private var hapticsEnabled = false
    @AppStorage("tokenbar.cinematicSound.enabled") private var cinematicSoundEnabled = false
    @AppStorage("tokenbar.motion.enabled") private var motionEnabled = false
    let runOnboarding: () -> Void

    var body: some View {
        ScrollView {
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
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        Image(systemName: "speaker.wave.2")
                            .foregroundStyle(TokenBarTheme.cyan)
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Interface sound")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(TokenBarTheme.text)
                            Text("Optional local cues for deliberate actions. Off by default.")
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

                    HStack(spacing: 12) {
                        Image(systemName: "waveform.path")
                            .foregroundStyle(TokenBarTheme.indigo)
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Ambient motion")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(TokenBarTheme.text)
                            Text("Slow moving fields on Story and report covers. Off by default.")
                                .font(.system(size: 10))
                                .foregroundStyle(TokenBarTheme.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $motionEnabled)
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
            }

            TokenBarPanel {
                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel(text: "Useful commands")
                    SettingsCommand(command: "tokenbar usage", note: "Read the local usage story")
                    SettingsCommand(command: "tokenbar report", note: "Refresh Builder Identity")
                    SettingsCommand(command: "tokenbar mcp", note: "Expose the safe profile to Codex")
                }
            }

            Button {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    runOnboarding()
                }
            } label: {
                HStack {
                    Label("Run setup again", systemImage: "checklist")
                    Spacer()
                    Text("Sources, privacy, and analysis window")
                        .font(.system(size: 10))
                        .foregroundStyle(TokenBarTheme.secondary)
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 12)
                .frame(height: 38)
                .background(TokenBarTheme.raised)
                .clipShape(RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain)
            }
            .padding(24)
        }
        .frame(width: 680, height: 700)
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
    @AppStorage("tokenbar.analysis.schedule") private var analysisSchedule = "Off"
    @State private var appeared = false
    @State private var storyPage = 0
    @State private var selectedDimension: BuilderDimension?
    @State private var analysisDays = 7
    @State private var analysisStartedAt = Date()
    @State private var showAnalysisReady = false
    @State private var showingCodexConnection = false

    private var identityStyle: BuilderIdentityStyle {
        BuilderIdentityCatalog.style(at: -1, seed: model.profile.displayTitle)
    }
    private var displayedTitle: String {
        model.profile.displayTitle
    }
    private var displayedMotto: String {
        model.profile.displayMotto
    }
    private var identityRank: BuilderIdentityRank {
        BuilderIdentityRank.resolve(
            evidenceScore: model.profile.proofScore,
            sessions: model.profile.evidenceSessions
        )
    }
    private var accent: Color {
        TokenBarTheme.identityPalette(identityStyle.paletteIndex).primary
    }
    private var analysisLabel: String {
        switch analysisDays {
        case 1: "day"
        case 30: "month"
        default: "week"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("BUILDER STORY · CHAPTER \(storyPage + 1) OF 5")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(TokenBarTheme.coral)
                    Text("Watch how you built")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(TokenBarTheme.text)
                    Text(displayedTitle)
                        .font(.system(size: 10, weight: .medium, design: .serif))
                        .foregroundStyle(TokenBarTheme.secondary)
                        .lineLimit(1)
                }

                Spacer()

                HStack(spacing: 8) {
                    Button {
                        showingCodexConnection = true
                    } label: {
                        Image(systemName: "link.badge.plus")
                    }
                    .buttonStyle(.bordered)
                    .help("Open the read-only Codex connection guide")
                    .accessibilityLabel("Connect Codex")

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

                    Menu {
                        ForEach(["Off", "Daily", "Weekly", "Monthly"], id: \.self) { option in
                            Button {
                                analysisSchedule = option
                            } label: {
                                if analysisSchedule == option {
                                    Label(option, systemImage: "checkmark")
                                } else {
                                    Text(option)
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "calendar.badge.clock")
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 28)
                    .help(analysisSchedule == "Off" ? "Schedule local analysis" : "\(analysisSchedule) analysis reminder")

                    Button {
                        analysisStartedAt = Date()
                        showAnalysisReady = false
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
                .frame(minHeight: 38, maxHeight: 38, alignment: .trailing)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 74)
            .background(TokenBarTheme.panel.opacity(0.94))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(TokenBarTheme.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            BuilderIdentityReportExperience(
                page: $storyPage,
                displayTitle: displayedTitle,
                displayMotto: displayedMotto,
                rank: identityRank,
                accent: accent
            ) { dimension in
                selectedDimension = dimension
            }
            .environmentObject(model)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)
            .frame(maxWidth: .infinity, minHeight: 510, maxHeight: .infinity, alignment: .top)
            .layoutPriority(1)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(TokenBarAppBackground())
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
        .onAppear {
            appeared = true
        }
        .onChange(of: model.isAnalyzing) { wasAnalyzing, isAnalyzing in
            if wasAnalyzing && !isAnalyzing && model.lastError == nil {
                showAnalysisReady = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                    showAnalysisReady = false
                }
            } else if wasAnalyzing && !isAnalyzing {
                showAnalysisReady = false
            }
        }
        .sheet(item: $selectedDimension) { dimension in
            BuilderDimensionDetailView(dimension: dimension, accent: accent)
                .environmentObject(model)
        }
        .sheet(isPresented: $showingCodexConnection) {
            CodexConnectionSheet()
                .environmentObject(model)
        }
    }
}

private struct CodexConnectionSheet: View {
    @EnvironmentObject private var model: TokenBarModel
    @Environment(\.dismiss) private var dismiss

    private var connectionTint: Color {
        switch model.identityBridgeSource {
        case .liveAPI, .safeSnapshot, .localFile:
            TokenBarTheme.green
        case .checking:
            TokenBarTheme.cyan
        case .unavailable:
            TokenBarTheme.amber
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                TokenBarFluidField(
                    primary: TokenBarTheme.cyan,
                    secondary: TokenBarTheme.amber,
                    speed: 0.18,
                    intensity: 0.45
                )
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        TokenBarPill(
                            label: "Connection",
                            value: model.identityBridgeSource.label,
                            tint: connectionTint
                        )
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18))
                        }
                        .buttonStyle(.plain)
                    }
                    Text("Bring TokenBar into Codex.")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(TokenBarTheme.text)
                    Text("A read-only bridge lets Codex inspect your safe Builder Identity bundle. Source code, raw prompts, transcripts, and credentials are excluded.")
                        .font(.system(size: 13))
                        .foregroundStyle(TokenBarTheme.secondary)
                        .lineSpacing(3)
                        .frame(maxWidth: 560, alignment: .leading)
                }
                .padding(24)
            }
            .frame(height: 210)

            VStack(alignment: .leading, spacing: 12) {
                CodexConnectionStep(
                    number: "01",
                    title: "Add the local bridge",
                    copy: "Copy one command and paste it into Terminal. TokenBar registers its bundled MCP with Codex."
                ) {
                    Button("Copy setup command") {
                        model.copyCodexMCPSetup()
                    }
                    .buttonStyle(.bordered)
                }

                CodexConnectionStep(
                    number: "02",
                    title: "Open Codex",
                    copy: "Open the Codex app and let it discover the TokenBar tool. Existing tasks remain untouched."
                ) {
                    Button("Open Codex") {
                        model.openCodex()
                    }
                    .buttonStyle(.borderedProminent)
                }

                CodexConnectionStep(
                    number: "03",
                    title: "Verify the safe bundle",
                    copy: "Refresh the connection status after Codex is open. TokenBar reads aggregate identity evidence only."
                ) {
                    Button(model.isLoadingIdentityBridge ? "Checking…" : "Verify connection") {
                        model.refreshIdentityBridge()
                    }
                    .buttonStyle(.bordered)
                    .disabled(model.isLoadingIdentityBridge)
                }
            }
            .padding(24)
        }
        .frame(width: 680, height: 570)
        .background(TokenBarTheme.canvas)
    }
}

private struct CodexConnectionStep<Trailing: View>: View {
    let number: String
    let title: String
    let copy: String
    let trailing: Trailing

    init(number: String, title: String, copy: String, @ViewBuilder trailing: () -> Trailing) {
        self.number = number
        self.title = title
        self.copy = copy
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 14) {
            Text(number)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(TokenBarTheme.cyan)
                .frame(width: 34, height: 34)
                .background(TokenBarTheme.cyan.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(TokenBarTheme.text)
                Text(copy)
                    .font(.system(size: 11))
                    .foregroundStyle(TokenBarTheme.secondary)
                    .lineLimit(2)
            }
            Spacer()
            trailing
        }
        .padding(13)
        .background(TokenBarTheme.panel)
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(TokenBarTheme.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 7))
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
    let displayTitle: String
    let displayMotto: String
    let rank: BuilderIdentityRank
    let accent: Color
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

    private var tint: Color {
        [accent, TokenBarTheme.cyan, TokenBarTheme.indigo, TokenBarTheme.amber, TokenBarTheme.coral][page]
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
            if page == 0 {
                TokenLoomBackdrop(accent: accent)
            } else {
                TokenBarFluidField(
                    primary: tint,
                    secondary: page.isMultiple(of: 2) ? TokenBarTheme.amber : TokenBarTheme.cyan,
                    speed: 0.2,
                    intensity: 0.76,
                    mood: .goodNight
                )
            }

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
        .frame(minHeight: 390, maxHeight: .infinity)
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
            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 8)

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        SectionLabel(text: "The Token Loom")
                        Text(rank.label.uppercased())
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(TokenBarTheme.green)
                    }

                    Text(displayTitle)
                        .font(.system(size: 48, weight: .semibold, design: .serif))
                        .foregroundStyle(Color.white)
                        .lineLimit(3)
                        .minimumScaleFactor(0.66)
                        .shadow(color: Color.black.opacity(0.42), radius: 12, y: 4)

                    Text(displayMotto)
                        .font(.system(size: 17, weight: .medium, design: .serif))
                        .italic()
                        .foregroundStyle(TokenBarTheme.amber.opacity(0.96))
                        .lineSpacing(4)
                        .lineLimit(3)

                    HStack(spacing: 10) {
                        IdentityEvidenceStat(value: "\(sessions)", label: "sessions woven", tint: TokenBarTheme.amber)
                        Rectangle()
                            .fill(Color.white.opacity(0.22))
                            .frame(width: 1, height: 34)
                        IdentityEvidenceStat(value: "\(activeDays)", label: "active days", tint: TokenBarTheme.green)
                    }
                    .padding(.top, 8)
                }
                .frame(maxWidth: 500, alignment: .leading)

                Spacer()

                HStack(spacing: 9) {
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .foregroundStyle(TokenBarTheme.green)
                    Text("\(model.profile.archetype) · \(model.profile.stance)")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.76))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(.horizontal, 38)
            .padding(.top, 24)
            .padding(.bottom, 18)

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

private struct IdentityEvidenceStat: View {
    let value: String
    let label: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 25, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
                .contentTransition(.numericText())
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.62))
        }
        .accessibilityElement(children: .combine)
    }
}

private struct TokenLoomBackdrop: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let accent: Color
    @State private var breathing = false

    private static let artwork: NSImage? = {
        guard let url = Bundle.main.url(forResource: "TokenLoomHero", withExtension: "png") else {
            return nil
        }
        return NSImage(contentsOf: url)
    }()

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let artwork = Self.artwork {
                    Image(nsImage: artwork)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .scaleEffect(breathing ? 1.018 : 1.0, anchor: .trailing)
                        .offset(x: breathing ? 5 : 0)
                } else {
                    TokenBarFluidField(
                        primary: accent,
                        secondary: TokenBarTheme.amber,
                        speed: 0.14,
                        intensity: 0.68,
                        mood: .goodNight
                    )
                }

                LinearGradient(
                    colors: [
                        TokenBarTheme.nightInk.opacity(0.98),
                        TokenBarTheme.nightInk.opacity(0.88),
                        TokenBarTheme.nightInk.opacity(0.24),
                        Color.clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )

                LinearGradient(
                    colors: [Color.black.opacity(0.26), Color.clear, Color.black.opacity(0.22)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) {
                breathing = true
            }
        }
        .accessibilityHidden(true)
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

private enum BuilderTimelineRange: String, CaseIterable, Identifiable {
    case day = "Day"
    case week = "Week"
    case month = "Month"
    case all = "All"

    var id: String { rawValue }

    var cutoff: Date? {
        let calendar = Calendar.current
        switch self {
        case .day:
            return calendar.startOfDay(for: Date())
        case .week:
            return calendar.date(byAdding: .day, value: -7, to: Date())
        case .month:
            return calendar.date(byAdding: .day, value: -30, to: Date())
        case .all:
            return nil
        }
    }
}

private struct BuilderTimelineView: View {
    @EnvironmentObject private var model: TokenBarModel
    @AppStorage("tokenbar.thread.customizations") private var customizationJSON = "{}"
    @State private var range = BuilderTimelineRange.month
    @State private var inspectingThread: CodexThread?
    @State private var timelinePage = 0
    @State private var galleryPage = 0

    private let timelinePageSize = 5
    private let galleryPageSize = 4

    private var customizations: [String: ThreadCustomization] {
        ThreadCustomizationCodec.decode(customizationJSON)
    }

    private var threads: [CodexThread] {
        model.codexThreads
            .filter { thread in
                guard let cutoff = range.cutoff else { return true }
                return thread.updatedAt >= cutoff
            }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private var dayGroups: [(date: Date, threads: [CodexThread])] {
        let grouped = Dictionary(grouping: threads) { Calendar.current.startOfDay(for: $0.updatedAt) }
        return grouped
            .map { (date: $0.key, threads: $0.value.sorted { $0.updatedAt > $1.updatedAt }) }
            .sorted { $0.date > $1.date }
    }

    private var projectCount: Int { Set(threads.map(\.cwd)).count }
    private var tokenTotal: Int64 { threads.reduce(0) { $0 + $1.tokensUsed } }
    private var changedCount: Int { threads.filter { $0.gitReviewState == "changed" }.count }
    private var timelinePageCount: Int {
        max(1, Int(ceil(Double(threads.count) / Double(timelinePageSize))))
    }
    private var galleryPageCount: Int {
        max(1, Int(ceil(Double(dayGroups.count) / Double(galleryPageSize))))
    }
    private var currentTimelinePage: Int {
        min(max(timelinePage, 0), timelinePageCount - 1)
    }
    private var currentGalleryPage: Int {
        min(max(galleryPage, 0), galleryPageCount - 1)
    }
    private var visibleThreads: [CodexThread] {
        Array(threads.dropFirst(currentTimelinePage * timelinePageSize).prefix(timelinePageSize))
    }
    private var visibleDayGroups: [(date: Date, threads: [CodexThread])] {
        Array(dayGroups.dropFirst(currentGalleryPage * galleryPageSize).prefix(galleryPageSize))
    }
    private var identityEditions: [SavedBuilderReport] {
        model.savedReports
            .filter { report in
                guard let cutoff = range.cutoff else { return true }
                return report.generatedAt >= cutoff
            }
            .sorted { $0.generatedAt < $1.generatedAt }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PageChrome(
                eyebrow: "Builder history",
                title: "See who you became.",
                subtitle: "Identity editions first; the local sessions that shaped them remain available underneath."
            ) {
                HStack(spacing: 9) {
                    Picker("Timeline range", selection: $range) {
                        ForEach(BuilderTimelineRange.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 250)

                    Button {
                        model.refreshThreads()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.isLoadingThreads)
                    .help(model.isLoadingThreads ? "Reading local Codex threads" : "Refresh local Codex threads")
                    .accessibilityLabel("Refresh local Codex threads")
                }
            }

            IdentityEvolutionTrack(reports: identityEditions)

            HStack(spacing: 12) {
                TimelineMetric(value: "\(threads.count)", label: "sessions", tint: TokenBarTheme.ivory)
                TimelineMetric(value: "\(projectCount)", label: "projects", tint: TokenBarTheme.ivory)
                TimelineMetric(value: compactThreadTokens(tokenTotal), label: "token weight", tint: TokenBarTheme.ivory)
                TimelineMetric(value: "\(changedCount)", label: "changed repos", tint: TokenBarTheme.coral)
            }

            if threads.isEmpty {
                TokenBarPanel {
                    HStack(spacing: 12) {
                        Image(systemName: "clock.badge.questionmark")
                            .font(.system(size: 22))
                            .foregroundStyle(TokenBarTheme.amber)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("No local sessions in this range")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(TokenBarTheme.text)
                            Text("Choose a wider range or refresh the local Codex index.")
                                .font(.system(size: 12))
                                .foregroundStyle(TokenBarTheme.secondary)
                        }
                    }
                }
            } else {
                HStack {
                    SectionLabel(text: "Session evidence")
                    Spacer()
                    TimelinePager(
                        page: currentTimelinePage,
                        pageCount: timelinePageCount,
                        previous: { timelinePage = max(0, currentTimelinePage - 1) },
                        next: { timelinePage = min(timelinePageCount - 1, currentTimelinePage + 1) }
                    )
                }

                HStack(spacing: 8) {
                    ForEach(Array(visibleThreads.enumerated()), id: \.element.id) { index, thread in
                        BuilderTimelineRailCard(
                            thread: thread,
                            customization: customizations[thread.id] ?? ThreadCustomization(),
                            position: (currentTimelinePage * timelinePageSize) + index + 1
                        ) {
                            inspectingThread = thread
                        }
                        .frame(maxWidth: .infinity)

                        if index < visibleThreads.count - 1 {
                            Rectangle()
                                .fill(TokenBarTheme.border)
                                .frame(width: 12, height: 1)
                        }
                    }
                }
                .frame(height: 120)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        SectionLabel(text: "Evidence by day")
                        Text("The sessions that contributed to each dated build window.")
                            .font(.system(size: 11))
                            .foregroundStyle(TokenBarTheme.secondary)
                    }
                    Spacer()
                    TimelinePager(
                        page: currentGalleryPage,
                        pageCount: galleryPageCount,
                        previous: { galleryPage = max(0, currentGalleryPage - 1) },
                        next: { galleryPage = min(galleryPageCount - 1, currentGalleryPage + 1) }
                    )
                }

                HStack(spacing: 12) {
                    ForEach(Array(visibleDayGroups.enumerated()), id: \.element.date) { index, group in
                        BuilderDayGalleryCard(
                            date: group.date,
                            threads: group.threads,
                            paletteIndex: (currentGalleryPage * galleryPageSize) + index
                        ) {
                            inspectingThread = group.threads.first
                        }
                        .frame(maxWidth: .infinity)
                    }
                }

                Label("Aggregate metadata only. Raw prompts and transcripts stay outside the chronicle.", systemImage: "lock.shield")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(TokenBarTheme.secondary)
            }
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 16)
        .frame(maxWidth: 1180, maxHeight: .infinity, alignment: .topLeading)
        .background(TokenBarAppBackground())
        .onChange(of: range) { _, _ in
            timelinePage = 0
            galleryPage = 0
        }
        .sheet(item: $inspectingThread) { thread in
            ThreadDetailSheet(thread: thread, onDraft: {})
                .environmentObject(model)
        }
    }
}

private struct TimelinePager: View {
    let page: Int
    let pageCount: Int
    let previous: () -> Void
    let next: () -> Void

    var body: some View {
        HStack(spacing: 7) {
            Button(action: previous) {
                Image(systemName: "arrow.left")
            }
            .buttonStyle(.borderless)
            .disabled(page == 0)
            .help("Previous page")

            Text("\(page + 1) / \(pageCount)")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(TokenBarTheme.secondary)
                .frame(minWidth: 34)

            Button(action: next) {
                Image(systemName: "arrow.right")
            }
            .buttonStyle(.borderless)
            .disabled(page >= pageCount - 1)
            .help("Next page")
        }
    }
}

private struct BuilderTimelineRailCard: View {
    let thread: CodexThread
    let customization: ThreadCustomization
    let position: Int
    let inspect: () -> Void

    private var tint: Color {
        customization.isHighlighted
            ? TokenBarTheme.boardAccent(customization.colorName)
            : TokenBarTheme.accent(for: thread.id)
    }

    var body: some View {
        Button(action: inspect) {
            ZStack(alignment: .topLeading) {
                LinearGradient(
                    colors: [TokenBarTheme.panel, tint.opacity(0.18), TokenBarTheme.panel],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(String(format: "%02d", position))
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(tint)
                        Spacer()
                        Circle()
                            .fill(tint)
                            .frame(width: 7, height: 7)
                    }

                    Text(customization.displayTitle(for: thread))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(TokenBarTheme.text)
                        .lineLimit(3)

                    Spacer(minLength: 2)

                    Label(thread.workspace, systemImage: "folder")
                        .lineLimit(1)
                    HStack {
                        Text(thread.updatedAt.formatted(date: .abbreviated, time: .omitted))
                        Spacer()
                        Text(compactThreadTokens(thread.tokensUsed))
                            .foregroundStyle(tint)
                    }
                }
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(TokenBarTheme.secondary)
                .padding(12)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(TokenBarTheme.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }
}

private struct TimelineMetric: View {
    let value: String
    let label: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(value)
                .font(.system(size: 27, weight: .semibold, design: .rounded))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(TokenBarTheme.secondary)
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TokenBarTheme.panel)
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(TokenBarTheme.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }
}

private struct BuilderTimelineRow: View {
    let thread: CodexThread
    let customization: ThreadCustomization
    let isLast: Bool
    let inspect: () -> Void

    private var tint: Color {
        customization.isHighlighted ? TokenBarTheme.boardAccent(customization.colorName) : TokenBarTheme.accent(for: thread.id)
    }

    var body: some View {
        Button(action: inspect) {
            HStack(alignment: .top, spacing: 14) {
                VStack(spacing: 0) {
                    Circle()
                        .fill(tint)
                        .frame(width: customization.isHighlighted ? 12 : 8, height: customization.isHighlighted ? 12 : 8)
                        .shadow(color: tint.opacity(customization.isHighlighted ? 0.45 : 0), radius: 8)
                    if !isLast {
                        Rectangle()
                            .fill(TokenBarTheme.border)
                            .frame(width: 1, height: 64)
                    }
                }
                .frame(width: 14)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(customization.displayTitle(for: thread))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(TokenBarTheme.text)
                            .lineLimit(2)
                        Spacer()
                        Text(thread.updatedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(TokenBarTheme.secondary)
                    }
                    HStack(spacing: 8) {
                        Label(thread.workspace, systemImage: "folder")
                        Text(thread.goalStatus.isEmpty ? "indexed" : thread.goalStatus)
                        Text(compactThreadTokens(thread.tokensUsed))
                        if thread.changedFileCount > 0 {
                            Text("\(thread.changedFileCount) files")
                        }
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(TokenBarTheme.secondary)
                }
                .padding(.bottom, isLast ? 0 : 12)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct BuilderDayGalleryCard: View {
    let date: Date
    let threads: [CodexThread]
    let paletteIndex: Int
    let inspect: () -> Void

    private var palette: (primary: Color, secondary: Color) {
        TokenBarTheme.identityPalette(paletteIndex)
    }
    private var projects: [String] {
        Array(Set(threads.map(\.workspace))).sorted()
    }

    var body: some View {
        Button(action: inspect) {
            ZStack(alignment: .bottomLeading) {
                LinearGradient(
                    colors: [
                        TokenBarTheme.panel,
                        palette.primary.opacity(0.24),
                        palette.secondary.opacity(0.14),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text(date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(TokenBarTheme.text)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(palette.primary)
                    }

                    HStack(alignment: .center, spacing: 12) {
                        Text("\(threads.count)")
                            .font(.system(size: 29, weight: .semibold, design: .rounded))
                            .foregroundStyle(palette.primary)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(threads.count == 1 ? "SESSION MOVED" : "SESSIONS MOVED")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(TokenBarTheme.secondary)
                            Text(projects.prefix(3).joined(separator: " · "))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(TokenBarTheme.text)
                                .lineLimit(2)
                        }
                    }
                }
                .padding(10)
            }
            .frame(height: 92)
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(TokenBarTheme.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
    }
}

private func compactThreadTokens(_ value: Int64) -> String {
    let number = Double(value)
    if number >= 1_000_000_000 { return String(format: "%.2fB", number / 1_000_000_000) }
    if number >= 1_000_000 { return String(format: "%.1fM", number / 1_000_000) }
    if number >= 1_000 { return String(format: "%.1fK", number / 1_000) }
    return "\(value)"
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
                .labelsHidden()
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
        }
        .background(TokenBarTheme.canvas)
        .onChange(of: mode) { _, _ in
            TokenBarSound.play(.inspect)
            TokenBarHaptics.perform(.selection)
        }
    }
}

private enum ThreadWorkspaceLayout: String, CaseIterable, Identifiable {
    case board = "Board"
    case list = "List"

    var id: String { rawValue }
}

private struct ThreadsView: View {
    @EnvironmentObject private var model: TokenBarModel
    @AppStorage("tokenbar.thread.customizations") private var customizationJSON = "{}"
    @AppStorage("tokenbar.thread.laneOverrides") private var laneOverrideJSON = "{}"
    @State private var draftingThread: CodexThread?
    @State private var inspectingThread: CodexThread?
    @State private var customizingThread: CodexThread?
    @State private var editingBoard: ThreadBoardConfiguration?
    @State private var showingThreadStore = false
    @State private var searchText = ""
    @State private var layout = ThreadWorkspaceLayout.board
    @State private var lanePages: [CodexThreadLane: Int] = [:]

    private let lanePageSize = 4

    private var board: ThreadBoardConfiguration { model.selectedThreadBoard }
    private var customizations: [String: ThreadCustomization] {
        ThreadCustomizationCodec.decode(customizationJSON)
    }
    private var laneOverrides: [String: CodexThreadLane] {
        ThreadLaneOverrideCodec.decode(laneOverrideJSON)
    }
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
    private func allThreads(in lane: CodexThreadLane) -> [CodexThread] {
        visibleThreads.filter { effectiveLane(for: $0) == lane }
    }
    private func effectiveLane(for thread: CodexThread) -> CodexThreadLane {
        laneOverrides[thread.id] ?? thread.lane()
    }
    private func pageCount(for lane: CodexThreadLane) -> Int {
        max(1, Int(ceil(Double(allThreads(in: lane).count) / Double(lanePageSize))))
    }
    private func page(for lane: CodexThreadLane) -> Int {
        min(max(lanePages[lane, default: 0], 0), pageCount(for: lane) - 1)
    }
    private func threads(in lane: CodexThreadLane) -> [CodexThread] {
        Array(allThreads(in: lane).dropFirst(page(for: lane) * lanePageSize).prefix(lanePageSize))
    }
    private func moveLane(_ lane: CodexThreadLane, by delta: Int) {
        lanePages[lane] = min(max(page(for: lane) + delta, 0), pageCount(for: lane) - 1)
    }
    private func moveThread(_ id: String, to lane: CodexThreadLane) {
        guard let thread = model.codexThreads.first(where: { $0.id == id }) else { return }
        var updated = laneOverrides
        if thread.lane() == lane {
            updated.removeValue(forKey: id)
        } else {
            updated[id] = lane
        }
        laneOverrideJSON = ThreadLaneOverrideCodec.encode(updated)
        lanePages[lane] = 0
        model.activityMessage = "Moved “\(thread.cardTitle)” to \(plainLaneTitle(lane))"
    }

    private func saveCustomization(_ customization: ThreadCustomization, for thread: CodexThread) {
        var updated = customizations
        if customization.customTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           ["green", "cyan"].contains(customization.colorName),
           !customization.isHighlighted {
            updated.removeValue(forKey: thread.id)
        } else {
            updated[thread.id] = customization
        }
        customizationJSON = ThreadCustomizationCodec.encode(updated)
    }

    private var activeGoalCount: Int { visibleThreads.filter { $0.goalStatus == "active" }.count }
    private var forkCount: Int { visibleThreads.filter(\.isFork).count }
    private var changedWorkspaceCount: Int {
        Set(visibleThreads.filter { $0.gitReviewState == "changed" }.map(\.cwd)).count
    }
    private var automationCount: Int { visibleThreads.filter(\.isAutomation).count }
    private var boardDisplayName: String {
        board.name.caseInsensitiveCompare("Recovery Bay") == .orderedSame
            ? "Project Finish Line"
            : board.name
    }

    private func plainLaneTitle(_ lane: CodexThreadLane) -> String {
        switch board.title(for: lane).lowercased() {
        case "triage", "queue", "intake": "Waiting"
        case "rescue now", "now", "focus": "Working"
        case "unblock", "fresh": "Next"
        case "verify", "revisit", "review": "Check"
        case "recovered", "done": "Complete"
        default: board.title(for: lane)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageChrome(
                    eyebrow: "Local Codex control",
                    title: boardDisplayName,
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
                                Text(
                                    board.name.caseInsensitiveCompare("Recovery Bay") == .orderedSame
                                        ? "Project Finish Line"
                                        : board.name
                                )
                                .tag(board.id)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 150)

                        Picker("Layout", selection: $layout) {
                            ForEach(ThreadWorkspaceLayout.allCases) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(width: 120)

                        Button {
                            editingBoard = ThreadBoardConfiguration(
                                id: UUID(),
                                name: "New board",
                                queuedTitle: "Waiting",
                                focusTitle: "Working",
                                recentTitle: "Next",
                                reviewTitle: "Check",
                                doneTitle: "Complete",
                                workspaceFilter: "",
                                includeAutomations: true,
                                accentName: "indigo"
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
                    ThreadSummary(value: "\(activeGoalCount)", label: "active goals", tint: TokenBarTheme.indigo)
                    ThreadSummary(value: "\(forkCount)", label: "forked threads", tint: TokenBarTheme.cyan)
                    ThreadSummary(value: "\(changedWorkspaceCount)", label: "repos to review", tint: TokenBarTheme.amber)
                    ThreadSummary(value: "\(automationCount)", label: "automation threads", tint: TokenBarTheme.coral)
                }

                if layout == .board {
                    ScrollView(.horizontal) {
                        HStack(alignment: .top, spacing: 12) {
                            ForEach(CodexThreadLane.allCases) { lane in
                                ThreadLaneColumn(
                                    lane: lane,
                                    title: plainLaneTitle(lane),
                                    subtitle: lane.subtitle,
                                    threads: threads(in: lane),
                                    totalCount: allThreads(in: lane).count,
                                    page: page(for: lane),
                                    pageCount: pageCount(for: lane),
                                    customizations: customizations,
                                    onPreviousPage: { moveLane(lane, by: -1) },
                                    onNextPage: { moveLane(lane, by: 1) },
                                    onMoveThread: moveThread,
                                    onDraft: { draftingThread = $0 },
                                    onInspect: { inspectingThread = $0 },
                                    onCustomize: { customizingThread = $0 }
                                )
                                .padding(14)
                                .frame(width: 248, alignment: .topLeading)
                                .background(TokenBarTheme.panel)
                                .overlay(alignment: .top) {
                                    Rectangle()
                                        .fill(TokenBarTheme.boardAccent(board.accentName))
                                        .frame(height: 3)
                                }
                                .overlay(RoundedRectangle(cornerRadius: 7).stroke(TokenBarTheme.border, lineWidth: 1))
                                .clipShape(RoundedRectangle(cornerRadius: 7))
                            }
                        }
                        .padding(.bottom, 4)
                    }
                    .scrollIndicators(.visible)
                } else {
                    TokenBarPanel {
                        VStack(alignment: .leading, spacing: 22) {
                            ForEach(CodexThreadLane.allCases) { lane in
                                ThreadLaneColumn(
                                    lane: lane,
                                    title: plainLaneTitle(lane),
                                    subtitle: lane.subtitle,
                                    threads: threads(in: lane),
                                    totalCount: allThreads(in: lane).count,
                                    page: page(for: lane),
                                    pageCount: pageCount(for: lane),
                                    customizations: customizations,
                                    onPreviousPage: { moveLane(lane, by: -1) },
                                    onNextPage: { moveLane(lane, by: 1) },
                                    onMoveThread: moveThread,
                                    onDraft: { draftingThread = $0 },
                                    onInspect: { inspectingThread = $0 },
                                    onCustomize: { customizingThread = $0 }
                                )
                                if lane != CodexThreadLane.allCases.last {
                                    Divider().overlay(TokenBarTheme.border)
                                }
                            }
                        }
                    }
                }

                HStack(spacing: 8) {
                    Image(systemName: "hand.draw")
                        .foregroundStyle(TokenBarTheme.cyan)
                    Text("Drag cards between lanes. Your arrangement and drafts stay on this Mac; Codex's database is never rewritten.")
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
        .sheet(item: $customizingThread) { thread in
            ThreadCustomizationEditor(
                thread: thread,
                customization: customizations[thread.id] ?? ThreadCustomization()
            ) { customization in
                saveCustomization(customization, for: thread)
            }
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
            tint: TokenBarTheme.indigo,
            laneTitles: ["Inbox", "Questions", "Evidence", "Decisions", "Published"],
            includesAutomations: false,
            seats: 3,
            accentName: "indigo"
        ),
        ThreadStoreKit(
            id: "recovery-bay",
            name: "Project Finish Line",
            caption: "Keep paused work visible, decide the next step, and close it with a clear result.",
            symbol: "wrench.and.screwdriver.fill",
            tint: Color(red: 0.74, green: 0.60, blue: 0.96),
            laneTitles: ["Waiting", "Working", "Next", "Check", "Complete"],
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
    let totalCount: Int
    let page: Int
    let pageCount: Int
    let customizations: [String: ThreadCustomization]
    let onPreviousPage: () -> Void
    let onNextPage: () -> Void
    let onMoveThread: (String, CodexThreadLane) -> Void
    let onDraft: (CodexThread) -> Void
    let onInspect: (CodexThread) -> Void
    let onCustomize: (CodexThread) -> Void
    @State private var isDropTarget = false

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
                Text("\(totalCount)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(TokenBarTheme.secondary)
            }
            .padding(.bottom, 12)

            HStack(spacing: 7) {
                Image(systemName: isDropTarget ? "arrow.down.to.line.compact" : "hand.draw")
                    .font(.system(size: 10, weight: .semibold))
                Text(isDropTarget ? "Drop to place in \(title)" : "Drag a thread here")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Spacer(minLength: 0)
            }
            .foregroundStyle(isDropTarget ? TokenBarTheme.text : TokenBarTheme.secondary)
            .padding(.horizontal, 9)
            .frame(height: 30)
            .background(isDropTarget ? TokenBarTheme.cyan.opacity(0.18) : TokenBarTheme.raised.opacity(0.54))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isDropTarget ? TokenBarTheme.cyan.opacity(0.7) : TokenBarTheme.border, lineWidth: 1)
            )
            .padding(.bottom, 10)

            if threads.isEmpty {
                Text(lane == .focus ? "No active goal in the local index." : "Nothing in this lane.")
                    .font(.system(size: 11))
                    .foregroundStyle(TokenBarTheme.secondary)
                    .padding(.vertical, 18)
            } else {
                ForEach(threads) { thread in
                    CodexThreadRow(
                        thread: thread,
                        customization: customizations[thread.id] ?? ThreadCustomization(),
                        plannedLaneTitle: title,
                        onDraft: { onDraft(thread) },
                        onInspect: { onInspect(thread) },
                        onCustomize: { onCustomize(thread) }
                    )
                    .draggable(thread.id) {
                        HStack(spacing: 8) {
                            Image(systemName: "rectangle.on.rectangle.angled")
                            Text(customizations[thread.id]?.displayTitle(for: thread) ?? thread.cardTitle)
                                .lineLimit(1)
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(TokenBarTheme.text)
                        .padding(.horizontal, 12)
                        .frame(width: 220, height: 42, alignment: .leading)
                        .background(TokenBarTheme.raised)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    if thread.id != threads.last?.id {
                        Divider().overlay(TokenBarTheme.border)
                    }
                }
            }

            if pageCount > 1 {
                HStack {
                    Button(action: onPreviousPage) {
                        Image(systemName: "arrow.left")
                    }
                    .buttonStyle(.borderless)
                    .disabled(page == 0)
                    .help("Previous \(title) page")

                    Spacer()
                    Text("\(page + 1) / \(pageCount)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(TokenBarTheme.secondary)
                    Spacer()

                    Button(action: onNextPage) {
                        Image(systemName: "arrow.right")
                    }
                    .buttonStyle(.borderless)
                    .disabled(page >= pageCount - 1)
                    .help("Next \(title) page")
                }
                .padding(.top, 10)
            }
        }
        .padding(8)
        .background(isDropTarget ? TokenBarTheme.cyan.opacity(0.10) : Color.clear)
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(
                    isDropTarget ? TokenBarTheme.cyan.opacity(0.78) : Color.clear,
                    style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])
                )
        }
        .contentShape(Rectangle())
        .dropDestination(for: String.self) { ids, _ in
            guard let id = ids.first else { return false }
            onMoveThread(id, lane)
            return true
        } isTargeted: { targeted in
            withAnimation(.easeOut(duration: 0.14)) {
                isDropTarget = targeted
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
                TextField("Not started lane", text: $draft.queuedTitle)
                TextField("In progress lane", text: $draft.focusTitle)
                TextField("Recently active lane", text: $draft.recentTitle)
                TextField("Needs a look lane", text: $draft.reviewTitle)
                TextField("Finished lane", text: $draft.doneTitle)
                TextField("Workspace or keyword filter", text: $draft.workspaceFilter)
                Toggle("Include automations", isOn: $draft.includeAutomations)
                Picker("Board color", selection: $draft.accentName) {
                    Text("Cyan").tag("cyan")
                    Text("Amber").tag("amber")
                    Text("Coral").tag("coral")
                    Text("Indigo").tag("indigo")
                    Text("Ivory").tag("ivory")
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

private struct ThreadCustomizationEditor: View {
    @Environment(\.dismiss) private var dismiss
    let thread: CodexThread
    @State private var customization: ThreadCustomization
    let onSave: (ThreadCustomization) -> Void

    init(
        thread: CodexThread,
        customization: ThreadCustomization,
        onSave: @escaping (ThreadCustomization) -> Void
    ) {
        self.thread = thread
        var normalized = customization
        if normalized.colorName == "green" {
            normalized.colorName = "cyan"
        }
        _customization = State(initialValue: normalized)
        self.onSave = onSave
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Mark this thread")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(TokenBarTheme.text)
                Text("Rename it for TokenBar, choose a signal color, or pin it visually. Codex's original thread record is never rewritten.")
                    .font(.system(size: 12))
                    .foregroundStyle(TokenBarTheme.secondary)
                    .lineSpacing(3)
            }

            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "Display title")
                TextField(thread.cardTitle, text: $customization.customTitle)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(text: "Signal color")
                HStack(spacing: 10) {
                    ForEach(["cyan", "amber", "coral", "indigo", "ivory"], id: \.self) { colorName in
                        Button {
                            customization.colorName = colorName
                        } label: {
                            Circle()
                                .fill(TokenBarTheme.boardAccent(colorName))
                                .frame(width: 24, height: 24)
                                .overlay {
                                    if customization.colorName == colorName {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundStyle(TokenBarTheme.canvas)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        .help(colorName.capitalized)
                    }
                }
            }

            Toggle("Highlight this thread across Board and Timeline", isOn: $customization.isHighlighted)
                .toggleStyle(.switch)
                .tint(TokenBarTheme.boardAccent(customization.colorName))

            HStack {
                Button("Reset") {
                    customization = ThreadCustomization()
                }
                .buttonStyle(.bordered)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    onSave(customization)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(TokenBarTheme.boardAccent(customization.colorName))
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 520)
        .background(TokenBarTheme.canvas)
    }
}

private struct CodexThreadRow: View {
    @EnvironmentObject private var model: TokenBarModel
    let thread: CodexThread
    let customization: ThreadCustomization
    let plannedLaneTitle: String
    let onDraft: () -> Void
    let onInspect: () -> Void
    let onCustomize: () -> Void
    @State private var isHovering = false

    private var tint: Color {
        customization.isHighlighted
            ? TokenBarTheme.boardAccent(customization.colorName)
            : TokenBarTheme.accent(for: thread.id)
    }

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

            Text(customization.displayTitle(for: thread))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(TokenBarTheme.text)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                Label(thread.workspace, systemImage: "folder")
                    .lineLimit(1)
                Text("-> \(plannedLaneTitle)")
                    .foregroundStyle(tint.opacity(0.95))
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
                ThreadIconButton(icon: "paintpalette", help: "Rename, color, or highlight this thread") {
                    onCustomize()
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
        .background {
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    customization.isHighlighted
                        ? tint.opacity(isHovering ? 0.20 : 0.12)
                        : (isHovering ? TokenBarTheme.raised.opacity(0.8) : Color.clear)
                )
        }
        .overlay(alignment: .leading) {
            if customization.isHighlighted {
                RoundedRectangle(cornerRadius: 2)
                    .fill(tint)
                    .frame(width: 3)
                    .padding(.vertical, 8)
            }
        }
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
    @State private var showingIdentityCatalog = false

    private var identityStyle: BuilderIdentityStyle {
        BuilderIdentityCatalog.style(at: -1, seed: model.profile.displayTitle)
    }
    private var rank: BuilderIdentityRank {
        BuilderIdentityRank.resolve(
            evidenceScore: model.profile.proofScore,
            sessions: model.profile.evidenceSessions
        )
    }
    private var displayedTitle: String {
        model.profile.displayTitle
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageChrome(
                    eyebrow: "\(rank.label) · \(model.profile.archetype)",
                    title: displayedTitle,
                    subtitle: model.profile.displayMotto
                ) {
                    HStack(spacing: 8) {
                        Button {
                            showingIdentityCatalog = true
                        } label: {
                            Label("Why this identity?", systemImage: "questionmark.circle")
                        }
                        .buttonStyle(.bordered)
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

                BuilderIdentityHero(
                    style: identityStyle,
                    rank: rank,
                    sourceTitle: model.profile.displayTitle,
                    isCustomSelection: false
                ) {
                    showingIdentityCatalog = true
                }

                BuilderActivityHeatMap(
                    days: model.profile.usage.days,
                    accent: TokenBarTheme.identityPalette(identityStyle.paletteIndex).primary
                )

                IdentityEvidenceRail(
                    title: "Three questions worth keeping",
                    items: Array(
                        IdentityEvidenceFactory.profile(
                            model.profile,
                            displayTitle: displayedTitle,
                            rank: rank
                        )
                        .prefix(3)
                    )
                )

                BuilderCohortLens(
                    profile: model.profile,
                    displayTitle: displayedTitle,
                    reports: model.savedReports
                )

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
        .sheet(isPresented: $showingIdentityCatalog) {
            IdentityCatalogSheet(assignedStyle: identityStyle)
        }
    }
}

private struct BuilderActivityHeatMap: View {
    let days: [UsageDaySnapshot]
    let accent: Color

    private let weeksToShow = 24

    private static let inputFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let keyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private var datedValues: [(date: Date, tokens: Int64)] {
        days.compactMap { day in
            Self.inputFormatter.date(from: day.date).map { ($0, day.tokens) }
        }
    }

    private var endDate: Date {
        datedValues.map(\.date).max() ?? Date()
    }

    private var valuesByDay: [String: Int64] {
        Dictionary(uniqueKeysWithValues: datedValues.map {
            (Self.keyFormatter.string(from: $0.date), $0.tokens)
        })
    }

    private var cells: [[BuilderHeatCell]] {
        let calendar = Calendar(identifier: .gregorian)
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: endDate)?.start ?? endDate
        let start = calendar.date(byAdding: .weekOfYear, value: -(weeksToShow - 1), to: weekStart) ?? weekStart
        return (0..<weeksToShow).map { week in
            (0..<7).map { day in
                let offset = (week * 7) + day
                let date = calendar.date(byAdding: .day, value: offset, to: start) ?? start
                let key = Self.keyFormatter.string(from: date)
                return BuilderHeatCell(date: date, tokens: valuesByDay[key] ?? 0)
            }
        }
    }

    private var maximum: Double {
        Double(max(1, cells.flatMap { $0 }.map(\.tokens).max() ?? 1))
    }

    private var activeDays: Int {
        cells.flatMap { $0 }.filter { $0.tokens > 0 }.count
    }

    private var totalTokens: Int64 {
        cells.flatMap { $0 }.reduce(0) { $0 + $1.tokens }
    }

    private var weekSummaries: [BuilderHeatWeekSummary] {
        cells.enumerated().map { index, week in
            BuilderHeatWeekSummary(
                index: index + 1,
                startDate: week.first?.date ?? endDate,
                tokens: week.reduce(0) { $0 + $1.tokens },
                activeDays: week.filter { $0.tokens > 0 }.count
            )
        }
    }

    private var peakCell: BuilderHeatCell? {
        cells.flatMap { $0 }.max { $0.tokens < $1.tokens }
    }

    private var peakWeek: BuilderHeatWeekSummary? {
        weekSummaries.max { $0.tokens < $1.tokens }
    }

    private var quietWeeks: Int {
        weekSummaries.filter { $0.tokens == 0 }.count
    }

    private var activeRatio: Int {
        Int(round((Double(activeDays) / Double(max(1, weeksToShow * 7))) * 100))
    }

    private var rhythmLabel: String {
        switch activeRatio {
        case 0: "No local rhythm yet"
        case 1..<14: "Sparse bursts"
        case 14..<34: "Focused campaigns"
        case 34..<58: "Steady build rhythm"
        default: "High-frequency operator"
        }
    }

    var body: some View {
        TokenBarPanel {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        SectionLabel(text: "Evidence heat map")
                        Text("Your local build rhythm, not a scoreboard")
                            .font(.system(size: 21, weight: .semibold, design: .serif))
                            .foregroundStyle(TokenBarTheme.text)
                    }
                    Spacer()
                    Text("\(activeDays) active days · \(compact(totalTokens)) token weight")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(TokenBarTheme.secondary)
                }

                HStack(spacing: 9) {
                    BuilderHeatSignalPill(
                        label: "Cadence",
                        value: "\(activeRatio)%",
                        note: rhythmLabel,
                        tint: TokenBarTheme.cyan
                    )
                    BuilderHeatSignalPill(
                        label: "Peak day",
                        value: compact(peakCell?.tokens ?? 0),
                        note: peakCell?.date.formatted(date: .abbreviated, time: .omitted) ?? "No activity",
                        tint: TokenBarTheme.amber
                    )
                    BuilderHeatSignalPill(
                        label: "Quiet weeks",
                        value: "\(quietWeeks)",
                        note: "Useful gaps, not failure",
                        tint: TokenBarTheme.indigo
                    )
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 8) {
                        VStack(alignment: .trailing, spacing: 4) {
                            ForEach(0..<7, id: \.self) { day in
                                Text([1: "M", 3: "W", 5: "F"][day] ?? "")
                                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                                    .foregroundStyle(TokenBarTheme.secondary)
                                    .frame(width: 10, height: 13)
                            }
                        }

                        HStack(alignment: .top, spacing: 4) {
                            ForEach(Array(cells.enumerated()), id: \.offset) { _, week in
                                VStack(spacing: 4) {
                                    ForEach(week) { cell in
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(fill(for: cell.tokens))
                                            .frame(width: 13, height: 13)
                                            .overlay {
                                                RoundedRectangle(cornerRadius: 2)
                                                    .stroke(Color.white.opacity(cell.tokens > 0 ? 0.10 : 0.04), lineWidth: 0.5)
                                            }
                                            .help("\(cell.date.formatted(date: .abbreviated, time: .omitted)) · \(compact(cell.tokens)) token weight")
                                    }
                                }
                            }
                        }
                    }

                    HStack(alignment: .bottom, spacing: 4) {
                        ForEach(weekSummaries) { week in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(week.tokens > 0 ? accent.opacity(0.24 + week.intensity(relativeTo: peakWeek?.tokens ?? 1) * 0.54) : Color.white.opacity(0.055))
                                .frame(width: 13, height: 4 + (34 * week.intensity(relativeTo: peakWeek?.tokens ?? 1)))
                                .overlay(alignment: .top) {
                                    if week.activeDays >= 5 {
                                        Circle()
                                            .fill(TokenBarTheme.ivory.opacity(0.9))
                                            .frame(width: 3.5, height: 3.5)
                                            .offset(y: -5)
                                    }
                                }
                                .help("Week \(week.index) from \(week.startDate.formatted(date: .abbreviated, time: .omitted)) · \(compact(week.tokens)) · \(week.activeDays) active days")
                        }
                    }
                    .padding(.leading, 18)
                    .frame(height: 42, alignment: .bottom)
                }
                .padding(12)
                .background(
                    LinearGradient(
                        colors: [
                            accent.opacity(0.13),
                            TokenBarTheme.raised.opacity(0.44),
                            TokenBarTheme.panel.opacity(0.18),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(TokenBarTheme.border, lineWidth: 1))

                HStack(spacing: 6) {
                    Text("Quiet")
                    ForEach(0..<5, id: \.self) { step in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(step == 0 ? Color.white.opacity(0.055) : accent.opacity(0.18 + (Double(step) * 0.18)))
                            .frame(width: 13, height: 13)
                    }
                    Text("Intense")
                    Spacer()
                    Text("Aggregate activity only · prompts and code are not read here")
                }
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .foregroundStyle(TokenBarTheme.secondary)
            }
        }
    }

    private func fill(for tokens: Int64) -> Color {
        guard tokens > 0 else { return Color.white.opacity(0.055) }
        let intensity = log1p(Double(tokens)) / log1p(maximum)
        return accent.opacity(0.20 + (intensity * 0.72))
    }

    private func compact(_ value: Int64) -> String {
        let amount = Double(value)
        if amount >= 1_000_000_000 { return String(format: "%.2fB", amount / 1_000_000_000) }
        if amount >= 1_000_000 { return String(format: "%.1fM", amount / 1_000_000) }
        if amount >= 1_000 { return String(format: "%.1fK", amount / 1_000) }
        return "\(value)"
    }
}

private struct BuilderHeatWeekSummary: Identifiable {
    var id: Int { index }
    let index: Int
    let startDate: Date
    let tokens: Int64
    let activeDays: Int

    func intensity(relativeTo maximum: Int64) -> Double {
        guard tokens > 0 else { return 0 }
        return log1p(Double(tokens)) / log1p(Double(max(1, maximum)))
    }
}

private struct BuilderHeatSignalPill: View {
    let label: String
    let value: String
    let note: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(TokenBarTheme.secondary)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(note)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(TokenBarTheme.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TokenBarTheme.raised.opacity(0.58))
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(tint.opacity(0.18), lineWidth: 1))
    }
}

private struct BuilderHeatCell: Identifiable {
    var id: Date { date }
    let date: Date
    let tokens: Int64
}

private struct BuilderIdentityHero: View {
    let style: BuilderIdentityStyle
    let rank: BuilderIdentityRank
    let sourceTitle: String
    let isCustomSelection: Bool
    let choose: () -> Void

    private var palette: (primary: Color, secondary: Color) {
        TokenBarTheme.identityPalette(style.paletteIndex)
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            AssignedIdentityTexture(style: style)
            HStack(alignment: .bottom, spacing: 28) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        TokenBarPill(label: "Order", value: style.order, tint: palette.primary)
                        TokenBarPill(label: "Surface", value: style.textureName, tint: palette.secondary)
                    }
                    Text(isCustomSelection ? style.title : sourceTitle)
                        .font(.system(size: 33, weight: .semibold, design: .serif))
                        .foregroundStyle(TokenBarTheme.text)
                        .lineLimit(2)
                        .minimumScaleFactor(0.72)
                    Text(style.motto)
                        .font(.system(size: 13, weight: .medium, design: .serif))
                        .foregroundStyle(TokenBarTheme.secondary)
                        .lineSpacing(3)
                        .lineLimit(3)
                        .frame(maxWidth: 650, alignment: .leading)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(palette.primary.opacity(0.16))
                        Circle()
                            .stroke(palette.primary.opacity(0.62), lineWidth: 1)
                        Image(systemName: style.symbolName)
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(palette.primary)
                    }
                    .frame(width: 74, height: 74)
                    Text(rank.label)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(palette.secondary)
                    Button("Explore the identity system", action: choose)
                        .buttonStyle(.bordered)
                }
            }
            .padding(22)
        }
        .frame(minHeight: 220)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(TokenBarTheme.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct IdentityCatalogSheet: View {
    @Environment(\.dismiss) private var dismiss
    let assignedStyle: BuilderIdentityStyle
    @State private var query = ""

    private var matches: [(offset: Int, element: BuilderIdentityStyle)] {
        Array(BuilderIdentityCatalog.styles.enumerated()).filter { entry in
            let clean = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !clean.isEmpty else { return true }
            return [
                entry.element.title,
                entry.element.order,
                entry.element.textureName,
                entry.element.motto,
            ]
            .joined(separator: " ")
            .localizedCaseInsensitiveContains(clean)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 5) {
                    SectionLabel(text: "Identity atlas")
                    Text("Your edition assigns the title.")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(TokenBarTheme.text)
                    Text("Explore the system without changing the result. No identity is better; each names a different observed working form.")
                        .font(.system(size: 12))
                        .foregroundStyle(TokenBarTheme.secondary)
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                }
                .buttonStyle(.plain)
            }
            .padding(22)

            HStack(spacing: 10) {
                IdentitySystemLevel(
                    index: "01",
                    title: "Form",
                    value: assignedStyle.title,
                    copy: "The memorable name assigned to this report edition.",
                    tint: TokenBarTheme.coral
                )
                IdentitySystemLevel(
                    index: "02",
                    title: "Order",
                    value: assignedStyle.order,
                    copy: "The broader family of related working styles.",
                    tint: TokenBarTheme.cyan
                )
                IdentitySystemLevel(
                    index: "03",
                    title: "Rank",
                    value: "Evidence maturity",
                    copy: "Ranks describe confidence in the pattern, not human worth.",
                    tint: TokenBarTheme.amber
                )
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 14)

            HStack(spacing: 9) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(TokenBarTheme.secondary)
                TextField("Explore forms, orders, textures, and mottos", text: $query)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 12)
            .frame(height: 38)
            .background(TokenBarTheme.raised)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .padding(.horizontal, 22)
            .padding(.bottom, 14)

            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 240), spacing: 12)],
                    spacing: 12
                ) {
                    ForEach(matches, id: \.element.id) { entry in
                        IdentityCatalogCard(
                            style: entry.element,
                            isSelected: assignedStyle.id == entry.element.id
                        )
                    }
                }
                .padding(22)
            }
        }
        .frame(minWidth: 860, minHeight: 660)
        .background(TokenBarTheme.canvas)
    }
}

private struct IdentityCatalogCard: View {
    let style: BuilderIdentityStyle
    let isSelected: Bool

    private var palette: (primary: Color, secondary: Color) {
        TokenBarTheme.identityPalette(style.paletteIndex)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: style.symbolName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(palette.primary)
                Spacer()
                if isSelected {
                    Text("THIS EDITION")
                        .font(.system(size: 7, weight: .black, design: .monospaced))
                        .foregroundStyle(palette.secondary)
                }
            }
            Text(style.title)
                .font(.system(size: 17, weight: .semibold, design: .serif))
                .foregroundStyle(TokenBarTheme.text)
                .lineLimit(2)
                .frame(minHeight: 42, alignment: .topLeading)
            Text(style.order.uppercased())
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(TokenBarTheme.secondary)
                .lineLimit(1)
            Text(style.textureName)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(palette.primary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [TokenBarTheme.panel, palette.primary.opacity(0.14), palette.secondary.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay {
            RoundedRectangle(cornerRadius: 7)
                .stroke(isSelected ? palette.primary : TokenBarTheme.border, lineWidth: isSelected ? 2 : 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }
}

private struct IdentitySystemLevel: View {
    let index: String
    let title: String
    let value: String
    let copy: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(index)
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(tint)
                Text(title.uppercased())
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(TokenBarTheme.secondary)
            }
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .serif))
                .foregroundStyle(TokenBarTheme.text)
                .lineLimit(2)
            Text(copy)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(TokenBarTheme.secondary)
                .lineLimit(2)
        }
        .padding(13)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
        .background(TokenBarTheme.panel)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(TokenBarTheme.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
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
    private var largestStorageItem: StorageItemSnapshot? {
        model.storageItems.max { $0.bytes < $1.bytes }
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
                        tint: TokenBarTheme.coral
                    )
                    StorageHeadline(
                        value: "\(model.storageItems.filter { !$0.isTrashable }.count)",
                        label: "protected",
                        note: "reports, receipts, sessions, and logs",
                        tint: TokenBarTheme.amber
                    )
                }

                if let largestStorageItem, mappedBytes > 0 {
                    StorageInsightBar(
                        item: largestStorageItem,
                        share: Int((Double(largestStorageItem.bytes) / Double(mappedBytes) * 100).rounded()),
                        reveal: { model.revealStorageItem(largestStorageItem) }
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

    var body: some View {
        HStack(spacing: 12) {
            StorageBubbleCluster(
                title: "Generated weight",
                subtitle: "Reviewable experiments",
                items: Array(items.filter(\.isTrashable).prefix(6)),
                selectedID: selectedID,
                tint: TokenBarTheme.coral,
                onSelect: onSelect
            )
            StorageBubbleCluster(
                title: "Protected evidence",
                subtitle: "Reports, logs, and sessions",
                items: Array(items.filter { !$0.isTrashable }.prefix(6)),
                selectedID: selectedID,
                tint: TokenBarTheme.cyan,
                onSelect: onSelect
            )
        }
    }
}

private struct StorageBubbleCluster: View {
    let title: String
    let subtitle: String
    let items: [StorageItemSnapshot]
    let selectedID: String?
    let tint: Color
    let onSelect: (StorageItemSnapshot) -> Void

    private var peak: Double { Double(max(1, items.map(\.bytes).max() ?? 1)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .serif))
                .foregroundStyle(TokenBarTheme.text)
            Text(subtitle.uppercased())
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(tint)

            if items.isEmpty {
                Text("Nothing mapped in this cluster.")
                    .font(.system(size: 10))
                    .foregroundStyle(TokenBarTheme.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                GeometryReader { proxy in
                    ZStack {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            let ratio = sqrt(Double(max(1, item.bytes)) / peak)
                            let diameter = 62 + 46 * ratio
                            let count = max(1, items.count)
                            let angle = (Double.pi * 2 * Double(index) / Double(count)) - (Double.pi / 2)
                            let radialX = count == 1 ? 0 : cos(angle) * Double(proxy.size.width * 0.25)
                            let radialY = count == 1 ? 0 : sin(angle) * Double(proxy.size.height * 0.20)

                            Button {
                                withAnimation(.snappy(duration: 0.22)) { onSelect(item) }
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(tint.opacity(selectedID == item.id ? 0.34 : 0.18))
                                    Circle()
                                        .stroke(tint.opacity(selectedID == item.id ? 1 : 0.62), lineWidth: selectedID == item.id ? 2.5 : 1)
                                    VStack(spacing: 3) {
                                        Text(storageSize(item.bytes))
                                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        Text(item.name)
                                            .font(.system(size: 8, weight: .semibold))
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.65)
                                            .padding(.horizontal, 7)
                                    }
                                    .foregroundStyle(TokenBarTheme.text)
                                }
                                .frame(width: diameter, height: diameter)
                                .shadow(color: tint.opacity(selectedID == item.id ? 0.22 : 0.06), radius: 12)
                            }
                            .buttonStyle(.plain)
                            .position(
                                x: proxy.size.width / 2 + CGFloat(radialX),
                                y: proxy.size.height / 2 + CGFloat(radialY)
                            )
                            .help("\(item.workspace) · \(item.path)")
                            .accessibilityLabel("Inspect \(item.name), \(storageSize(item.bytes))")
                        }
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 290)
        .background(TokenBarTheme.raised.opacity(0.38))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(TokenBarTheme.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

private struct StorageInsightBar: View {
    let item: StorageItemSnapshot
    let share: Int
    let reveal: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "externaldrive.fill.badge.magnifyingglass")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(TokenBarTheme.coral)
            VStack(alignment: .leading, spacing: 3) {
                Text("Largest footprint: \(item.name)")
                    .font(.system(size: 14, weight: .semibold, design: .serif))
                    .foregroundStyle(TokenBarTheme.text)
                Text("\(storageSize(item.bytes)) · \(share)% of mapped storage · \(item.fileCount) files")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(TokenBarTheme.secondary)
            }
            Spacer()
            Button("Reveal", action: reveal)
                .buttonStyle(.bordered)
        }
        .padding(14)
        .background(TokenBarTheme.panel)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(TokenBarTheme.coral.opacity(0.34), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
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

private enum ReportLibraryMode: String, CaseIterable, Identifiable {
    case collections = "Collections"
    case timeline = "Timeline"

    var id: String { rawValue }
}

private struct ProofView: View {
    @EnvironmentObject private var model: TokenBarModel
    @State private var selectedReportID: String?
    @State private var reportQuery = ""
    @State private var analysisDays = 7
    @State private var confirmingPublication = false
    @State private var libraryMode = ReportLibraryMode.collections
    @State private var expandedCollectionIDs = Set<String>()

    private var selectedReport: SavedBuilderReport? {
        model.savedReports.first(where: { $0.id == selectedReportID })
    }

    private var matchingReports: [SavedBuilderReport] {
        model.savedReports.filter { $0.matches(reportQuery) }
    }

    private var visibleReports: [SavedBuilderReport] {
        SavedReportLibrary.deduplicated(matchingReports)
    }

    private var reportCollections: [ReportIdentityCollection] {
        SavedReportLibrary.collections(from: matchingReports)
    }

    private var foldedReportCount: Int {
        max(0, matchingReports.count - visibleReports.count)
    }

    var body: some View {
        Group {
            if let report = selectedReport {
                reportDetail(report)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            } else {
                reportLibrary
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            }
        }
        .animation(.snappy(duration: 0.34), value: selectedReportID)
        .onChange(of: model.savedReports.map(\.id)) { _, reportIDs in
            if let selectedReportID, !reportIDs.contains(selectedReportID) {
                self.selectedReportID = nil
            }
        }
        .onChange(of: model.lastImportedReportID) { _, importedID in
            if let importedID {
                withAnimation(.snappy(duration: 0.34)) {
                    selectedReportID = importedID
                    reportQuery = ""
                }
            }
        }
        .confirmationDialog(
            "Create an unlisted link for this report?",
            isPresented: $confirmingPublication,
            titleVisibility: .visible
        ) {
            Button("Create unlisted link") {
                if let report = selectedReport {
                    model.publishReport(report)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Only generated identity fields, aggregate usage, selected scores, and a privacy receipt are uploaded. Raw prompts, transcripts, source code, local paths, credentials, and private files stay on this Mac.")
        }
    }

    private var reportLibrary: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageChrome(
                    eyebrow: "The Proof Archive",
                    title: "Every identity has editions.",
                    subtitle: "Browse the evidence-backed forms TokenBar has saved on this Mac, or add one another builder shared with you."
                ) {
                    HStack(spacing: 10) {
                        Picker("Analysis window", selection: $analysisDays) {
                            Text("Day").tag(1)
                            Text("Week").tag(7)
                            Text("Month").tag(30)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 166)
                        .disabled(model.isAnalyzing)

                        Button {
                            TokenBarSound.play(.analysisStart)
                            TokenBarHaptics.perform(.analysisStart)
                            model.refreshIdentity(days: analysisDays)
                        } label: {
                            Label(
                                model.isAnalyzing ? "Analyzing…" : "New report",
                                systemImage: model.isAnalyzing ? "ellipsis" : "sparkles"
                            )
                        }
                        .buttonStyle(TokenBarPrimaryActionStyle(tint: TokenBarTheme.amber))
                        .disabled(model.isAnalyzing)
                        .help("Analyze local Codex evidence and save a new report")
                    }
                }
                .frame(height: 108, alignment: .top)

                ReportFinderPanel(
                    query: $reportQuery,
                    resultCount: visibleReports.count,
                    isImporting: model.isImportingReport,
                    openOrImport: openOrImportReference,
                    paste: pasteReportReference,
                    copyCommand: model.copyClaimCommand
                )

                if visibleReports.isEmpty {
                    ReportLibraryEmptyState(hasQuery: !reportQuery.isEmpty)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            SectionLabel(text: reportQuery.isEmpty ? "Saved reports" : "Matches")
                            Spacer()
                            if reportQuery.isEmpty {
                                Picker("Browse reports", selection: $libraryMode) {
                                    ForEach(ReportLibraryMode.allCases) { mode in
                                        Text(mode.rawValue).tag(mode)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .labelsHidden()
                                .frame(width: 190)
                            }
                        }

                        HStack(spacing: 18) {
                            Label("\(visibleReports.count) editions", systemImage: "doc.on.doc")
                            Label("\(reportCollections.count) identities", systemImage: "person.text.rectangle")
                            if foldedReportCount > 0 {
                                Label("\(foldedReportCount) repeats folded", systemImage: "square.stack.3d.down.right")
                            }
                        }
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(TokenBarTheme.secondary)

                        if !reportQuery.isEmpty || libraryMode == .timeline {
                            reportGrid(visibleReports)
                        } else {
                            VStack(alignment: .leading, spacing: 26) {
                                ForEach(reportCollections) { collection in
                                    reportIdentityShelf(collection)
                                }
                            }
                        }
                    }
                }

                ReportPrivacyFooter(reportCount: model.savedReports.count)
            }
            .padding(30)
            .frame(maxWidth: 1120, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    private func reportGrid(_ reports: [SavedBuilderReport]) -> some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 255, maximum: 330), spacing: 14)],
            alignment: .center,
            spacing: 14
        ) {
            ForEach(reports) { report in
                reportButton(report)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func reportIdentityShelf(_ collection: ReportIdentityCollection) -> some View {
        let expanded = expandedCollectionIDs.contains(collection.id)
        let reports = expanded ? collection.reports : Array(collection.reports.prefix(3))
        let style = ReportVisualStyle(report: collection.latest)

        return VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 14) {
                ReportIdentitySeal(report: collection.latest, size: 58)

                VStack(alignment: .leading, spacing: 3) {
                    ReportDisplayTitle(text: collection.title, style: style, size: 19)
                        .foregroundStyle(TokenBarTheme.text)
                    Text(collection.latest.identityPatternLabel.uppercased())
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(style.primary)
                    Text("\(collection.reports.count) \(collection.reports.count == 1 ? "edition" : "editions") · latest \(collection.latest.generatedAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(TokenBarTheme.secondary)
                }

                Spacer()

                if collection.reports.count > 3 {
                    Button(expanded ? "Show latest" : "View all \(collection.reports.count)") {
                        withAnimation(.snappy(duration: 0.28)) {
                            if expanded {
                                expandedCollectionIDs.remove(collection.id)
                            } else {
                                expandedCollectionIDs.insert(collection.id)
                            }
                        }
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(style.primary)
                }
            }

            reportGrid(reports)
        }
        .overlay(alignment: .bottom) {
            Divider()
                .offset(y: 13)
        }
    }

    private func reportButton(_ report: SavedBuilderReport) -> some View {
        Button {
            TokenBarSound.play(.inspect)
            TokenBarHaptics.perform(.selection)
            selectedReportID = report.id
        } label: {
            ReportCollectionCard(report: report)
        }
        .buttonStyle(.plain)
    }

    private func reportDetail(_ report: SavedBuilderReport) -> some View {
        let style = ReportVisualStyle(report: report)
        return ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Button {
                        selectedReportID = nil
                    } label: {
                        Label("All reports", systemImage: "chevron.left")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(TokenBarTheme.text)

                    Spacer()

                    Text(report.generatedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(TokenBarTheme.secondary)
                }

                SavedReportDossier(
                    report: report,
                    accent: style.primary,
                    secondaryAccent: style.secondary,
                    isPublishing: model.isPublishingProof,
                    isExporting: model.isExportingProof,
                    openReport: {
                        model.open(report.reportURL ?? report.pdfURL ?? report.identityURL)
                    },
                    openPDF: { model.open(report.pdfURL) },
                    exportPortfolio: { model.exportProofPacket() },
                    copyToken: {
                        model.copy(report.token, confirmation: "Report ID copied")
                    },
                    createLink: { confirmingPublication = true },
                    copyLink: {
                        if let url = report.shareURL {
                            model.copy(url.absoluteString, confirmation: "Report link copied")
                        }
                    },
                    copyCaption: { model.copyShareCaption(report) },
                    shareLink: { model.shareReport(report) },
                    openLink: { model.open(report.shareURL) }
                )
            }
            .padding(30)
            .frame(maxWidth: 980, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    private func openOrImportReference() {
        let query = reportQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        if let exact = model.savedReports.first(where: { $0.matchesReference(query) }) {
            selectedReportID = exact.id
        } else if looksLikeReportReference(query) {
            model.importReportReference(query)
        } else if let firstMatch = visibleReports.first {
            selectedReportID = firstMatch.id
        } else {
            model.activityMessage = "No saved report matches \"\(query)\""
        }
    }

    private func looksLikeReportReference(_ value: String) -> Bool {
        value.localizedCaseInsensitiveContains("TBAR-")
            || value.contains("://")
            || value.hasSuffix(".identity.json")
            || value.hasPrefix("/")
            || value.hasPrefix("~")
    }

    private func pasteReportReference() {
        guard let pasted = NSPasteboard.general.string(forType: .string) else { return }
        reportQuery = pasted.trimmingCharacters(in: .whitespacesAndNewlines)
        if reportQuery.localizedCaseInsensitiveContains("TBAR-")
            || reportQuery.hasSuffix(".identity.json") {
            openOrImportReference()
        }
    }
}

private struct ReportCollectionCard: View {
    let report: SavedBuilderReport

    var body: some View {
        IdentityReportEditionCard(report: report)
    }
}

private struct ReportFinderPanel: View {
    @Binding var query: String
    let resultCount: Int
    let isImporting: Bool
    let openOrImport: () -> Void
    let paste: () -> Void
    let copyCommand: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(TokenBarTheme.secondary)
                TextField("Find a saved edition", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .onSubmit(openOrImport)
                if !query.isEmpty {
                    Text(resultCount > 0 ? "\(resultCount)" : "0")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(resultCount > 0 ? TokenBarTheme.cyan : TokenBarTheme.secondary)
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(TokenBarTheme.secondary)
                }
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 34)
            .background(TokenBarTheme.raised)
            .clipShape(RoundedRectangle(cornerRadius: 5))

            Menu {
                Button("Paste shared report", action: paste)
                Button("Copy terminal report command", action: copyCommand)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 15))
            }
            .menuStyle(.borderlessButton)
            .frame(width: 28)
            .help("Import or terminal options")

            Button(action: openOrImport) {
                Label(
                    isImporting ? "Adding…" : (resultCount > 0 ? "Open" : "Add"),
                    systemImage: isImporting ? "ellipsis" : "arrow.right"
                )
            }
            .buttonStyle(.borderedProminent)
            .tint(TokenBarTheme.cyan)
            .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isImporting)
        }
        .padding(9)
        .background(TokenBarTheme.panel)
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(TokenBarTheme.border, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

private struct ReportLibraryEmptyState: View {
    let hasQuery: Bool

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: hasQuery ? "magnifyingglass" : "books.vertical.fill")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(TokenBarTheme.amber)
            Text(hasQuery ? "No saved report matches that search." : "Your first report will appear here.")
                .font(.system(size: 20, weight: .semibold, design: .serif))
                .foregroundStyle(TokenBarTheme.text)
            Text(hasQuery
                 ? "Paste a TBAR link, token, or local .identity.json path to add it."
                 : "Choose Day, Week, or Month, then run a private local analysis.")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(TokenBarTheme.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 260)
        .background(TokenBarTheme.panel.opacity(0.58))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(TokenBarTheme.border, style: StrokeStyle(lineWidth: 1, dash: [6, 6]))
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct ReportPrivacyFooter: View {
    let reportCount: Int

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "lock.shield")
                .foregroundStyle(TokenBarTheme.green)
            Text("Saved locally. Sharing starts only after you create and review an unlisted link.")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(TokenBarTheme.secondary)
            Spacer()
            Text("\(reportCount) saved")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(TokenBarTheme.secondary)
        }
        .padding(.horizontal, 2)
    }
}

private struct ReportVisualStyle {
    let primary: Color
    let secondary: Color
    let typography: ReportTypographySignature

    var titleDesign: Font.Design {
        switch typography.design {
        case .standard: .default
        case .rounded: .rounded
        case .serif: .serif
        case .monospaced: .monospaced
        }
    }

    var titleWeight: Font.Weight {
        switch typography.weight {
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        case .heavy: .heavy
        case .black: .black
        }
    }

    var titleItalic: Bool { typography.italic }
    var titleTracking: CGFloat { CGFloat(typography.trackingTenths) / 10 }

    init(report: SavedBuilderReport) {
        typography = report.typographySignature
        switch report.identityFamily {
        case .commerce:
            primary = Color(red: 0.96, green: 0.56, blue: 0.30)
            secondary = Color(red: 0.94, green: 0.28, blue: 0.36)
        case .orchestration:
            primary = Color(red: 0.32, green: 0.78, blue: 0.94)
            secondary = Color(red: 0.46, green: 0.91, blue: 0.69)
        case .design:
            primary = Color(red: 0.96, green: 0.40, blue: 0.49)
            secondary = Color(red: 0.98, green: 0.72, blue: 0.34)
        case .research:
            primary = Color(red: 0.50, green: 0.69, blue: 0.98)
            secondary = Color(red: 0.47, green: 0.88, blue: 0.78)
        case .stress:
            primary = Color(red: 0.98, green: 0.38, blue: 0.36)
            secondary = Color(red: 0.98, green: 0.72, blue: 0.34)
        case .architecture:
            primary = Color(red: 0.64, green: 0.82, blue: 0.98)
            secondary = Color(red: 0.92, green: 0.93, blue: 0.96)
        case .privacy, .reliability:
            primary = TokenBarTheme.green
            secondary = TokenBarTheme.cyan
        case .velocity, .launch:
            primary = Color(red: 0.98, green: 0.70, blue: 0.28)
            secondary = Color(red: 0.98, green: 0.38, blue: 0.36)
        case .evidence, .portfolio:
            primary = Color(red: 0.78, green: 0.66, blue: 0.98)
            secondary = Color(red: 0.43, green: 0.82, blue: 0.96)
        case .exploration, .workflow, .integration:
            primary = Color(red: 0.43, green: 0.82, blue: 0.96)
            secondary = Color(red: 0.46, green: 0.91, blue: 0.69)
        case .strategy, .coaching:
            primary = Color(red: 0.98, green: 0.72, blue: 0.34)
            secondary = Color(red: 0.78, green: 0.66, blue: 0.98)
        case .general:
            primary = TokenBarTheme.accent(for: report.presentationTitle)
            secondary = TokenBarTheme.cyan
        }
    }
}

private struct ReportDisplayTitle: View {
    let text: String
    let style: ReportVisualStyle
    let size: CGFloat

    var body: some View {
        Group {
            if style.titleItalic {
                Text(text).italic()
            } else {
                Text(text)
            }
        }
        .font(.system(size: size, weight: style.titleWeight, design: style.titleDesign))
        .tracking(style.titleTracking)
    }
}

private struct ReportIdentitySeal: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let report: SavedBuilderReport
    let size: CGFloat
    @State private var active = false

    private var style: ReportVisualStyle { ReportVisualStyle(report: report) }
    private var scores: [Int] {
        Array(report.dimensions.sorted { $0.score > $1.score }.prefix(3).map(\.score))
    }

    var body: some View {
        ReportEmblemMark(
            report: report,
            style: style,
            scores: scores,
            compact: true,
            active: active
        )
        .frame(width: 116, height: 116)
        .scaleEffect(size / 116)
        .frame(width: size, height: size)
        .contentShape(Rectangle())
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 3.8).repeatForever(autoreverses: true)) {
                active = true
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(report.presentationTitle) identity mark")
    }
}

private struct ReportIdentityGlyph: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let report: SavedBuilderReport
    var compact = false
    @State private var active = false

    private var style: ReportVisualStyle { ReportVisualStyle(report: report) }
    private var strongestScores: [Int] {
        Array(report.dimensions.sorted { $0.score > $1.score }.prefix(3).map(\.score))
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(style.primary.opacity(0.07))
            Circle()
                .trim(from: 0.08, to: 0.76)
                .stroke(
                    AngularGradient(
                        colors: [style.primary, style.secondary, style.primary.opacity(0.24)],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: compact ? 2 : 3, lineCap: .round)
                )
                .rotationEffect(.degrees(active ? 360 : 0))

            ReportEmblemMark(
                report: report,
                style: style,
                scores: strongestScores,
                compact: compact,
                active: active
            )
        }
        .frame(width: compact ? 116 : 190, height: compact ? 116 : 190)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: compact ? 3.6 : 4.8).repeatForever(autoreverses: true)) {
                active = true
            }
        }
    }
}

private struct ReportEmblemMark: View {
    let report: SavedBuilderReport
    let style: ReportVisualStyle
    let scores: [Int]
    let compact: Bool
    let active: Bool

    private var markSize: CGFloat { compact ? 60 : 100 }
    private var iconSize: CGFloat { compact ? 23 : 38 }
    private var signature: Int { report.emblemSignature }
    private var scoreValues: [Int] {
        scores.isEmpty ? [72, 61, 48] : scores
    }

    var body: some View {
        ZStack {
            familyMotif
            signatureConstellation

            emblemPlate
                .frame(width: markSize, height: markSize)
                .shadow(color: style.primary.opacity(0.24), radius: compact ? 10 : 18)

            Image(systemName: report.symbolName)
                .font(.system(size: iconSize, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(style.primary)
                .scaleEffect(active ? 1.04 : 0.96)
        }
    }

    private var signatureConstellation: some View {
        let markerCount = 3 + (signature % 5)
        let arcCount = 1 + (signature % 3)
        let radius = markSize * (compact ? 0.82 : 0.86)

        return ZStack {
            ForEach(0..<arcCount, id: \.self) { index in
                let start = Double((signature * 13 + index * 19) % 70) / 100
                let length = 0.12 + Double((signature + index * 3) % 5) * 0.035
                Circle()
                    .trim(from: start, to: min(start + length, 0.98))
                    .stroke(
                        index == 0 ? style.primary.opacity(0.82) : style.secondary.opacity(0.48),
                        style: StrokeStyle(lineWidth: compact ? 1.5 : 2, lineCap: .round)
                    )
                    .frame(width: markSize * (1.48 + CGFloat(index) * 0.16))
                    .rotationEffect(.degrees(active ? 18 : -18))
            }

            ForEach(0..<markerCount, id: \.self) { index in
                let angle = Double((signature * 29 + index * (360 / markerCount)) % 360)
                Group {
                    if (signature + index).isMultiple(of: 3) {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(index == 0 ? style.primary : style.secondary.opacity(0.76))
                            .frame(width: compact ? 9 : 14, height: compact ? 3 : 4)
                    } else {
                        Circle()
                            .fill(index == 0 ? style.primary : style.secondary.opacity(0.76))
                            .frame(width: compact ? 4 : 6, height: compact ? 4 : 6)
                    }
                }
                .offset(y: -radius)
                .rotationEffect(.degrees(angle + (active ? 7 : -7)))
            }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var emblemPlate: some View {
        switch report.identityFamily {
        case .stress:
            RoundedRectangle(cornerRadius: compact ? 12 : 18)
                .fill(TokenBarTheme.panel.opacity(0.90))
                .overlay(RoundedRectangle(cornerRadius: compact ? 12 : 18).stroke(style.primary, lineWidth: 1))
                .rotationEffect(.degrees(45))
        case .design, .portfolio:
            Capsule()
                .fill(TokenBarTheme.panel.opacity(0.90))
                .overlay(Capsule().stroke(style.primary, lineWidth: 1))
        case .architecture, .commerce:
            RoundedRectangle(cornerRadius: compact ? 8 : 13)
                .fill(TokenBarTheme.panel.opacity(0.90))
                .overlay(RoundedRectangle(cornerRadius: compact ? 8 : 13).stroke(style.primary, lineWidth: 1))
        default:
            Circle()
                .fill(TokenBarTheme.panel.opacity(0.90))
                .overlay(Circle().stroke(style.primary, lineWidth: 1))
        }
    }

    @ViewBuilder
    private var familyMotif: some View {
        switch report.identityFamily {
        case .commerce:
            HStack(alignment: .bottom, spacing: compact ? 6 : 9) {
                ForEach(Array(scoreValues.prefix(3).enumerated()), id: \.offset) { index, score in
                    Capsule()
                        .fill(index == 2 ? style.primary : style.secondary.opacity(0.70))
                        .frame(
                            width: compact ? 7 : 11,
                            height: (compact ? 42 : 72) * CGFloat(max(score, 24)) / 100
                        )
                        .scaleEffect(y: active ? 1 : 0.72, anchor: .bottom)
                }
            }
            .offset(y: compact ? 24 : 40)
        case .orchestration:
            ForEach(0..<5, id: \.self) { index in
                Circle()
                    .fill(index == 0 ? style.primary : style.secondary)
                    .frame(width: compact ? 7 : 10, height: compact ? 7 : 10)
                    .offset(y: compact ? -47 : -78)
                    .rotationEffect(.degrees(Double(index) * 72 + (active ? 18 : -18)))
            }
        case .stress:
            HStack(spacing: compact ? 3 : 5) {
                ForEach(Array([28, 62, 94, 44, 78, 34, 58].enumerated()), id: \.offset) { index, height in
                    Capsule()
                        .fill(index == 2 ? style.primary : style.secondary.opacity(0.72))
                        .frame(width: compact ? 3 : 5, height: (compact ? 0.45 : 0.72) * CGFloat(height))
                        .scaleEffect(y: active ? 1 : 0.64)
                }
            }
        case .architecture:
            Image(systemName: "square.grid.3x3.square")
                .font(.system(size: compact ? 88 : 146, weight: .ultraLight))
                .foregroundStyle(style.primary.opacity(active ? 0.24 : 0.12))
        case .evidence, .portfolio:
            ForEach(0..<3, id: \.self) { index in
                RoundedRectangle(cornerRadius: compact ? 7 : 11)
                    .stroke(index == 0 ? style.primary : style.secondary.opacity(0.62), lineWidth: 1)
                    .frame(width: markSize * 1.18, height: markSize * 0.72)
                    .offset(x: CGFloat(index - 1) * (compact ? 8 : 13), y: CGFloat(index - 1) * (compact ? 6 : 10))
            }
        case .velocity, .launch:
            Image(systemName: "line.diagonal.arrow")
                .font(.system(size: compact ? 86 : 142, weight: .ultraLight))
                .foregroundStyle(style.primary.opacity(active ? 0.30 : 0.14))
                .offset(x: active ? 6 : -6, y: active ? -6 : 6)
        case .research:
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(index == 0 ? style.primary : style.secondary.opacity(0.58), lineWidth: 1)
                    .frame(width: markSize * CGFloat(1.25 - Double(index) * 0.18))
                    .rotation3DEffect(.degrees(index.isMultiple(of: 2) ? 62 : -62), axis: (x: 1, y: 0, z: 0))
                    .rotationEffect(.degrees(active ? Double(index * 14) : Double(index * -14)))
            }
        case .privacy, .reliability:
            Circle()
                .trim(from: 0.04, to: active ? 0.92 : 0.70)
                .stroke(style.primary.opacity(0.72), style: StrokeStyle(lineWidth: compact ? 6 : 9, lineCap: .round))
                .frame(width: markSize * 1.30, height: markSize * 1.30)
        case .design:
            ForEach(0..<3, id: \.self) { index in
                Capsule()
                    .stroke(index == 0 ? style.primary : style.secondary.opacity(0.60), lineWidth: 1)
                    .frame(width: markSize * 1.38, height: markSize * 0.62)
                    .rotationEffect(.degrees(Double(index * 60) + (active ? 8 : -8)))
            }
        default:
            Circle()
                .stroke(style.secondary.opacity(0.42), style: StrokeStyle(lineWidth: 1, dash: [3, 7]))
                .frame(width: markSize * 1.45, height: markSize * 1.45)
                .rotationEffect(.degrees(active ? 24 : -24))
        }
    }
}

private struct SavedReportDossier: View {
    let report: SavedBuilderReport
    let accent: Color
    let secondaryAccent: Color
    let isPublishing: Bool
    let isExporting: Bool
    let openReport: () -> Void
    let openPDF: () -> Void
    let exportPortfolio: () -> Void
    let copyToken: () -> Void
    let createLink: () -> Void
    let copyLink: () -> Void
    let copyCaption: () -> Void
    let shareLink: () -> Void
    let openLink: () -> Void
    @State private var showMeasurements = false

    private var evidenceStatements: [String] {
        report.signatureMoves.filter {
            !$0.lowercased().hasPrefix("projected ")
        }
    }

    var body: some View {
        let rank = BuilderIdentityRank.resolve(
            evidenceScore: report.evidenceScore,
            sessions: report.sessions
        )
        VStack(alignment: .leading, spacing: 18) {
            ZStack {
                TokenBarFluidField(
                    primary: accent,
                    secondary: secondaryAccent,
                    speed: 0.18,
                    intensity: 0.40,
                    mood: .goodNight
                )

                LinearGradient(
                    colors: [TokenBarTheme.panel.opacity(0.24), TokenBarTheme.panel.opacity(0.90)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                HStack(spacing: 32) {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 8) {
                            TokenBarPill(label: "Report", value: report.windowLabel, tint: accent)
                            TokenBarPill(label: "Stored", value: "On this Mac", tint: TokenBarTheme.green)
                            TokenBarPill(label: "Rank", value: rank.name, tint: secondaryAccent)
                        }

                        ReportDisplayTitle(text: report.presentationTitle, style: ReportVisualStyle(report: report), size: 45)
                            .foregroundStyle(TokenBarTheme.text)
                            .lineLimit(2)
                            .minimumScaleFactor(0.68)

                        Text(report.subtitle)
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(TokenBarTheme.text.opacity(0.84))
                            .lineSpacing(4)
                            .lineLimit(3)

                        Text([
                            report.identityPatternLabel,
                            report.workRhythmLabel,
                            report.operatingStanceLabel,
                        ].filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(accent)

                        HStack(spacing: 24) {
                            ReportMetric(value: "\(report.sessions)", label: "sessions")
                            ReportMetric(value: "\(report.activeDays)/30", label: "active days")
                            ReportMetric(value: "\(report.windowDays)d", label: "window")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    ReportIdentityGlyph(report: report)
                        .frame(width: 210)
                }
                .padding(30)
            }
            .frame(height: 340)
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(TokenBarTheme.border, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))

            if report.scrollStoryBeats.count > 1 {
                ReportScrollStory(
                    report: report,
                    primary: accent,
                    secondary: secondaryAccent
                )
            }

            ReportIdentityFormula(
                report: report,
                primary: accent,
                secondary: secondaryAccent
            )

            TokenBarPanel {
                DisclosureGroup(isExpanded: $showMeasurements) {
                    TokenBarPanel {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(evidenceStatements.enumerated()), id: \.offset) { index, statement in
                                ReportEvidenceRow(index: index + 1, statement: statement, accent: accent)
                                if index < evidenceStatements.count - 1 {
                                    Divider().overlay(TokenBarTheme.border)
                                }
                            }

                            if evidenceStatements.isEmpty {
                                Text("This older report does not contain a measurement ledger.")
                                    .font(.system(size: 12))
                                    .foregroundStyle(TokenBarTheme.secondary)
                                    .padding(.vertical, 8)
                            }
                        }
                    }
                    .padding(.top, 12)

                    HStack(spacing: 8) {
                        Image(systemName: "lock")
                            .foregroundStyle(TokenBarTheme.green)
                        Text("Counts and summaries only. Source code and full prompt text are not shown.")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(TokenBarTheme.secondary)
                    }
                    .padding(.top, 9)
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(accent.opacity(0.12))
                            Image(systemName: "tablecells")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(accent)
                        }
                        .frame(width: 34, height: 34)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Source measurements")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(TokenBarTheme.text)
                            Text("\(evidenceStatements.count) inspectable local summaries")
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundStyle(TokenBarTheme.secondary)
                        }

                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
            }
            .tint(accent)

            TokenBarPanel {
                VStack(alignment: .leading, spacing: 14) {
                    ReportShareState(report: report, accent: accent)

                    Divider().overlay(TokenBarTheme.border)

                    HStack(spacing: 10) {
                        Button(action: openReport) {
                            Label("Open full report", systemImage: "doc.text.magnifyingglass")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(accent)

                        if report.pdfURL != nil {
                            Button(action: openPDF) {
                                Label("Open PDF", systemImage: "doc.richtext")
                            }
                            .buttonStyle(.bordered)
                        }

                        Menu {
                            Button("Copy report ID", action: copyToken)
                            Button("Export report portfolio", action: exportPortfolio)
                                .disabled(isExporting)
                        } label: {
                            Image(systemName: "ellipsis")
                        }
                        .menuStyle(.borderlessButton)
                        .frame(width: 30)

                        Spacer()

                        if report.shareURL != nil {
                            Button(action: shareLink) {
                                Label("Share report", systemImage: "square.and.arrow.up")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(TokenBarTheme.green)

                            Menu {
                                Button("Copy link", action: copyLink)
                                Button("Copy social post", action: copyCaption)
                                Button("Open shared view", action: openLink)
                            } label: {
                                Label("More", systemImage: "ellipsis.circle")
                            }
                            .menuStyle(.borderlessButton)
                            .frame(width: 76)
                        } else {
                            Button(action: createLink) {
                                Label(
                                    isPublishing ? "Creating…" : "Create unlisted link",
                                    systemImage: isPublishing ? "ellipsis" : "link.badge.plus"
                                )
                            }
                            .buttonStyle(.bordered)
                            .disabled(isPublishing)
                            .help("Create a safe generated profile that only people with the link can open")
                        }
                    }
                }
            }
        }
    }
}

private struct ReportScrollStory: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let report: SavedBuilderReport
    let primary: Color
    let secondary: Color

    private let viewportHeight: CGFloat = 430
    private let beatStride: CGFloat = 310
    private var beats: [ReportStoryBeat] { report.scrollStoryBeats }
    private var totalHeight: CGFloat {
        viewportHeight + (CGFloat(max(0, beats.count - 1)) * beatStride)
    }

    var body: some View {
        GeometryReader { proxy in
            let frame = proxy.frame(in: .global)
            let maximumOffset = max(0, totalHeight - viewportHeight)
            let pinnedOffset = min(max(24 - frame.minY, 0), maximumOffset)
            let rawProgress = beatStride > 0 ? pinnedOffset / beatStride : 0
            let progress = reduceMotion ? rawProgress.rounded() : rawProgress
            let activeIndex = min(max(Int(rawProgress.rounded()), 0), max(0, beats.count - 1))

            ReportStoryStage(
                report: report,
                beats: beats,
                progress: progress,
                activeIndex: activeIndex,
                primary: primary,
                secondary: secondary
            )
            .frame(height: viewportHeight)
            .offset(y: pinnedOffset)
        }
        .frame(height: totalHeight)
    }
}

private struct ReportStoryStage: View {
    let report: SavedBuilderReport
    let beats: [ReportStoryBeat]
    let progress: CGFloat
    let activeIndex: Int
    let primary: Color
    let secondary: Color

    var body: some View {
        ZStack {
            TokenBarFluidField(
                primary: primary,
                secondary: secondary,
                speed: 0.10,
                intensity: 0.34,
                mood: .goodNight
            )

            LinearGradient(
                colors: [
                    TokenBarTheme.nightInk.opacity(0.52),
                    TokenBarTheme.panel.opacity(0.92),
                    TokenBarTheme.nightInk.opacity(0.72),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 0) {
                HStack {
                    Text("REPORT STORY")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(TokenBarTheme.text.opacity(0.72))

                    Spacer()

                    Text("\(activeIndex + 1) / \(beats.count)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(primary)
                }
                .padding(.horizontal, 26)
                .padding(.top, 22)

                ZStack {
                    ForEach(Array(beats.enumerated()), id: \.element.id) { index, beat in
                        let distance = abs(progress - CGFloat(index))

                        ReportStoryBeatView(
                            report: report,
                            beat: beat,
                            primary: primary,
                            secondary: secondary
                        )
                        .opacity(max(0, 1 - (distance * 1.25)))
                        .offset(y: (CGFloat(index) - progress) * 54)
                        .scaleEffect(1 - (min(distance, 1) * 0.035))
                        .accessibilityHidden(distance > 0.55)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                HStack(spacing: 6) {
                    ForEach(beats.indices, id: \.self) { index in
                        Capsule()
                            .fill(index == activeIndex ? primary : TokenBarTheme.text.opacity(0.18))
                            .frame(width: index == activeIndex ? 26 : 7, height: 4)
                    }
                }
                .padding(.bottom, 20)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(primary.opacity(0.26), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Report story, chapter \(activeIndex + 1) of \(beats.count)")
    }
}

private struct ReportStoryBeatView: View {
    let report: SavedBuilderReport
    let beat: ReportStoryBeat
    let primary: Color
    let secondary: Color

    private var isIdentity: Bool { beat.kind == "identity" }

    var body: some View {
        HStack(spacing: 34) {
            VStack(alignment: .leading, spacing: 12) {
                Text(beat.eyebrow.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(secondary)

                Text(beat.title)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(TokenBarTheme.text.opacity(0.76))

                if isIdentity {
                    ReportDisplayTitle(
                        text: beat.value,
                        style: ReportVisualStyle(report: report),
                        size: 48
                    )
                    .foregroundStyle(TokenBarTheme.text)
                    .lineLimit(2)
                    .minimumScaleFactor(0.68)
                } else {
                    Text(beat.value)
                        .font(.system(size: 70, weight: .black, design: .serif))
                        .italic()
                        .foregroundStyle(primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.62)
                }

                Text(beat.copy)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(TokenBarTheme.text.opacity(0.80))
                    .lineSpacing(4)
                    .lineLimit(3)

                Text("\(report.sessions) local sessions · \(report.windowLabel.lowercased())")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(TokenBarTheme.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Group {
                if isIdentity {
                    ReportIdentitySeal(report: report, size: 142)
                } else {
                    ZStack {
                        Circle()
                            .fill(TokenBarTheme.raised.opacity(0.86))
                        Circle()
                            .stroke(
                                AngularGradient(
                                    colors: [primary, secondary, primary.opacity(0.24)],
                                    center: .center
                                ),
                                lineWidth: 2
                            )
                        Image(systemName: beat.symbolName)
                            .font(.system(size: 42, weight: .semibold))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(primary)
                    }
                    .frame(width: 126, height: 126)
                }
            }
            .frame(width: 152)
        }
        .padding(.horizontal, 32)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(beat.eyebrow). \(beat.title). \(beat.value). \(beat.copy)")
    }
}

private struct ReportFactGallery: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let facts: [BuilderFact]
    let primary: Color
    let secondary: Color
    @State private var revealed = false

    private let columns = [
        GridItem(.adaptive(minimum: 175, maximum: 230), spacing: 10),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .firstTextBaseline) {
                SectionLabel(text: "What stood out")
                Spacer()
                Text("\(facts.count) signals from this edition")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(TokenBarTheme.secondary)
            }

            LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                ForEach(Array(facts.enumerated()), id: \.element.id) { index, fact in
                    ReportFactCard(
                        fact: fact,
                        index: index,
                        tint: index.isMultiple(of: 2) ? primary : secondary
                    )
                    .opacity(revealed ? 1 : 0.18)
                    .offset(y: revealed || reduceMotion ? 0 : 12)
                    .animation(
                        reduceMotion
                            ? nil
                            : .spring(response: 0.62, dampingFraction: 0.84)
                                .delay(Double(index) * 0.07),
                        value: revealed
                    )
                }
            }
        }
        .onAppear {
            revealed = true
        }
    }
}

private struct ReportFactCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let fact: BuilderFact
    let index: Int
    let tint: Color
    @State private var hovered = false

    private var symbol: String {
        let label = fact.label.lowercased()
        if label.contains("identity") { return "square.grid.3x3.fill" }
        if label.contains("command") { return "cursorarrow.rays" }
        if label.contains("short") { return "bolt.fill" }
        if label.contains("question") { return "questionmark.bubble.fill" }
        if label.contains("courtesy") { return "hand.wave.fill" }
        if label.contains("typo") { return "scribble.variable" }
        return "chart.xyaxis.line"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Text(String(format: "%02d", index + 1))
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(tint)
                Spacer()
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
            }

            Text(fact.value)
                .font(.system(size: 29, weight: .bold, design: .serif))
                .foregroundStyle(TokenBarTheme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.70)

            Text(fact.label.uppercased())
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(tint)

            Text(fact.copy)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(TokenBarTheme.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [tint.opacity(hovered ? 0.15 : 0.09), TokenBarTheme.panel],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(hovered ? tint.opacity(0.72) : TokenBarTheme.border, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .scaleEffect(hovered && !reduceMotion ? 1.012 : 1)
        .animation(reduceMotion ? nil : .snappy(duration: 0.22), value: hovered)
        .onHover { hovered = $0 }
        .help(fact.copy)
    }
}

private struct ReportShareState: View {
    let report: SavedBuilderReport
    let accent: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: report.shareURL == nil ? "lock.fill" : "link.circle.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(report.shareURL == nil ? TokenBarTheme.secondary : TokenBarTheme.green)

            VStack(alignment: .leading, spacing: 2) {
                Text(report.shareURL == nil ? "Sharing off" : "Unlisted link active")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(TokenBarTheme.text)
                Text(report.shareURL == nil
                    ? "This report exists only on this Mac until you create a link."
                    : "Only the generated report is shared. Local sessions and source code stay on this Mac.")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(TokenBarTheme.secondary)
            }

            Spacer()

            if let host = report.shareURL?.host {
                Text(host)
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(accent)
            }
        }
    }
}

private struct ReportIdentityFormula: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let report: SavedBuilderReport
    let primary: Color
    let secondary: Color
    @State private var selectedComponentID: String?
    @State private var driversRevealed = false

    private var rationale: ReportTitleRationale { report.displayTitleRationale }
    private var components: [ReportTitleComponent] { Array(rationale.components.prefix(3)) }
    private var selectedComponent: ReportTitleComponent? {
        components.first { $0.id == selectedComponentID } ?? components.first
    }

    var body: some View {
        TokenBarPanel {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        SectionLabel(text: "Why this title")
                        Text("Tap a signal to see what it contributed.")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(TokenBarTheme.secondary)
                    }
                    Spacer()
                    Text("BUILT FROM THIS REPORT")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(TokenBarTheme.secondary)
                }

                HStack(spacing: 8) {
                    ForEach(Array(components.enumerated()), id: \.element.id) { index, component in
                        Button {
                            TokenBarHaptics.perform(.selection)
                            withAnimation(.snappy(duration: 0.26)) {
                                selectedComponentID = component.id
                            }
                        } label: {
                            ReportFormulaNode(
                                component: component,
                                tint: index == 1 ? primary : secondary,
                                isSelected: selectedComponent?.id == component.id
                            )
                        }
                        .buttonStyle(.plain)
                        .help(component.reason)

                        if index < components.count - 1 {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(TokenBarTheme.secondary)
                        }
                    }

                    Image(systemName: "equal")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(TokenBarTheme.secondary)

                    HStack(spacing: 8) {
                        Image(systemName: report.symbolName)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(primary)
                        ReportDisplayTitle(
                            text: report.presentationTitle,
                            style: ReportVisualStyle(report: report),
                            size: 18
                        )
                        .foregroundStyle(TokenBarTheme.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 58)
                    .background(primary.opacity(0.10))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(primary.opacity(0.42), lineWidth: 1)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                if let selectedComponent {
                    Divider().overlay(TokenBarTheme.border)

                    HStack(spacing: 10) {
                        Image(systemName: "arrow.turn.down.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(primary)
                        Text(selectedComponent.reason)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(TokenBarTheme.text)
                            .lineLimit(2)
                        Spacer(minLength: 0)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .id(selectedComponent.id)
                }

                if !rationale.drivers.isEmpty {
                    Divider().overlay(TokenBarTheme.border)
                    ReportDriverConstellation(
                        drivers: Array(rationale.drivers.prefix(6)),
                        primary: primary,
                        secondary: secondary,
                        revealed: driversRevealed
                    )
                }
            }
        }
        .onAppear {
            selectedComponentID = components.first?.id
            if reduceMotion {
                driversRevealed = true
            } else {
                withAnimation(.spring(response: 0.72, dampingFraction: 0.82).delay(0.12)) {
                    driversRevealed = true
                }
            }
        }
        .task(id: report.id) {
            guard !reduceMotion, components.count > 1 else { return }
            for component in components.dropFirst() {
                try? await Task.sleep(nanoseconds: 1_150_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    withAnimation(.snappy(duration: 0.32)) {
                        selectedComponentID = component.id
                    }
                }
            }
        }
    }
}

private struct ReportFormulaNode: View {
    let component: ReportTitleComponent
    let tint: Color
    let isSelected: Bool

    private var icon: String {
        switch component.kind.lowercased() {
        case let value where value.contains("archetype"): "person.crop.square.filled.and.at.rectangle"
        case let value where value.contains("modifier"): "slider.horizontal.3"
        case let value where value.contains("stance"): "figure.stand"
        default: "sparkle"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(tint)
                Text(component.kind.uppercased())
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundStyle(TokenBarTheme.secondary)
            }
            Text(component.name)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(TokenBarTheme.text)
                .lineLimit(2)
            if let probability = component.probability {
                Text("\(probability, specifier: "%.0f")% signal weight")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(tint)
            }
        }
        .padding(10)
        .frame(maxWidth: 150, minHeight: 58, alignment: .leading)
        .background(isSelected ? tint.opacity(0.13) : TokenBarTheme.raised)
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? tint.opacity(0.72) : Color.clear, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .scaleEffect(isSelected ? 1.018 : 1)
    }
}

private struct ReportDriverConstellation: View {
    let drivers: [ReportTraitDriver]
    let primary: Color
    let secondary: Color
    let revealed: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            Text("MEASURED\nDRIVERS")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(TokenBarTheme.secondary)
                .lineSpacing(3)
                .frame(width: 66, alignment: .leading)

            ForEach(Array(drivers.enumerated()), id: \.element.id) { index, driver in
                VStack(spacing: 6) {
                    Text("\(driver.score)")
                        .font(.system(size: index == 0 ? 18 : 13, weight: .bold, design: .rounded))
                        .foregroundStyle(index == 0 ? primary : secondary)
                    Capsule()
                        .fill(index == 0 ? primary : secondary.opacity(0.68))
                        .frame(
                            width: 9,
                            height: revealed ? 14 + 46 * CGFloat(max(driver.score, 10)) / 100 : 8
                        )
                    Text(driver.name)
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(TokenBarTheme.text.opacity(0.78))
                        .lineLimit(1)
                        .minimumScaleFactor(0.64)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ReportMetric: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(TokenBarTheme.text)
                .lineLimit(1)
            Text(label.uppercased())
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(TokenBarTheme.secondary)
        }
    }
}

private struct ReportEvidenceRow: View {
    let index: Int
    let statement: String
    let accent: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(String(format: "%02d", index))
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(accent)
                .frame(width: 24, alignment: .leading)
            Text(statement)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(TokenBarTheme.text)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 11)
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
