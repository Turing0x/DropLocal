import SwiftUI

@main
struct NexoApp: App {
    @State private var transferService = LocalTransferService()
    @State private var discoveryStore = DiscoveryStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(transferService)
                .environment(discoveryStore)
                // Arranca el servidor LocalSend (NWListener con TLS) y el
                // escaneo periódico de la subred. `.task` se cancela solo al
                // desaparecer la vista, y `start()` es idempotente.
                .task { discoveryStore.start() }
        }
    }
}
