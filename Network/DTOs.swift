import Foundation

// Codable del protocolo LocalSend v2.2. Los campos opcionales lo son porque
// la especificación los omite en distintos endpoints (p.ej. la respuesta de
// /info no lleva `port` ni `protocol`); un único tipo reutilizable evita
// duplicar el mismo objeto ocho veces con combinaciones distintas de campos.
struct LocalSendDeviceInfo: Codable, Equatable, Sendable {
    var alias: String
    var version: String
    var deviceModel: String?
    var deviceType: LocalSendDeviceType?
    var fingerprint: String
    var port: Int?
    var protocolName: String?
    var download: Bool?
    // Solo se usa en el anuncio multicast (sección 3.1 de la especificación).
    var announce: Bool?

    enum CodingKeys: String, CodingKey {
        case alias, version, deviceModel, deviceType, fingerprint, port, download, announce
        case protocolName = "protocol"
    }
}

struct LocalSendFileMetadata: Codable, Equatable, Sendable {
    var modified: String?
    var accessed: String?
}

// El `id` del protocolo no es el nombre de fichero (aviso de la sección 8
// del handoff): es una clave arbitraria elegida por el emisor para casar
// esta entrada con su token en la respuesta de /prepare-upload.
struct LocalSendFileDTO: Codable, Equatable, Sendable {
    var id: String
    var fileName: String
    var size: Int64
    var fileType: String
    var sha256: String?
    var preview: String?
    var metadata: LocalSendFileMetadata?
}

struct PrepareUploadRequest: Codable, Sendable {
    var info: LocalSendDeviceInfo
    var files: [String: LocalSendFileDTO]
}

struct PrepareUploadResponse: Codable, Sendable {
    var sessionId: String
    var files: [String: String]
}
