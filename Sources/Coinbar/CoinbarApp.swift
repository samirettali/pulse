import AppKit
import SwiftUI

@main
struct CoinbarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var priceStore = PriceStore(symbols: TrackedSymbol.defaults)

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(store: priceStore)
        } label: {
            Text(priceStore.frozenMenuBarTitle ?? priceStore.menuBarTitle)
                .font(AppFont.uiFont(size: 13, weight: .medium))
                .contextMenu {
                    Button("Reconnect") { priceStore.restart() }
                    Button("Quit") { NSApplication.shared.terminate(nil) }
                }
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
    }
}

extension Notification.Name {
    static let reconnect = Notification.Name("coinbar.reconnect")
}
