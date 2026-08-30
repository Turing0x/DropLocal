import Foundation
import Network

struct HTTPRequest {
    let method: String
    let path: String
    let headers: [String: String]
    let body: Data
}

enum HTTPStatus {
    case ok, badRequest, notFound, forbidden

    var line: String {
        switch self {
        case .ok: return "200 OK"
        case .badRequest: return "400 Bad Request"
        case .notFound: return "404 Not Found"
        case .forbidden: return "403 Forbidden"
        }
    }
}

// Lee una petición HTTP/1.1 completa (cabeceras + cuerpo por
// Content-Length) de una conexión y la entrega una única vez. Pensado para
// peticiones pequeñas de JSON (registro, metadatos) — la subida de
// ficheros por streaming es cosa de `Receiver.swift` en la Sprint 2, no de
// este router.
final class HTTPServerSession: @unchecked Sendable {
    private let connection: NWConnection
    private let onRequest: @Sendable (HTTPRequest) -> Void
    // Se dispara una única vez cuando la sesión deja de leer (petición
    // entregada, error o cierre del par). `HTTPServer` lo usa para soltar la
    // referencia fuerte que mantiene viva a esta sesión; sin ese aviso las
    // sesiones se acumularían hasta agotar el límite de conexiones.
    private let onFinish: @Sendable () -> Void
    private var finished = false
    private var buffer = Data()
    private var headerParsed = false
    private var method = ""
    private var path = ""
    private var headers: [String: String] = [:]
    private var expectedBodyLength = 0
    private var delivered = false

    // Límite defensivo: una petición de registro/metadatos nunca necesita
    // más que unos pocos KB. Evita que un par malicioso agote memoria
    // mandando un Content-Length gigante a un endpoint que no es de subida.
    private static let maxBodyLength = 1 * 1024 * 1024

    init(
        connection: NWConnection,
        onRequest: @escaping @Sendable (HTTPRequest) -> Void,
        onFinish: @escaping @Sendable () -> Void
    ) {
        self.connection = connection
        self.onRequest = onRequest
        self.onFinish = onFinish
    }

    func receive() {
        // Ojo: el closure captura `self` con fuerza a propósito. La sesión
        // también la retiene `HTTPServer` mientras dura, pero mantenerla viva
        // aquí durante la lectura evita que una carrera entre el `onFinish` y
        // el siguiente `receive` deje la petición a medio leer.
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { data, _, isComplete, error in
            if let data { self.buffer.append(data) }
            self.consumeBuffer()

            if self.delivered || error != nil || isComplete {
                self.finish()
                return
            }
            self.receive()
        }
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        onFinish()
    }

    private func consumeBuffer() {
        guard !delivered else { return }

        if !headerParsed {
            guard let separatorRange = buffer.range(of: Data("\r\n\r\n".utf8)) else { return }
            let headerData = buffer.subdata(in: 0..<separatorRange.lowerBound)
            buffer.removeSubrange(0..<separatorRange.upperBound)
            parseHeaders(String(decoding: headerData, as: UTF8.self))
            headerParsed = true

            guard expectedBodyLength <= Self.maxBodyLength else {
                Self.respond(.badRequest, on: connection)
                delivered = true
                return
            }
        }

        guard headerParsed, buffer.count >= expectedBodyLength else { return }
        delivered = true
        let body = buffer.prefix(expectedBodyLength)
        onRequest(HTTPRequest(method: method, path: path, headers: headers, body: Data(body)))
    }

    private func parseHeaders(_ raw: String) {
        var lines = raw.components(separatedBy: "\r\n")
        guard !lines.isEmpty else { return }
        let requestLine = lines.removeFirst().split(separator: " ")
        if requestLine.count >= 2 {
            method = String(requestLine[0])
            path = String(requestLine[1])
        }

        for line in lines {
            let parts = line.split(separator: ":", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            headers[parts[0].trimmingCharacters(in: .whitespaces).lowercased()] = parts[1].trimmingCharacters(in: .whitespaces)
        }
        expectedBodyLength = Int(headers["content-length"] ?? "0") ?? 0
    }

    static func respond(_ status: HTTPStatus, body: Data = Data(), on connection: NWConnection) {
        var response = "HTTP/1.1 \(status.line)\r\n"
        response += "Content-Type: application/json\r\n"
        response += "Content-Length: \(body.count)\r\n"
        response += "Connection: close\r\n\r\n"

        var data = Data(response.utf8)
        data.append(body)
        connection.send(content: data, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}
