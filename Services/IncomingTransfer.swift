import Foundation
import Network

// Bandera de una sola vía protegida por lock: varias colas de `Network`
// pueden intentar disparar el mismo evento de estado a la vez, y solo una
// puede ganar la carrera para reanudar la continuación.
final class OneShotFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var fired = false

    func tryFire() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if fired { return false }
        fired = true
        return true
    }
}

// Envuelve la recepción cruda de una transferencia entrante del protocolo viejo
// (`_locdrop._tcp`). Se sustituirá por el receptor del protocolo LocalSend en
// la Sprint 2; de momento solo se le arreglan los bugs #1/#4 de la auditoría.
//
// Se marca `@unchecked Sendable` porque, aunque no es un tipo inmutable, todo su
// estado mutable solo se toca desde los completion handlers de una única
// `NWConnection`, que `Network.framework` serializa en su cola: nunca hay dos
// accesos concurrentes reales, solo secuenciales.
final class IncomingTransfer: @unchecked Sendable {
    private let connection: NWConnection
    private let onComplete: @Sendable (URL) -> Void
    private var buffer = Data()
    private var headerParsed = false
    private var expectedBodyLength: Int64 = 0
    private var receivedBodyLength: Int64 = 0
    private var outputURL: URL?
    private var outputHandle: FileHandle?
    private var finished = false

    init(connection: NWConnection, onComplete: @escaping @Sendable (URL) -> Void) {
        self.connection = connection
        self.onComplete = onComplete
    }

    func receive() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data {
                self.buffer.append(data)
                self.consumeBuffer()
            }

            // Bug #4 de la auditoría: sin paréntesis explícitos, la precedencia de
            // `&&`/`||` hacía que esta condición no significara lo que parecía.
            let bodyComplete = self.receivedBodyLength >= self.expectedBodyLength && self.headerParsed
            if error != nil || isComplete || bodyComplete {
                self.finish()
            } else {
                self.receive()
            }
        }
    }

    private func consumeBuffer() {
        if !headerParsed {
            guard let separator = buffer.range(of: Data("\r\n\r\n".utf8)) else { return }
            let headerData = buffer.subdata(in: 0..<separator.lowerBound)
            let bodyStart = separator.upperBound
            buffer = buffer.subdata(in: bodyStart..<buffer.endIndex)
            parseHeaders(String(decoding: headerData, as: UTF8.self))
            headerParsed = true
        }

        guard headerParsed, let handle = outputHandle, !buffer.isEmpty else { return }
        let remaining = expectedBodyLength - receivedBodyLength
        let count = min(Int64(buffer.count), remaining)
        guard count > 0 else { return }
        let bodyChunk = buffer.prefix(Int(count))
        try? handle.write(contentsOf: Data(bodyChunk))
        receivedBodyLength += count
        buffer.removeFirst(Int(count))
    }

    private func parseHeaders(_ headers: String) {
        let lines = headers.components(separatedBy: "\r\n")
        var fileName = "archivo-recibido"
        for line in lines {
            let parts = line.split(separator: ":", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            let key = parts[0].lowercased()
            let value = parts[1].trimmingCharacters(in: .whitespaces)
            if key == "content-length" {
                expectedBodyLength = Int64(value) ?? 0
            } else if key == "x-file-name-base64", let data = Data(base64Encoded: value), let decoded = String(data: data, encoding: .utf8) {
                fileName = decoded
            }
        }

        let safeName = URL(fileURLWithPath: fileName).lastPathComponent
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Received", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = uniqueURL(directory.appendingPathComponent(safeName))
        FileManager.default.createFile(atPath: destination.path, contents: nil)
        outputURL = destination
        outputHandle = try? FileHandle(forWritingTo: destination)
    }

    // Bug #4 de la auditoría: `finish()` podía llamarse más de una vez (p. ej. un
    // `isComplete` seguido de un `error`) y cerraba dos veces el mismo FileHandle.
    // La bandera `finished` lo evita.
    private func finish() {
        guard !finished else { return }
        finished = true

        try? outputHandle?.close()
        if receivedBodyLength == expectedBodyLength, let outputURL {
            let response = "HTTP/1.1 200 OK\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
            connection.send(content: Data(response.utf8), completion: .contentProcessed { [weak self] _ in
                self?.connection.cancel()
            })
            onComplete(outputURL)
        } else {
            connection.cancel()
        }
    }

    private func uniqueURL(_ url: URL) -> URL {
        guard FileManager.default.fileExists(atPath: url.path) else { return url }
        let stem = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        let suffix = UUID().uuidString.prefix(6)
        let name = ext.isEmpty ? "\(stem)-\(suffix)" : "\(stem)-\(suffix).\(ext)"
        return url.deletingLastPathComponent().appendingPathComponent(name)
    }
}
