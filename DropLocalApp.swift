import SwiftUI

@main
struct DropLocalApp: App {
    @StateObject private var transferService = LocalTransferService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(transferService)
                .preferredColorScheme(.dark)
                #if os(macOS)
                .frame(minWidth: 420, minHeight: 640)
                #endif
        }
        #if os(macOS)
        .defaultSize(width: 480, height: 780)
        .windowResizability(.contentMinSize)
        #endif
    }
}