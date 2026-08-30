import Foundation
import Network

// Servidor HTTP/1.1 minimalista sobre TLS para el protocolo LocalSend.
// No es un servidor HTTP de propósito general (el handoff prohíbe traer
// una librería de servidor externa): solo entiende lo justo — método,
// ruta, cabeceras con Content-Length, cuerpo — para los dos endpoints que
// necesita la Sprint 1 (`/register`, `/info`). `/prepare-upload`,
// `/upload` y `/cancel` llegan en las Sprints 2 y 3.
@MainActor
final class HTTPServer {
    typealias RegisterHandler = @MainActor (_ remoteHost: String, _ info: LocalSendDeviceInfo) -> LocalSendDeviceInfo

    private var listener: NWListener?
    private let queue = DispatchQueue(label: "com.threedotsdev.nexo.httpserver")
    private var onRegister: RegisterHandler?

    // Sesiones en vuelo. Retenerlas aquí NO es opcional: `NWConnection` no
    // retiene al objeto que le pasa el closure de lectura, así que una sesión
    // creada como variable local se destruye en cuanto `accept` retorna y la
    // petición no llega a leerse nunca (la conexión completa el handshake TLS
    // y se queda muda hasta que el cliente agota su tiempo de espera).
    private var sessions: [UUID: HTTPServerSession] = [:]

    // Límite defensivo de la sección 8 del handoff: un par malicioso no debe
    // poder abrir cientos de conexiones y dejarlas colgadas.
    private static let maxConcurrentSessions = 16

    var isRunning: Bool { listener != nil }
    private(set) var boundPort: UInt16?

    func start(myInfo: @escaping @MainActor () -> LocalSendDeviceInfo, onRegister: @escaping RegisterHandler) throws {
        guard listener == nil else { return }
        self.onRegister = onRegister

        let identity = try TLSIdentity.current()
        guard let secIdentity = sec_identity_create(identity.secIdentity) else {
            throw TLSIdentityError.importFailed(errSecParam)
        }

        let tlsOptions = NWProtocolTLS.Options()
        sec_protocol_options_set_local_identity(tlsOptions.securityProtocolOptions, secIdentity)

        let params = NWParameters(tls: tlsOptions, tcp: NWProtocolTCP.Options())
        params.includePeerToPeer = true

        let port = NWEndpoint.Port(rawValue: LocalSendProtocol.defaultPort) ?? .any
        let listener = try NWListener(using: params, on: port)
        listener.newConnectionHandler = { [weak self] connection in
            Task { @MainActor in
                self?.accept(connection, myInfo: myInfo)
            }
        }
        listener.stateUpdateHandler = { [weak self] state in
            if case .ready = state {
                Task { @MainActor in self?.boundPort = listener.port?.rawValue }
            }
        }
        listener.start(queue: queue)
        self.listener = listener
    }

    // Si el servidor se destruye sin llamar a `stop()`, el `NWListener` sigue
    // vivo por su cuenta y deja el puerto 53317 ocupado aceptando conexiones
    // que ya no contesta nadie. Pasó de verdad durante las pruebas de esta
    // sprint; esto lo cierra por si acaso.
    deinit {
        listener?.cancel()
    }

    func stop() {
        listener?.cancel()
        listener = nil
        boundPort = nil
        sessions.removeAll()
    }

    private func accept(_ connection: NWConnection, myInfo: @escaping @MainActor () -> LocalSendDeviceInfo) {
        guard sessions.count < Self.maxConcurrentSessions else {
            connection.cancel()
            return
        }

        let remoteHost = HTTPServer.remoteHost(of: connection)
        connection.start(queue: queue)

        let sessionID = UUID()
        let session = HTTPServerSession(
            connection: connection,
            onRequest: { [weak self] request in
                Task { @MainActor in
                    self?.handle(request, remoteHost: remoteHost, myInfo: myInfo, connection: connection)
                }
            },
            onFinish: { [weak self] in
                Task { @MainActor in
                    self?.sessions.removeValue(forKey: sessionID)
                }
            }
        )
        sessions[sessionID] = session
        session.receive()
    }

    private func handle(
        _ request: HTTPRequest,
        remoteHost: String,
        myInfo: @escaping @MainActor () -> LocalSendDeviceInfo,
        connection: NWConnection
    ) {
        let decoder = JSONDecoder()
        let encoder = JSONEncoder()

        switch (request.method, request.path) {
        case ("POST", LocalSendProtocol.registerPath):
            guard let peerInfo = try? decoder.decode(LocalSendDeviceInfo.self, from: request.body) else {
                HTTPServerSession.respond(.badRequest, on: connection)
                return
            }
            let ourInfo = onRegister?(remoteHost, peerInfo) ?? myInfo()
            let body = (try? encoder.encode(ourInfo)) ?? Data()
            HTTPServerSession.respond(.ok, body: body, on: connection)

        case ("GET", LocalSendProtocol.infoPath):
            let body = (try? encoder.encode(myInfo())) ?? Data()
            HTTPServerSession.respond(.ok, body: body, on: connection)

        default:
            HTTPServerSession.respond(.notFound, on: connection)
        }
    }

    private static func remoteHost(of connection: NWConnection) -> String {
        guard case let .hostPort(host, _) = connection.endpoint else { return "?" }
        switch host {
        case .ipv4(let address): return address.debugDescription
        case .ipv6(let address): return address.debugDescription
        default: return "\(host)"
        }
    }
}
