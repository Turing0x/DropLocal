import Foundation

struct DiscoveredDevice: Identifiable, Equatable {
    let id: String
    let name: String
    let detail: String
}

enum TransferState: Equatable {
    case preparing
    case transferring
    case completed
    case failed(String)

    var label: String {
        switch self {
        case .preparing:
            return "Preparando"
        case .transferring:
            return "Enviando"
        case .completed:
            return "Completado"
        case .failed:
            return "No completado"
        }
    }
}

struct TransferRecord: Identifiable, Equatable {
    let id = UUID()
    let fileName: String
    let size: Int64
    let deviceName: String
    let date: Date
    var progress: Double
    var state: TransferState

    static func == (lhs: TransferRecord, rhs: TransferRecord) -> Bool {
        lhs.id == rhs.id &&
            lhs.fileName == rhs.fileName &&
            lhs.progress == rhs.progress &&
            lhs.state == rhs.state
    }
}

struct SelectedFile: Identifiable, Equatable {
    let id = UUID()
    let url: URL

    var name: String {
        url.lastPathComponent
    }

    var size: Int64 {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        return Int64(values?.fileSize ?? 0)
    }

    static func == (lhs: SelectedFile, rhs: SelectedFile) -> Bool {
        lhs.url == rhs.url
    }
}

enum TransferServiceError: LocalizedError {
    case noDevice
    case unreadableFile
    case connectionFailed
    case invalidResponse
    case remoteRejected(String)

    var errorDescription: String? {
        switch self {
        case .noDevice:
            return "No se ha seleccionado ningún dispositivo."
        case .unreadableFile:
            return "No se puede leer el archivo seleccionado."
        case .connectionFailed:
            return "No se pudo conectar con el dispositivo."
        case .invalidResponse:
            return "El dispositivo devolvió una respuesta no válida."
        case let .remoteRejected(message):
            return message
        }
    }
}

extension Int64 {
    var fileSizeLabel: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: self)
    }
}