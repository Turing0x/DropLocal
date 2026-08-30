import Foundation

// Constantes del protocolo LocalSend v2.2 (github.com/localsend/protocol,
// leído el 30/08/2026). No hay mDNS/Bonjour en la especificación: el
// descubrimiento real es multicast UDP crudo + escaneo HTTP de subred.
// Ver Discovery.swift para el porqué de esa decisión.
enum LocalSendProtocol {
    static let version = "2.2"
    static let apiBasePath = "/api/localsend/v2"

    static let defaultPort: UInt16 = 53317
    static let multicastGroup = "224.0.0.167"
    static let multicastPort: UInt16 = 53317

    static let registerPath = "\(apiBasePath)/register"
    static let infoPath = "\(apiBasePath)/info"
    static let prepareUploadPath = "\(apiBasePath)/prepare-upload"
    static let uploadPath = "\(apiBasePath)/upload"
    static let cancelPath = "\(apiBasePath)/cancel"
}

enum LocalSendDeviceType: String, Codable, Sendable {
    case mobile, desktop, web, headless, server
}
