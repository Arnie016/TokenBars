import AppKit
import SwiftUI

@main
struct TokenBarMacApp: App {
    @NSApplicationDelegateAdaptor(TokenBarAppDelegate.self) private var appDelegate
    @StateObject private var model = TokenBarModel.shared

    var body: some Scene {
        MenuBarExtra("TokenBar", systemImage: "circle.hexagongrid.fill") {
            TokenBarMenuPopover()
                .environmentObject(model)
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class TokenBarAppDelegate: NSObject, NSApplicationDelegate {
    static weak var shared: TokenBarAppDelegate?
    private var mainWindow: NSWindow?

    override init() {
        super.init()
        Self.shared = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        DispatchQueue.main.async {
            self.openMainWindow()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openMainWindow()
        return true
    }

    func openMainWindow() {
        if mainWindow == nil {
            let root = TokenBarRootView()
                .environmentObject(TokenBarModel.shared)
                .frame(minWidth: 980, minHeight: 680)
                .preferredColorScheme(.dark)
            let hostingView = NSHostingView(rootView: root)
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 1180, height: 790),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = "TokenBar"
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.toolbarStyle = .unifiedCompact
            window.backgroundColor = NSColor(red: 0.075, green: 0.078, blue: 0.082, alpha: 1)
            window.minSize = NSSize(width: 980, height: 680)
            window.isReleasedWhenClosed = false
            window.contentView = hostingView
            window.center()
            window.setFrameAutosaveName("TokenBarMainWindow")
            mainWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        mainWindow?.makeKeyAndOrderFront(nil)
        mainWindow?.orderFrontRegardless()
    }
}

private enum MenuBarStorySurface: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case forecast = "Forecast"
    case budget = "Budget"
    case cost = "Costs"
    case playbooks = "Playbooks"
    case compare = "Compare"
    case system = "System"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .overview: "chart.pie"
        case .forecast: "waveform.path.ecg"
        case .budget: "gauge.with.dots.needle.67percent"
        case .cost: "creditcard"
        case .playbooks: "text.book.closed"
        case .compare: "point.3.connected.trianglepath.dotted"
        case .system: "memorychip"
        }
    }
}

private struct TokenBarMenuPopover: View {
    @EnvironmentObject private var model: TokenBarModel
    @State private var surface: MenuBarStorySurface = .overview
    @State private var tokenWindow: TokenWindowScope = .today

    private var providerRows: [ProviderSnapshot] {
        ProviderSnapshot.defaults(model: model)
    }

    private var selectedTokenValue: String {
        switch tokenWindow {
        case .today: model.profile.usage.today
        case .week: model.profile.usage.last7
        case .month: model.profile.usage.last30
        case .year: TokenFormatter.compact(model.profile.usage.days.reduce(Int64(0)) { $0 + $1.tokens })
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 16) {
                MenuBarHeader(
                    title: model.profile.displayTitle,
                    subtitle: AccountLabel.current,
                    tokenValue: selectedTokenValue,
                    tokenScope: $tokenWindow
                )

                MenuBarSurfaceTabs(selection: $surface)
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 12)

            Divider()
                .overlay(TokenBarTheme.border)

            ScrollView {
                Group {
                    switch surface {
                    case .overview:
                        MenuOverviewSurface(providerRows: providerRows, usage: model.profile.usage)
                    case .forecast:
                        MenuForecastSurface(days: model.profile.usage.days)
                    case .budget:
                        MenuBudgetSurface(usage: model.profile.usage)
                    case .cost:
                        MenuCostSurface(
                            costUsage: model.costUsage,
                            isLoading: model.isLoadingCosts,
                            refresh: {
                                model.refreshUsageCosts()
                            },
                            copyCommand: { command in
                                model.copy(command, confirmation: "Cost passport command copied")
                            }
                        )
                    case .playbooks:
                        MenuPlaybooksSurface(
                            copyCommand: { command in
                                model.copy(command, confirmation: "Command copied")
                            },
                            copyPlaybookJSON: {
                                model.copyPlaybookCatalogJSON()
                            },
                            openPlaybooks: {
                                model.open(URL(string: "https://www.tokenbar.site/playbooks"))
                            },
                            openCatalog: {
                                model.open(URL(string: "https://www.tokenbar.site/prompt-playbooks.md"))
                            },
                            copyPlaybook: { playbook in
                                model.copy(playbook.prompt, confirmation: "\(playbook.title) copied")
                            }
                        )
                    case .compare:
                        MenuComparisonSurface(usage: model.profile.usage) {
                            model.copy("tokenbar comparison-lens json", confirmation: "Comparison command copied")
                        }
                    case .system:
                        MenuSystemSurface()
                    }
                }
                .padding(18)
            }

            Divider()
                .overlay(TokenBarTheme.border)

            MenuBarLaunchBridge(
                openApp: {
                    TokenBarAppDelegate.shared?.openMainWindow()
                },
                analyze: {
                    model.refreshIdentity()
                    TokenBarAppDelegate.shared?.openMainWindow()
                },
                downloadMacApp: {
                    model.open(URL(string: "https://www.tokenbar.site/#download"))
                },
                openPlaybooks: {
                    model.open(URL(string: "https://www.tokenbar.site/playbooks"))
                },
                copyProofPacket: {
                    model.copy("tokenbar proof-packet json", confirmation: "Proof packet command copied")
                },
                refresh: {
                    model.refreshUsageCosts()
                },
                quit: {
                    NSApp.terminate(nil)
                }
            )
            .padding(14)
        }
        .frame(width: 560, height: 680)
        .background(MenuBarBackground())
        .preferredColorScheme(.dark)
    }
}

private enum TokenWindowScope: String, CaseIterable, Identifiable {
    case today = "Today"
    case week = "Week"
    case month = "Month"
    case year = "All"

    var id: String { rawValue }
}

private struct MenuBarHeader: View {
    let title: String
    let subtitle: String
    let tokenValue: String
    @Binding var tokenScope: TokenWindowScope

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(TokenBarTheme.indigo.opacity(0.22))
                Image(systemName: "circle.hexagongrid.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(TokenBarTheme.cyan)
            }
            .frame(width: 58, height: 58)

            VStack(alignment: .leading, spacing: 5) {
                Text("TokenBar")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(TokenBarTheme.text)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(TokenBarTheme.secondary)
                    .lineLimit(1)
                Label(subtitle, systemImage: "person.crop.circle.badge.checkmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(TokenBarTheme.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                Button {
                    tokenScope = tokenScope.next
                } label: {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(tokenValue)
                            .font(.system(size: 30, weight: .heavy, design: .rounded))
                            .foregroundStyle(TokenBarTheme.text)
                            .monospacedDigit()
                        Text("\(tokenScope.rawValue.uppercased()) TOKENS")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(TokenBarTheme.secondary)
                    }
                }
                .buttonStyle(.plain)
                .help("Cycle token window")

                HStack(spacing: 5) {
                    Circle()
                        .fill(TokenBarTheme.green)
                        .frame(width: 6, height: 6)
                    Text("Local evidence")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(TokenBarTheme.secondary)
                }
            }
        }
    }
}

private extension TokenWindowScope {
    var next: TokenWindowScope {
        let values = Self.allCases
        guard let index = values.firstIndex(of: self) else { return .today }
        return values[(index + 1) % values.count]
    }
}

private struct MenuBarSurfaceTabs: View {
    @Binding var selection: MenuBarStorySurface

    var body: some View {
        HStack(spacing: 8) {
            ForEach(MenuBarStorySurface.allCases) { item in
                Button {
                    withAnimation(.easeOut(duration: 0.18)) {
                        selection = item
                    }
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: item.icon)
                            .font(.system(size: 15, weight: .semibold))
                        Text(item.rawValue)
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(selection == item ? TokenBarTheme.text : TokenBarTheme.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(selection == item ? TokenBarTheme.raised : Color.clear)
                    }
                    .overlay(alignment: .bottom) {
                        Capsule()
                            .fill(selection == item ? TokenBarTheme.amber : Color.clear)
                            .frame(width: 36, height: 3)
                            .offset(y: 4)
                    }
                }
                .buttonStyle(.plain)
                .help(item.rawValue)
            }
        }
    }
}

private struct MenuBarLaunchBridge: View {
    let openApp: () -> Void
    let analyze: () -> Void
    let downloadMacApp: () -> Void
    let openPlaybooks: () -> Void
    let copyProofPacket: () -> Void
    let refresh: () -> Void
    let quit: () -> Void
    @State private var relaySurface = MenuBarRelaySurface.menu

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(TokenBarTheme.cyan.opacity(0.18))
                    Image(systemName: "menubar.rectangle")
                        .foregroundStyle(TokenBarTheme.cyan)
                }
                .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Menu bar now. Full Mac app when you want reports.")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(TokenBarTheme.text)
                        .lineLimit(1)
                    Text("Free tracking stays here. Pro playbooks, reports, and comparison proofs open in the larger surface.")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(TokenBarTheme.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)
            }

            MenuBarSurfaceRelay(selection: $relaySurface)

            HStack(spacing: 8) {
                Button {
                    openApp()
                } label: {
                    Label("Open App", systemImage: "macwindow")
                }
                Button {
                    analyze()
                } label: {
                    Label("Analyze", systemImage: "sparkles")
                }
                Button {
                    downloadMacApp()
                } label: {
                    Label("Download Mac app", systemImage: "arrow.down.circle")
                }
                Button {
                    openPlaybooks()
                } label: {
                    Label("Playbooks", systemImage: "text.book.closed")
                }
                Button {
                    copyProofPacket()
                } label: {
                    Label("Proof packet", systemImage: "checkmark.seal")
                }
                Button {
                    refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh TokenBar")
                Spacer(minLength: 0)
                Button {
                    quit()
                } label: {
                    Image(systemName: "power")
                }
                .help("Quit TokenBar")
            }
            .buttonStyle(.bordered)
            .font(.system(size: 11, weight: .bold))
        }
        .padding(12)
        .background(TokenBarTheme.panel.opacity(0.68), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(TokenBarTheme.border))
    }
}

private enum MenuBarRelaySurface: String, CaseIterable, Identifiable {
    case cli = "CLI"
    case menu = "Menu bar"
    case companion = "Companion"
    case studio = "Mac studio"
    case pro = "Pro"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cli: "CLI evidence line"
        case .menu: "Menu-bar cockpit"
        case .companion: "Browser context rail"
        case .studio: "Mac studio archive"
        case .pro: "Pro proof market"
        }
    }

    var command: String {
        switch self {
        case .cli: "tokenbar usage"
        case .menu: "tokenbar status"
        case .companion: "tokenbar api"
        case .studio: "tokenbar proof-packet"
        case .pro: "tokenbar playbooks"
        }
    }

    var tier: String {
        switch self {
        case .cli, .menu: "Free"
        case .companion: "Free preview"
        case .studio: "Free app"
        case .pro: "Pro"
        }
    }

    var gate: String {
        switch self {
        case .cli: "Local read only"
        case .menu: "No provider sign-in"
        case .companion: "127.0.0.1 only"
        case .studio: "Review before share"
        case .pro: "No auto-billing"
        }
    }

    var value: String {
        switch self {
        case .cli:
            "Scriptable usage, cost passport, reminders, playbooks, launch kit, and local JSON."
        case .menu:
            "Active account, measured providers, token windows, budget pressure, and the next suggested action."
        case .companion:
            "Budget, reminders, memory pressure, and prompt playbooks beside Codex, GitHub, Product Hunt, and provider pages."
        case .studio:
            "Story, Timeline, Threads, Profile, Report, Storage, and proof packets from aggregate evidence."
        case .pro:
            "Paid prompt playbooks, public proof cards, cohort comparison, and premium reports after account review."
        }
    }

    var tint: Color {
        switch self {
        case .cli: TokenBarTheme.ivory
        case .menu: TokenBarTheme.cyan
        case .companion: TokenBarTheme.indigo
        case .studio: TokenBarTheme.amber
        case .pro: TokenBarTheme.coral
        }
    }
}

private struct MenuBarSurfaceRelay: View {
    @Binding var selection: MenuBarRelaySurface

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("SURFACE RELAY")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(selection.tint)
                    Text(selection.title)
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(TokenBarTheme.text)
                }
                Spacer(minLength: 8)
                Text(selection.tier)
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(selection.tint)
                    .padding(.horizontal, 8)
                    .frame(height: 22)
                    .background(selection.tint.opacity(0.14), in: Capsule())
            }

            Text(selection.value)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(TokenBarTheme.secondary)
                .lineLimit(2)

            HStack(spacing: 7) {
                Text(selection.command)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(selection.tint)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 8)
                Text(selection.gate)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(TokenBarTheme.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(TokenBarTheme.canvas.opacity(0.42), in: RoundedRectangle(cornerRadius: 7))

            HStack(spacing: 5) {
                ForEach(MenuBarRelaySurface.allCases) { surface in
                    Button {
                        withAnimation(.easeOut(duration: 0.18)) {
                            selection = surface
                        }
                    } label: {
                        Text(surface.rawValue)
                            .font(.system(size: 9, weight: .black))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .frame(maxWidth: .infinity)
                            .frame(height: 24)
                            .foregroundStyle(selection == surface ? TokenBarTheme.canvas : TokenBarTheme.secondary)
                            .background(selection == surface ? surface.tint : TokenBarTheme.raised.opacity(0.58), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("\(surface.title) · \(surface.gate)")
                }
            }
        }
        .padding(10)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(TokenBarTheme.raised.opacity(0.60))
                LinearGradient(
                    colors: [selection.tint.opacity(0.18), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        )
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(selection.tint.opacity(0.28)))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Surface relay, \(selection.title), \(selection.tier), \(selection.gate), command \(selection.command)")
    }
}

private struct ProviderSnapshot: Identifiable {
    let id: String
    let title: String
    let detail: String
    let accountLabel: String
    let sourceLabel: String
    let tokens: Int64
    let tint: Color
    let isConnected: Bool
    let isMeasured: Bool

    @MainActor
    static func defaults(model: TokenBarModel) -> [ProviderSnapshot] {
        let days = model.profile.usage.days
        let codex = days.reduce(Int64(0)) { $0 + $1.tokens }
        let localAccount = AccountLabel.current
        return [
            ProviderSnapshot(
                id: "codex",
                title: "Codex",
                detail: days.isEmpty ? "Run analysis to measure" : "Measured local sessions",
                accountLabel: localAccount,
                sourceLabel: days.isEmpty ? "Local scan pending" : "Codex local evidence",
                tokens: codex,
                tint: TokenBarTheme.cyan,
                isConnected: !days.isEmpty,
                isMeasured: !days.isEmpty
            ),
            ProviderSnapshot(id: "claude", title: "Claude", detail: "Connector pending", accountLabel: "No account connected", sourceLabel: "Needs local connector", tokens: 0, tint: TokenBarTheme.amber, isConnected: false, isMeasured: false),
            ProviderSnapshot(id: "cursor", title: "Cursor", detail: "Adapter pending", accountLabel: "No account connected", sourceLabel: "Needs local adapter", tokens: 0, tint: TokenBarTheme.indigo, isConnected: false, isMeasured: false),
            ProviderSnapshot(id: "antigravity", title: "Antigravity", detail: "Preview lane", accountLabel: "Preview only", sourceLabel: "Not measured yet", tokens: 0, tint: TokenBarTheme.ivory, isConnected: false, isMeasured: false),
            ProviderSnapshot(id: "opencode", title: "OpenCode", detail: "Open-source IDE lane", accountLabel: "No workspace linked", sourceLabel: "Awaiting usage source", tokens: 0, tint: TokenBarTheme.coral, isConnected: false, isMeasured: false),
        ]
    }
}

private struct MenuOverviewSurface: View {
    let providerRows: [ProviderSnapshot]
    let usage: UsageSnapshot

    private var totalTokens: Int64 {
        max(1, measuredRows.reduce(Int64(0)) { $0 + $1.tokens })
    }

    private var measuredRows: [ProviderSnapshot] {
        providerRows.filter { $0.isMeasured && $0.tokens > 0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            MenuSectionHeader("Usage composition", subtitle: "Measured usage stays separate from connector setup.")
            HStack(spacing: 8) {
                Label(AccountLabel.current, systemImage: "person.crop.circle")
                Spacer()
                Text("Account shown before usage")
            }
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(TokenBarTheme.secondary)
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(TokenBarTheme.raised.opacity(0.58))
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(TokenBarTheme.border, lineWidth: 1))

            HStack(alignment: .center, spacing: 18) {
                LiquidDonut(rows: measuredRows)
                    .frame(width: 178, height: 178)
                VStack(spacing: 10) {
                    ForEach(providerRows) { provider in
                        ProviderRow(provider: provider, total: totalTokens)
                    }
                    Button {
                        TokenBarAppDelegate.shared?.openMainWindow()
                    } label: {
                        Label("Add provider", systemImage: "plus.circle")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                    .help("Add another IDE or coding agent")
                }
            }

            HStack(spacing: 10) {
                MenuMetricTile(value: "\(usage.sessions)", label: "sessions", tint: TokenBarTheme.cyan)
                MenuMetricTile(value: "\(usage.activeDays)", label: "active days", tint: TokenBarTheme.amber)
                MenuMetricTile(value: usage.model, label: "top model", tint: TokenBarTheme.indigo)
            }
        }
    }
}

private struct LiquidDonut: View {
    let rows: [ProviderSnapshot]

    private var total: Int64 {
        max(1, rows.reduce(Int64(0)) { $0 + $1.tokens })
    }

    var body: some View {
        ZStack {
            Canvas { context, size in
                let side = min(size.width, size.height)
                let rect = CGRect(
                    x: (size.width - side) / 2 + 12,
                    y: (size.height - side) / 2 + 12,
                    width: side - 24,
                    height: side - 24
                )
                var start = Angle.degrees(-90)
                for row in rows {
                    let degrees = max(4, (Double(row.tokens) / Double(total)) * 360)
                    let end = start + Angle.degrees(degrees)
                    var path = Path()
                    path.addArc(center: CGPoint(x: rect.midX, y: rect.midY), radius: rect.width / 2, startAngle: start, endAngle: end, clockwise: false)
                    context.stroke(path, with: .color(row.tint.opacity(0.86)), style: StrokeStyle(lineWidth: 24, lineCap: .round))
                    start = end + Angle.degrees(3)
                }
            }
            Circle()
                .stroke(rows.isEmpty ? TokenBarTheme.secondary.opacity(0.28) : TokenBarTheme.border, lineWidth: 1)
                .padding(24)
            VStack(spacing: 4) {
                Text(rows.isEmpty ? "--" : TokenFormatter.compact(total))
                    .font(.system(size: 27, weight: .heavy, design: .rounded))
                    .foregroundStyle(TokenBarTheme.text)
                Text(rows.isEmpty ? "not measured" : "measured weight")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(TokenBarTheme.secondary)
            }
        }
    }
}

private struct ProviderRow: View {
    let provider: ProviderSnapshot
    let total: Int64

    private var share: Double {
        Double(provider.tokens) / Double(max(1, total))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Circle()
                    .fill(provider.tint)
                    .frame(width: 8, height: 8)
                Text(provider.title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(TokenBarTheme.text)
                Spacer()
                Text(provider.isMeasured ? "Measured" : (provider.isConnected ? "Connected" : "Setup"))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(provider.isMeasured ? TokenBarTheme.green : TokenBarTheme.amber)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(TokenBarTheme.raised)
                    Capsule()
                        .fill(provider.tint)
                        .frame(width: provider.isMeasured ? max(8, proxy.size.width * share) : 8)
                        .opacity(provider.isMeasured ? 1 : 0.38)
                }
            }
            .frame(height: 7)
            HStack {
                Text(provider.detail)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(TokenBarTheme.secondary)
                Spacer()
                Text(provider.isMeasured ? TokenFormatter.compact(provider.tokens) : "--")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(TokenBarTheme.secondary)
            }
            HStack(spacing: 6) {
                Label(provider.accountLabel, systemImage: provider.isMeasured ? "checkmark.seal.fill" : "person.crop.circle.badge.questionmark")
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(provider.sourceLabel)
                    .lineLimit(1)
            }
            .font(.system(size: 8, weight: .bold, design: .monospaced))
            .foregroundStyle(provider.isMeasured ? TokenBarTheme.green : TokenBarTheme.secondary)
        }
    }
}

private struct MenuForecastSurface: View {
    let days: [UsageDaySnapshot]

    private var recent: [UsageDaySnapshot] {
        Array(days.suffix(10))
    }

    private var forecast: ForecastSummary {
        ForecastSummary(days: recent)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            MenuSectionHeader("Projected usage", subtitle: "Forecast includes an uncertainty band instead of a single fake-exact line.")
            ForecastRibbon(days: recent, forecast: forecast)
                .frame(height: 230)
            HStack(spacing: 10) {
                MenuMetricTile(value: TokenFormatter.compact(forecast.expected), label: "next 7 days", tint: TokenBarTheme.cyan)
                MenuMetricTile(value: TokenFormatter.compact(forecast.low) + "-" + TokenFormatter.compact(forecast.high), label: "likely band", tint: TokenBarTheme.amber)
                MenuMetricTile(value: forecast.riskLabel, label: "budget risk", tint: forecast.riskTint)
            }
            Label("Bands widen when the last few days are uneven.", systemImage: "info.circle")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(TokenBarTheme.secondary)
        }
    }
}

private struct ForecastSummary {
    let expected: Int64
    let low: Int64
    let high: Int64
    let riskLabel: String
    let riskTint: Color

    init(days: [UsageDaySnapshot]) {
        let values = days.map(\.tokens)
        let average = values.isEmpty ? Int64(0) : values.reduce(0, +) / Int64(values.count)
        let spread = values.map { abs($0 - average) }.max() ?? 0
        expected = average * 7
        low = max(0, expected - (spread * 3))
        high = expected + (spread * 3)
        if high > 2_000_000_000 {
            riskLabel = "high"
            riskTint = TokenBarTheme.coral
        } else if high > 800_000_000 {
            riskLabel = "watch"
            riskTint = TokenBarTheme.amber
        } else {
            riskLabel = "steady"
            riskTint = TokenBarTheme.green
        }
    }
}

private struct ForecastRibbon: View {
    let days: [UsageDaySnapshot]
    let forecast: ForecastSummary

    private var values: [Int64] {
        let history = days.map(\.tokens)
        let projected = [forecast.low / 7, forecast.expected / 7, forecast.high / 7]
        return history + projected
    }

    var body: some View {
        let plotValues = values
        let localMaxValue = max(1, plotValues.max() ?? 1)

        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(TokenBarTheme.panel.opacity(0.72))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(TokenBarTheme.border))

                Canvas { context, size in
                    let plot = CGRect(x: 22, y: 22, width: size.width - 44, height: size.height - 58)
                    let step = plot.width / CGFloat(max(1, plotValues.count - 1))
                    func point(_ index: Int, _ value: Int64) -> CGPoint {
                        let y = plot.maxY - (CGFloat(value) / CGFloat(localMaxValue) * plot.height)
                        return CGPoint(x: plot.minX + CGFloat(index) * step, y: y)
                    }

                    var band = Path()
                    let lowPoint = point(max(0, values.count - 3), forecast.low / 7)
                    let highPoint = point(values.count - 1, forecast.high / 7)
                    band.move(to: CGPoint(x: lowPoint.x, y: lowPoint.y))
                    band.addLine(to: CGPoint(x: highPoint.x, y: highPoint.y))
                    band.addLine(to: CGPoint(x: highPoint.x, y: plot.maxY))
                    band.addLine(to: CGPoint(x: lowPoint.x, y: plot.maxY))
                    band.closeSubpath()
                    context.fill(band, with: .linearGradient(
                        Gradient(colors: [TokenBarTheme.amber.opacity(0.18), TokenBarTheme.coral.opacity(0.12)]),
                        startPoint: lowPoint,
                        endPoint: highPoint
                    ))

                    for index in plotValues.indices {
                        let dot = point(index, plotValues[index])
                        let color = index >= plotValues.count - 3 ? TokenBarTheme.amber : TokenBarTheme.cyan
                        context.fill(Path(ellipseIn: CGRect(x: dot.x - 4, y: dot.y - 4, width: 8, height: 8)), with: .color(color))
                    }

                    var line = Path()
                    for index in plotValues.indices {
                        let dot = point(index, plotValues[index])
                        index == plotValues.startIndex ? line.move(to: dot) : line.addLine(to: dot)
                    }
                    context.stroke(line, with: .color(TokenBarTheme.cyan.opacity(0.72)), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                }
                .frame(width: proxy.size.width, height: proxy.size.height)

                VStack {
                    Spacer()
                    HStack {
                        Text("history")
                        Spacer()
                        Text("uncertainty")
                    }
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(TokenBarTheme.secondary)
                    .padding(.horizontal, 22)
                    .padding(.bottom, 12)
                }
            }
        }
    }
}

private struct MenuBudgetSurface: View {
    @EnvironmentObject private var model: TokenBarModel
    let usage: UsageSnapshot
    @State private var remindersOn = true
    @State private var selectedCoach = BudgetCoachPreset.steady

    private var dailyTokens: Int64 {
        usage.days.last?.tokens ?? 0
    }

    private var budgetFraction: Double {
        min(1, Double(dailyTokens) / 1_000_000_000)
    }

    private var runwayState: String {
        switch budgetFraction {
        case 0.9...:
            "Over"
        case 0.72..<0.9:
            "High"
        case 0.55..<0.72:
            "Watch"
        default:
            "Calm"
        }
    }

    private var recommendedLimit: String {
        switch selectedCoach {
        case .steady:
            "Keep the next run under 80% pressure."
        case .focus:
            "Keep the next run under 72% pressure."
        case .strict:
            "Stop for approval at 60% pressure."
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            MenuSectionHeader("Budgets and reminders", subtitle: "The useful part is the action before the limit, not the alert after it.")
            BudgetReservoir(fraction: budgetFraction)
                .frame(height: 180)
            HStack(spacing: 10) {
                ReminderCapsule(title: "75%", subtitle: "pace check", tint: TokenBarTheme.amber)
                ReminderCapsule(title: "90%", subtitle: "handoff now", tint: TokenBarTheme.coral)
                ReminderCapsule(title: remindersOn ? "On" : "Off", subtitle: "reminders", tint: remindersOn ? TokenBarTheme.green : TokenBarTheme.secondary)
                    .onTapGesture { remindersOn.toggle() }
            }
            Text("Suggested: ask agents to state budget, route, verifier, and stop condition in the first answer before long work begins.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(TokenBarTheme.secondary)
                .lineSpacing(3)
            RunwayBriefCard(
                state: runwayState,
                recommendedLimit: recommendedLimit,
                prompt: selectedCoach.prompt,
                tint: selectedCoach.tint,
                fraction: budgetFraction,
                remindersOn: remindersOn
            )
            BudgetCoachCard(preset: selectedCoach, remindersOn: remindersOn)
            HStack(spacing: 8) {
                ForEach(BudgetCoachPreset.allCases) { preset in
                    Button {
                        selectedCoach = preset
                    } label: {
                        Text(preset.rawValue)
                            .font(.system(size: 11, weight: .bold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(selectedCoach == preset ? preset.tint : TokenBarTheme.secondary)
                }
            }
            HStack(spacing: 8) {
                Button {
                    model.copy(selectedCoach.prompt, confirmation: "\(selectedCoach.rawValue) prompt copied")
                } label: {
                    Label("Copy setup prompt", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                Button {
                    model.copy("tokenbar reminders json", confirmation: "Reminder command copied")
                } label: {
                    Label("Copy reminder command", systemImage: "bell.badge")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(TokenBarTheme.amber)
        }
    }
}

private struct RunwayBriefCard: View {
    let state: String
    let recommendedLimit: String
    let prompt: String
    let tint: Color
    let fraction: Double
    let remindersOn: Bool

    private var riskBars: [Double] {
        [
            max(0.18, min(1, fraction + 0.12)),
            max(0.16, min(1, fraction * 0.82 + 0.2)),
            max(0.14, min(1, fraction * 1.1 + 0.08)),
            max(0.12, min(1, 1 - fraction * 0.35)),
        ]
    }

    var body: some View {
        TokenBarMiniPanel {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("RUNWAY BRIEF")
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .foregroundStyle(tint)
                        Text("Prepare the next run before it expands.")
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                            .foregroundStyle(TokenBarTheme.text)
                    }
                    Spacer()
                    Text(state)
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(tint)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(tint.opacity(0.14), in: Capsule())
                }

                HStack(alignment: .bottom, spacing: 7) {
                    ForEach(Array(riskBars.enumerated()), id: \.offset) { index, value in
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [TokenBarTheme.cyan.opacity(0.35), tint.opacity(index == 2 ? 0.95 : 0.62)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: 14 + 42 * value)
                            .shadow(color: tint.opacity(0.18), radius: 10, x: 0, y: 6)
                    }
                }
                .frame(height: 70)
                .padding(.horizontal, 4)

                Text(recommendedLimit)
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(TokenBarTheme.text)
                Text(prompt)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(TokenBarTheme.secondary)
                    .lineLimit(3)
                    .lineSpacing(2)

                HStack(spacing: 8) {
                    Label(remindersOn ? "Suggested only" : "Draft only", systemImage: "bell.badge")
                    Label("No notification scheduled", systemImage: "hand.raised")
                }
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(TokenBarTheme.secondary)
            }
        }
    }
}

private enum BudgetCoachPreset: String, CaseIterable, Identifiable {
    case steady = "Steady"
    case focus = "Focus"
    case strict = "Strict"

    var id: String { rawValue }

    var tint: Color {
        switch self {
        case .steady: TokenBarTheme.green
        case .focus: TokenBarTheme.cyan
        case .strict: TokenBarTheme.coral
        }
    }

    var threshold: String {
        switch self {
        case .steady: "80%"
        case .focus: "72%"
        case .strict: "60%"
        }
    }

    var title: String {
        switch self {
        case .steady: "Keep the run shaped."
        case .focus: "Shorten before drift."
        case .strict: "Stop before waste."
        }
    }

    var copy: String {
        switch self {
        case .steady:
            "Warn at 80% of the chosen budget, then suggest one cheaper verifier-first prompt."
        case .focus:
            "At 72%, ask the agent to reduce context, name the next proof command, and defer extras."
        case .strict:
            "At 60%, require a stop-or-continue decision before additional files, tools, or outputs."
        }
    }

    var prompt: String {
        switch self {
        case .steady:
            "Budget: Steady. State route, context cap, expected input/output cost, verifier, and stop condition in your first answer. Warn before the run exceeds 80% of the budget. Do not schedule, publish, spend, or contact external services without approval."
        case .focus:
            "Budget: Focus. Before coding, reduce the task to one proof-bearing improvement, name the files you will touch, set a context cap, and stop at 72% budget pressure unless the next action is verification. Keep external actions approval-gated."
        case .strict:
            "Budget: Strict. Do not broaden scope. Give the exact smallest implementation, one verifier, and the stop condition. At 60% budget pressure, ask whether to continue, hand off, or stop. No credentials, publishing, spending, or destructive actions."
        }
    }
}

private struct BudgetCoachCard: View {
    let preset: BudgetCoachPreset
    let remindersOn: Bool

    var body: some View {
        TokenBarMiniPanel {
            VStack(alignment: .leading, spacing: 11) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("AI BUDGET COACH")
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .foregroundStyle(preset.tint)
                        Text(preset.title)
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                            .foregroundStyle(TokenBarTheme.text)
                    }
                    Spacer()
                    Text(preset.threshold)
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(preset.tint)
                }
                Text(preset.copy)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(TokenBarTheme.secondary)
                    .lineSpacing(2)
                HStack(spacing: 8) {
                    Label(remindersOn ? "Suggested reminder" : "Reminder draft only", systemImage: remindersOn ? "bell.badge.fill" : "bell.slash")
                    Label("Approval-gated", systemImage: "hand.raised.fill")
                }
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(TokenBarTheme.secondary)
            }
        }
    }
}

private struct BudgetReservoir: View {
    let fraction: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(TokenBarTheme.panel.opacity(0.72))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(TokenBarTheme.border))
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient(colors: [TokenBarTheme.cyan, TokenBarTheme.amber], startPoint: .bottom, endPoint: .top))
                    .frame(height: max(14, proxy.size.height * fraction))
                    .opacity(0.82)
                    .padding(12)
                VStack {
                    Spacer()
                    threshold(label: "75", y: proxy.size.height * 0.25)
                    threshold(label: "90", y: proxy.size.height * 0.10)
                }
                .padding(.horizontal, 18)
            }
        }
    }

    private func threshold(label: String, y: CGFloat) -> some View {
        HStack {
            Rectangle()
                .fill(TokenBarTheme.text.opacity(0.34))
                .frame(height: 1)
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(TokenBarTheme.secondary)
        }
        .offset(y: -y)
    }
}

private struct MenuCostSurface: View {
    let costUsage: CCUsageSnapshot
    let isLoading: Bool
    let refresh: () -> Void
    let copyCommand: (String) -> Void

    @State private var selectedDays = 7

    private var availableDays: Int {
        max(1, costUsage.recentDays.count)
    }

    private var selectedWindowDays: Int {
        min(selectedDays, availableDays)
    }

    private var selectedRows: [CCUsageDaySnapshot] {
        Array(costUsage.recentDays.suffix(selectedWindowDays))
    }

    private var selectedTotal: Double {
        selectedRows.reduce(0) { $0 + Self.currencyValue($1.totalCost) }
    }

    private var selectedCodex: Double {
        selectedRows.reduce(0) { $0 + Self.currencyValue($1.codexCost) }
    }

    private var peakDay: CCUsageDaySnapshot? {
        selectedRows.max { Self.currencyValue($0.totalCost) < Self.currencyValue($1.totalCost) }
    }

    private var selectedRangeLabel: String {
        guard let first = selectedRows.first, let last = selectedRows.last else {
            return "No cost range loaded"
        }
        return first.period == last.period ? first.period : "\(first.period) -> \(last.period)"
    }

    private var forecastBand: String {
        let low = selectedTotal * 0.72
        let high = selectedTotal * 1.38
        return "\(Self.currency(low)) to \(Self.currency(high))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                MenuSectionHeader("Cost passport", subtitle: "Daily costs stay local and become a range you can inspect.")
                Spacer()
                Button(isLoading ? "Reading" : "Load") { refresh() }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoading)
            }
            if costUsage.period == "Not loaded" {
                TokenBarMiniPanel {
                    VStack(alignment: .leading, spacing: 9) {
                        Label("Run a local ccusage read to fill this passport.", systemImage: "terminal")
                        Text("TokenBar does not upload logs. It caches a private summary under Application Support.")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(TokenBarTheme.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        ForEach([3, 7], id: \.self) { option in
                            Button {
                                selectedDays = min(option, availableDays)
                            } label: {
                                Text(option == 7 ? "7 days" : "3 days")
                                    .font(.system(size: 11, weight: .heavy))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                            .padding(.vertical, 7)
                            .background(selectedWindowDays == min(option, availableDays) ? TokenBarTheme.amber.opacity(0.28) : TokenBarTheme.raised.opacity(0.48), in: RoundedRectangle(cornerRadius: 9))
                            .overlay(RoundedRectangle(cornerRadius: 9).stroke(selectedWindowDays == min(option, availableDays) ? TokenBarTheme.amber.opacity(0.48) : TokenBarTheme.border))
                        }
                        Button {
                            copyCommand("tokenbar cost-passport --from YYYY-MM-DD --to YYYY-MM-DD json")
                        } label: {
                            Label("Copy range", systemImage: "doc.on.doc")
                        }
                        .buttonStyle(.bordered)
                        Button {
                            copyCommand("tokenbar reminders json")
                        } label: {
                            Label("Reminder", systemImage: "bell.badge")
                        }
                        .buttonStyle(.bordered)
                    }

                    CostPassport(
                        days: selectedRows,
                        rangeLabel: selectedRangeLabel,
                        selectedTotal: Self.currency(selectedTotal),
                        selectedCodex: Self.currency(selectedCodex),
                        peakLabel: peakDay.map { "\($0.period) · \($0.totalCost)" } ?? "No peak yet",
                        forecastBand: forecastBand
                    )
                    .frame(height: 286)

                    HStack(spacing: 10) {
                        MenuMetricTile(value: costUsage.latestCost, label: "latest day", tint: TokenBarTheme.green)
                        MenuMetricTile(value: costUsage.codexCost, label: "codex share", tint: TokenBarTheme.cyan)
                        MenuMetricTile(value: costUsage.observedCost, label: "observed", tint: TokenBarTheme.amber)
                    }
                }
            }
        }
        .onChange(of: availableDays) { _, newValue in
            selectedDays = min(selectedDays, max(1, newValue))
        }
    }

    private static func currencyValue(_ value: String) -> Double {
        let cleaned = value
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Double(cleaned) ?? 0
    }

    private static func currency(_ value: Double) -> String {
        if value >= 100 {
            return "$\(Int(value.rounded()))"
        }
        return String(format: "$%.2f", value)
    }
}

private struct CostPassport: View {
    let days: [CCUsageDaySnapshot]
    let rangeLabel: String
    let selectedTotal: String
    let selectedCodex: String
    let peakLabel: String
    let forecastBand: String

    private var peakCost: Double {
        max(1, days.map { costValue($0.totalCost) }.max() ?? 1)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            TokenBarTheme.panel.opacity(0.88),
                            TokenBarTheme.amber.opacity(0.11),
                            TokenBarTheme.cyan.opacity(0.09),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("SELECTED RANGE")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundStyle(TokenBarTheme.amber)
                        Text(rangeLabel)
                            .font(.system(size: 13, weight: .heavy, design: .monospaced))
                            .foregroundStyle(TokenBarTheme.text)
                            .lineLimit(1)
                        Text("Estimate only. Not a provider invoice.")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(TokenBarTheme.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(selectedTotal)
                            .font(.system(size: 34, weight: .black, design: .rounded))
                            .foregroundStyle(TokenBarTheme.amber)
                        Text("local estimate")
                            .font(.system(size: 10, weight: .black))
                            .foregroundStyle(TokenBarTheme.secondary)
                    }
                }

                HStack(spacing: 10) {
                    PassportFact(label: "Peak day", value: peakLabel, tint: TokenBarTheme.coral)
                    PassportFact(label: "Codex share", value: selectedCodex, tint: TokenBarTheme.cyan)
                    PassportFact(label: "Forecast band", value: forecastBand, tint: TokenBarTheme.indigo)
                }

                GeometryReader { geometry in
                    HStack(alignment: .bottom, spacing: 5) {
                        ForEach(days) { day in
                            let height = max(8, min(82, (costValue(day.totalCost) / peakCost) * 82))
                            VStack(spacing: 5) {
                                Spacer(minLength: 0)
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(
                                        LinearGradient(
                                            colors: [TokenBarTheme.cyan, TokenBarTheme.amber.opacity(0.86)],
                                            startPoint: .bottom,
                                            endPoint: .top
                                        )
                                    )
                                    .frame(
                                        width: max(9, (geometry.size.width - CGFloat(max(0, days.count - 1)) * 5) / CGFloat(max(1, days.count))),
                                        height: height
                                    )
                                    .overlay(alignment: .top) {
                                        Circle()
                                            .fill(TokenBarTheme.text.opacity(0.74))
                                            .frame(width: 5, height: 5)
                                            .offset(y: -7)
                                    }
                                Text(shortDate(day.period))
                                    .font(.system(size: 8, weight: .black, design: .monospaced))
                                    .foregroundStyle(TokenBarTheme.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .frame(height: 104)

                HStack(spacing: 8) {
                    Label("Aggregate totals only", systemImage: "lock.shield")
                    Spacer()
                    Text("Raw prompts, paths, source, credentials stay out.")
                }
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(TokenBarTheme.secondary)
            }
            .padding(14)
        }
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(TokenBarTheme.amber.opacity(0.28)))
    }

    private func costValue(_ value: String) -> Double {
        let cleaned = value
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Double(cleaned) ?? 0
    }

    private func shortDate(_ value: String) -> String {
        let parts = value.split(separator: "-")
        if parts.count >= 3 {
            return parts.suffix(2).joined(separator: "/")
        }
        return value
    }
}

private struct PassportFact: View {
    let label: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(tint)
            Text(value)
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .foregroundStyle(TokenBarTheme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(TokenBarTheme.raised.opacity(0.50), in: RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(tint.opacity(0.18)))
    }
}

private enum PlaybookTierFilter: String, CaseIterable, Identifiable {
    case free = "Free"
    case pro = "Pro"

    var id: String { rawValue }
}

private struct MenuPlaybooksSurface: View {
    let copyCommand: (String) -> Void
    let copyPlaybookJSON: () -> Void
    let openPlaybooks: () -> Void
    let openCatalog: () -> Void
    let copyPlaybook: (PromptPlaybook) -> Void

    @State private var tier: PlaybookTierFilter = .free

    private var playbooks: [PromptPlaybook] {
        switch tier {
        case .free: PromptPlaybook.freeSet
        case .pro: PromptPlaybook.proSet
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            MenuSectionHeader(
                "Prompt playbooks",
                subtitle: "A prompt operating system for budget, scope, cost, handoff, and proof."
            )

            PlaybookCommandStrip(
                copyJSON: copyPlaybookJSON,
                copyFree: { copyCommand("tokenbar playbooks copy mission-lock") },
                openPlaybooks: openPlaybooks
            )

            PlaybookMatrixPreview()

            Picker("Playbook tier", selection: $tier) {
                ForEach(PlaybookTierFilter.allCases) { item in
                    Text(item.rawValue).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            VStack(spacing: 9) {
                ForEach(playbooks) { playbook in
                    PromptPlaybookCard(playbook: playbook) {
                        copyPlaybook(playbook)
                    }
                }
            }

            PlaybookPrivacyBar(openCatalog: openCatalog)
        }
    }
}

private struct PlaybookCommandStrip: View {
    let copyJSON: () -> Void
    let copyFree: () -> Void
    let openPlaybooks: () -> Void

    var body: some View {
        TokenBarMiniPanel {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(TokenBarTheme.amber.opacity(0.20))
                        Image(systemName: "terminal")
                            .foregroundStyle(TokenBarTheme.amber)
                    }
                    .frame(width: 36, height: 36)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Open the playbook layer from the icon bar")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(TokenBarTheme.text)
                        Text("Copy one prompt, open the marketplace, or hand structured JSON to the app without uploading sessions.")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(TokenBarTheme.secondary)
                            .lineSpacing(2)
                    }

                    Spacer(minLength: 6)
                }

                HStack(spacing: 8) {
                    Button {
                        copyFree()
                    } label: {
                        Label("Copy starter", systemImage: "sparkle")
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        copyJSON()
                    } label: {
                        Label("Copy JSON command", systemImage: "curlybraces")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        openPlaybooks()
                    } label: {
                        Label("Open library", systemImage: "arrow.up.right")
                    }
                    .buttonStyle(.bordered)
                }
                .font(.system(size: 11, weight: .bold))
            }
        }
    }
}

private struct PlaybookMatrixPreview: View {
    private let cells: [(String, Color)] = [
        ("Budget", TokenBarTheme.amber),
        ("Scope", TokenBarTheme.cyan),
        ("Stop", TokenBarTheme.coral),
        ("Proof", TokenBarTheme.green),
        ("Cost", TokenBarTheme.amber),
        ("Handoff", TokenBarTheme.indigo),
        ("Launch", TokenBarTheme.coral),
        ("Memory", TokenBarTheme.ivory),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Token waste matrix")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(TokenBarTheme.secondary)
                Spacer()
                Text("Free -> Pro")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(TokenBarTheme.secondary.opacity(0.82))
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 4), spacing: 7) {
                ForEach(cells, id: \.0) { cell in
                    HStack(spacing: 5) {
                        Circle()
                            .fill(cell.1)
                            .frame(width: 6, height: 6)
                        Text(cell.0)
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(TokenBarTheme.text)
                    }
                    .frame(maxWidth: .infinity, minHeight: 30)
                    .background(
                        LinearGradient(
                            colors: [cell.1.opacity(0.18), TokenBarTheme.panel.opacity(0.68)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 8)
                    )
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(cell.1.opacity(0.24)))
                }
            }
        }
        .padding(12)
        .background(TokenBarTheme.panel.opacity(0.42), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(TokenBarTheme.border))
    }
}

private struct PlaybookPrivacyBar: View {
    let openCatalog: () -> Void

    var body: some View {
        TokenBarMiniPanel {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "lock.shield")
                    .foregroundStyle(TokenBarTheme.green)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Free templates stay local. Pro unlocks the full system-prompt library.")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(TokenBarTheme.text)
                    Text("No raw transcripts, source code, or credentials. External actions stay approval-gated.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(TokenBarTheme.secondary)
                        .lineSpacing(2)
                }
                Spacer(minLength: 8)
                Button {
                    openCatalog()
                } label: {
                    Label("Catalog", systemImage: "doc.text.magnifyingglass")
                }
                .buttonStyle(.bordered)
                .font(.system(size: 11, weight: .bold))
            }
        }
    }
}

private struct PromptPlaybook: Identifiable {
    let id: String
    let title: String
    let tier: String
    let category: String
    let subtitle: String
    let outcome: String
    let tint: Color
    let prompt: String

    static let freeSet: [PromptPlaybook] = [
        PromptPlaybook(
            id: "mission-lock",
            title: "Mission Lock",
            tier: "Free",
            category: "Scope",
            subtitle: "Make the agent declare scope, verifier, and stop condition before edits.",
            outcome: "Stops vague first turns",
            tint: TokenBarTheme.cyan,
            prompt: "Budget: Medium | Route: smallest useful implementation | Context cap: only directly affected files | Stop: destructive scope, credentials, paid services, or unclear ownership. First restate the outcome, then implement one verified improvement."
        ),
        PromptPlaybook(
            id: "cost-saver",
            title: "Cost Saver Header",
            tier: "Free",
            category: "Cost",
            subtitle: "Reduce wasteful output tokens and force evidence-first progress.",
            outcome: "Cuts rambling output",
            tint: TokenBarTheme.green,
            prompt: "Budget: Low unless blocked | Route: inspect first, edit second | Context cap: 6 files max | Stop: secrets, paid services, or broad refactor. Return only decision-relevant output."
        ),
        PromptPlaybook(
            id: "verifier-first",
            title: "Verifier First",
            tier: "Free",
            category: "Proof",
            subtitle: "Name the proof before changing code, then run the closest narrow check.",
            outcome: "Prevents fake completion",
            tint: TokenBarTheme.amber,
            prompt: "Before editing, identify the verifier. After editing, run it. If it is too slow, run the closest narrow check and state the limitation."
        ),
        PromptPlaybook(
            id: "connector-truth",
            title: "Connector Truth Table",
            tier: "Free",
            category: "Accounts",
            subtitle: "Separate measured providers from setup lanes and demo placeholders.",
            outcome: "Keeps accounts honest",
            tint: TokenBarTheme.indigo,
            prompt: "For each connector, label measured, connected, demo, setup needed, or unsupported. Never draw usage from unmeasured providers."
        ),
    ]

    static let proSet: [PromptPlaybook] = [
        PromptPlaybook(
            id: "system-prompt-hardener",
            title: "System Prompt Hardener",
            tier: "Pro",
            category: "Constitution",
            subtitle: "Turn a campaign prompt into a stricter operating contract.",
            outcome: "Hardens broad agent runs",
            tint: TokenBarTheme.indigo,
            prompt: "Critique this prompt adversarially, then rewrite it as a bounded constitution. Preserve creative freedom, but harden budget, context cap, evidence requirements, stop conditions, credentials, external actions, and completion proof."
        ),
        PromptPlaybook(
            id: "no-submit-launch-draft",
            title: "No-Submit Launch Draft",
            tier: "Pro",
            category: "Launch",
            subtitle: "Draft launch copy and media asks from verified product evidence without posting.",
            outcome: "Keeps launch human-owned",
            tint: TokenBarTheme.amber,
            prompt: "Prepare Product Hunt, Macapp Supply, and website launch copy only from verified local evidence. Do not submit, upload, schedule, or invent public proof. Mark every missing asset as HUMAN_GATE."
        ),
        PromptPlaybook(
            id: "cost-passport",
            title: "Cost Passport",
            tier: "Pro",
            category: "Costs",
            subtitle: "Turn a date range into spend, peak days, waste flags, and a savings prompt.",
            outcome: "Makes spend actionable",
            tint: TokenBarTheme.coral,
            prompt: "Build a cost passport for this selected range: observed spend, estimated provider cost, peak day, waste pattern, confidence, and one cheaper next-run prompt. Do not call it an invoice."
        ),
        PromptPlaybook(
            id: "thread-handoff",
            title: "Thread Handoff",
            tier: "Pro",
            category: "Threads",
            subtitle: "Offload a long task into the next agent run without losing proof.",
            outcome: "Prevents context amnesia",
            tint: TokenBarTheme.ivory,
            prompt: "Create a handoff note with: objective, current evidence, changed files, commands already run, failed commands with exact error, remaining decisions, approval gates, and the next single safe action. Do not include secrets or raw private transcripts."
        ),
    ]
}

private struct PromptPlaybookCard: View {
    let playbook: PromptPlaybook
    let copy: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 4) {
                Image(systemName: playbook.tier == "Free" ? "sparkle" : "crown")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(playbook.tint)
                Text(playbook.tier.uppercased())
                    .font(.system(size: 8, weight: .heavy))
                    .foregroundStyle(TokenBarTheme.secondary)
            }
            .frame(width: 42)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(playbook.category.uppercased())
                        .font(.system(size: 8, weight: .heavy, design: .monospaced))
                        .foregroundStyle(playbook.tint)
                    Text(playbook.outcome)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(TokenBarTheme.secondary.opacity(0.86))
                }
                Text(playbook.title)
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(TokenBarTheme.text)
                Text(playbook.subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(TokenBarTheme.secondary)
                    .lineSpacing(2)
                Text(playbook.prompt)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(TokenBarTheme.secondary.opacity(0.82))
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Button {
                copy()
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.bordered)
            .help("Copy \(playbook.title)")
        }
        .padding(12)
        .background(TokenBarTheme.panel.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(playbook.tint.opacity(0.26)))
    }
}

private struct MenuComparisonSurface: View {
    let usage: UsageSnapshot
    let copyCommand: () -> Void

    private var lens: ComparisonLens {
        ComparisonLens(usage: usage)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            MenuSectionHeader(
                "Comparison lens",
                subtitle: "Compare the work pattern, not the person."
            )

            ComparisonConstellation(cards: lens.cards)
                .frame(height: 220)

            HStack(spacing: 10) {
                MenuMetricTile(value: "\(lens.activeDays)/30", label: "active days", tint: TokenBarTheme.cyan)
                MenuMetricTile(value: "locked", label: "percentile", tint: TokenBarTheme.amber)
                MenuMetricTile(value: "\(lens.minimumCohort)+", label: "cohort gate", tint: TokenBarTheme.indigo)
            }

            VStack(spacing: 9) {
                ForEach(lens.cards) { card in
                    ComparisonMetricRow(card: card)
                }
            }

            TokenBarMiniPanel {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "lock.shield")
                            .foregroundStyle(TokenBarTheme.green)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Percentiles unlock only with opt-in proof cohorts.")
                                .font(.system(size: 12, weight: .heavy))
                                .foregroundStyle(TokenBarTheme.text)
                            Text("Local mode can compare your own windows. It cannot claim top 1%, rank identities as better or worse, or compare raw prompts and source code.")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(TokenBarTheme.secondary)
                                .lineSpacing(2)
                        }
                    }
                    Button {
                        copyCommand()
                    } label: {
                        Label("Copy comparison JSON command", systemImage: "curlybraces")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(TokenBarTheme.indigo)
                }
            }
        }
    }
}

private struct ComparisonLens {
    let cards: [ComparisonMetricCard]
    let activeDays: Int
    let minimumCohort = 10

    init(usage: UsageSnapshot) {
        let values = usage.days.suffix(30).map(\.tokens)
        let active = values.filter { $0 > 0 }
        let last7 = values.suffix(7).reduce(Int64(0), +)
        let previous7 = values.dropLast(7).suffix(7).reduce(Int64(0), +)
        let last30 = values.reduce(Int64(0), +)
        let peak = values.max() ?? 0
        let avgActive = active.isEmpty ? Int64(0) : active.reduce(0, +) / Int64(active.count)
        activeDays = active.count

        let consistency: Int
        if active.isEmpty {
            consistency = 0
        } else {
            let variance = active.map { abs($0 - avgActive) }.reduce(Int64(0), +) / Int64(max(1, active.count))
            consistency = max(0, min(100, 100 - Int((Double(variance) / Double(max(1, avgActive))) * 45)))
        }

        let momentum: Int
        if previous7 > 0 {
            momentum = max(0, min(100, 50 + Int((Double(last7 - previous7) / Double(max(1, previous7))) * 35)))
        } else {
            momentum = last7 > 0 ? 68 : 50
        }

        let costControl: Int
        if avgActive > 0 {
            costControl = max(0, min(100, 84 - Int((Double(peak) / Double(max(1, avgActive)) - 1) * 18)))
        } else {
            costControl = 50
        }

        let quietDays = max(0, values.count - active.count)
        let scope = max(0, min(100, 45 + active.count * 2 - min(25, quietDays)))

        cards = [
            ComparisonMetricCard(label: "Cadence", value: "\(active.count)/30 active", score: consistency, tint: TokenBarTheme.cyan),
            ComparisonMetricCard(label: "Momentum", value: TokenFormatter.compact(last7), score: momentum, tint: TokenBarTheme.green),
            ComparisonMetricCard(label: "Cost control", value: TokenFormatter.compact(avgActive), score: costControl, tint: TokenBarTheme.amber),
            ComparisonMetricCard(label: "Scope discipline", value: TokenFormatter.compact(last30), score: scope, tint: TokenBarTheme.indigo),
        ]
    }
}

private struct ComparisonMetricCard: Identifiable {
    var id: String { label }
    let label: String
    let value: String
    let score: Int
    let tint: Color
}

private struct ComparisonConstellation: View {
    let cards: [ComparisonMetricCard]

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(TokenBarTheme.panel.opacity(0.72))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(TokenBarTheme.border))

                Canvas { context, size in
                    let center = CGPoint(x: size.width * 0.50, y: size.height * 0.50)
                    let radius = min(size.width, size.height) * 0.32
                    let points = cards.enumerated().map { index, card -> CGPoint in
                        let angle = (Double(index) / Double(max(1, cards.count))) * Double.pi * 2 - Double.pi / 2
                        let scale = CGFloat(max(20, card.score)) / 100
                        return CGPoint(
                            x: center.x + cos(angle) * radius * scale,
                            y: center.y + sin(angle) * radius * scale
                        )
                    }

                    var grid = Path()
                    for step in 1...4 {
                        let ring = radius * CGFloat(step) / 4
                        grid.addEllipse(in: CGRect(x: center.x - ring, y: center.y - ring, width: ring * 2, height: ring * 2))
                    }
                    context.stroke(grid, with: .color(TokenBarTheme.secondary.opacity(0.12)), lineWidth: 1)

                    if points.count > 1 {
                        var shape = Path()
                        shape.move(to: points[0])
                        for point in points.dropFirst() {
                            shape.addLine(to: point)
                        }
                        shape.closeSubpath()
                        context.fill(shape, with: .color(TokenBarTheme.indigo.opacity(0.18)))
                        context.stroke(shape, with: .color(TokenBarTheme.indigo.opacity(0.72)), style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))
                    }

                    for (index, point) in points.enumerated() {
                        let card = cards[index]
                        context.fill(Path(ellipseIn: CGRect(x: point.x - 6, y: point.y - 6, width: 12, height: 12)), with: .color(card.tint))
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)

                VStack {
                    HStack {
                        Text("SELF-OVER-TIME")
                        Spacer()
                        Text("COHORT LOCKED")
                    }
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .foregroundStyle(TokenBarTheme.secondary)
                    Spacer()
                    Text("No top-percentile claim without opt-in data.")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(TokenBarTheme.secondary)
                }
                .padding(16)
            }
        }
    }
}

private struct ComparisonMetricRow: View {
    let card: ComparisonMetricCard

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(card.label)
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(TokenBarTheme.text)
                Text(card.value)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(TokenBarTheme.secondary)
            }
            Spacer()
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(TokenBarTheme.secondary.opacity(0.12))
                    Capsule()
                        .fill(card.tint)
                        .frame(width: proxy.size.width * CGFloat(card.score) / 100)
                }
            }
            .frame(width: 132, height: 8)
            Text("\(card.score)")
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .foregroundStyle(card.tint)
                .frame(width: 30, alignment: .trailing)
        }
        .padding(12)
        .background(TokenBarTheme.panel.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(card.tint.opacity(0.22)))
    }
}

private struct MenuSystemSurface: View {
    private var runningApps: Int {
        NSWorkspace.shared.runningApplications.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            MenuSectionHeader("Memory guard", subtitle: "A launch-safe preview of system load reasoning and recovery actions.")
            MemorySurface(appCount: runningApps)
                .frame(height: 220)
            HStack(spacing: 10) {
                ReminderCapsule(title: "\(runningApps)", subtitle: "apps open", tint: TokenBarTheme.cyan)
                ReminderCapsule(title: "Ask", subtitle: "before closing", tint: TokenBarTheme.amber)
                ReminderCapsule(title: "Restore", subtitle: "windows later", tint: TokenBarTheme.indigo)
            }
            Text("Automatic app closing remains approval-gated. This surface is prepared for Chrome/Codex overload explanations without taking action by itself.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(TokenBarTheme.secondary)
                .lineSpacing(3)
        }
    }
}

private struct MemorySurface: View {
    let appCount: Int

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(TokenBarTheme.panel.opacity(0.72))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(TokenBarTheme.border))
            Canvas { context, size in
                let center = CGPoint(x: size.width * 0.44, y: size.height * 0.52)
                for index in 0..<28 {
                    let angle = Double(index) * .pi * 2 / 28
                    let radius = CGFloat(36 + (index % 5) * 12)
                    let point = CGPoint(
                        x: center.x + cos(angle) * radius,
                        y: center.y + sin(angle) * radius
                    )
                    let color: Color = index % 3 == 0 ? TokenBarTheme.amber : (index % 3 == 1 ? TokenBarTheme.cyan : TokenBarTheme.indigo)
                    let size = CGFloat(6 + (index % 4) * 3)
                    context.fill(Path(ellipseIn: CGRect(x: point.x, y: point.y, width: size, height: size)), with: .color(color.opacity(0.72)))
                }
                var path = Path()
                path.addArc(center: center, radius: 78, startAngle: .degrees(218), endAngle: .degrees(496), clockwise: false)
                context.stroke(path, with: .color(TokenBarTheme.cyan.opacity(0.55)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("pressure map")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(TokenBarTheme.secondary)
                Text(appCount > 70 ? "Crowded workspace" : "Workspace steady")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(TokenBarTheme.text)
                Text("Chrome, Codex, and IDE lanes will be grouped here before any assisted restart.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(TokenBarTheme.secondary)
                    .frame(maxWidth: 230, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(18)
        }
    }
}

private struct ReminderCapsule: View {
    let title: String
    let subtitle: String
    let tint: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(tint)
            Text(subtitle.uppercased())
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(TokenBarTheme.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 13)
        .background(TokenBarTheme.panel.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(TokenBarTheme.border))
    }
}

private struct MenuMetricTile: View {
    let value: String
    let label: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 19, weight: .heavy, design: .rounded))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(TokenBarTheme.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(TokenBarTheme.panel.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(TokenBarTheme.border))
    }
}

private struct TokenBarMiniPanel<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(TokenBarTheme.panel.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(TokenBarTheme.border))
    }
}

private struct MenuSectionHeader: View {
    let title: String
    let subtitle: String

    init(_ title: String, subtitle: String) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(TokenBarTheme.amber)
            Text(subtitle)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(TokenBarTheme.secondary)
                .lineSpacing(2)
        }
    }
}

private struct MenuBarBackground: View {
    var body: some View {
        ZStack {
            TokenBarTheme.canvas
            LinearGradient(
                colors: [
                    TokenBarTheme.indigo.opacity(0.18),
                    Color.clear,
                    TokenBarTheme.amber.opacity(0.10),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Canvas { context, size in
                var path = Path()
                stride(from: CGFloat(-120), through: size.width + size.height, by: 42).forEach { x in
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x - size.height, y: size.height))
                }
                context.stroke(path, with: .color(TokenBarTheme.ivory.opacity(0.025)), lineWidth: 1)
            }
        }
        .ignoresSafeArea()
    }
}

private enum AccountLabel {
    static var current: String {
        let user = NSUserName()
        return user.isEmpty ? "Local Mac account" : "\(user) local account"
    }
}

private enum TokenFormatter {
    static func compact(_ value: Int64) -> String {
        let absValue = abs(value)
        if absValue >= 1_000_000_000 {
            return String(format: "%.2fB", Double(value) / 1_000_000_000)
        }
        if absValue >= 1_000_000 {
            return String(format: "%.0fM", Double(value) / 1_000_000)
        }
        if absValue >= 1_000 {
            return String(format: "%.0fK", Double(value) / 1_000)
        }
        return "\(value)"
    }
}
