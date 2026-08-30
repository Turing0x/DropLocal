import Foundation

// Dispositivo LocalSend descubierto. Sustituye a `DiscoveredDevice` (que
// solo guardaba un endpoint de Bonjour del protocolo viejo) por algo que
// ya trae dirección IP y puerto, porque el nuevo descubrimiento habla
// directamente por IP: ni mDNS ni NWBrowser están en el protocolo.
struct Device: Identifiable, Equatable, Sendable {
    var fingerprint: String
    var alias: String
    var deviceModel: String?
    var deviceType: LocalSendDeviceType?
    var host: String
    var port: Int
    var useHTTPS: Bool
    var lastSeen: Date

    var id: String { fingerprint }
}
