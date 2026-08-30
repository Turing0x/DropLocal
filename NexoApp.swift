import SwiftUI

@main
struct NexoApp: App {
    @State private var transferService = LocalTransferService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(transferService)
        }
    }
}
