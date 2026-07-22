import AppKit
import SwiftUI

@main
struct TokenBarMacApp: App {
    @NSApplicationDelegateAdaptor(TokenBarAppDelegate.self) private var appDelegate
    @StateObject private var model = TokenBarModel.shared

    var body: some Scene {
        MenuBarExtra("TokenBar", systemImage: "circle.hexagongrid.fill") {
            TokenBarMenuView()
                .environmentObject(model)
        }
        .menuBarExtraStyle(.menu)
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

private struct TokenBarMenuView: View {
    @EnvironmentObject private var model: TokenBarModel

    var body: some View {
        Text(model.profile.identityTitle)
        Text("\(model.profile.usage.last7) this week · proof \(model.profile.proofScore)")
        Divider()
        Button("Open Builder Identity") {
            TokenBarAppDelegate.shared?.openMainWindow()
        }
        Button("Analyze this week") {
            model.refreshIdentity()
            TokenBarAppDelegate.shared?.openMainWindow()
        }
        Divider()
        Button("Quit TokenBar") {
            NSApp.terminate(nil)
        }
    }
}
