import Foundation
import CryptoKit
import Network

// Cliente HTTP/1.1 mínimo sobre `NWConnection` con TLS.
//
// Por qué no `URLSession`: el handoff (sección 5) prohíbe expresamente
// `URLSession` para el transporte entre pares. Todo lo de red va por
// `Network.framework`, escrito a mano.
//
// Sobre la validación del certificado: se acepta CUALQUIER certificado del
// par sin comprobar cadena de confianza. No es un descuido — LocalSend usa
// certificados autofirmados y un modelo de confianza "primero se usa, luego
// se recuerda por huella" (así está descrito en el README de la propia
// especificación). Validar contra una CA haría imposible hablar con nadie.
// Lo que sí hacemos es capturar el certificado del par en el verify block
// para poder calcular su huella y compararla más adelante (Sprint 6,
// dispositivos de confianza).
enum HTTPClient {

    struct Response: Sendable {
        let statusCode: Int
        let body: Data
        // Huella SHA-256 del certificado que presentó el par, en hexadecimal
        // minúsculas. `nil` si no se pudo leer la cadena.
        let peerFingerprint: String?
    }

    enum ClientError: Error {
        case connectionFailed(String)
        case timedOut
        case malformedResponse
    }

    // Tiempo de espera corto a propósito: en el escaneo de subred se prueban
    // hasta 254 direcciones y la inmensa mayoría no tiene nada escuchando.
    // Un timeout largo convertiría el escaneo en minutos.
    static let scanTimeout: TimeInterval = 0.4
    static let manualTimeout: TimeInterval = 3.0

    /// `POST /api/localsend/v2/register` — anuncio y registro bidireccional.
    /// Es el mecanismo real de descubrimiento activo: si el par responde con
    /// un `LocalSendDeviceInfo` válido, es un dispositivo LocalSend.
    static func register(
        host: String,
        port: Int,
        myInfo: LocalSendDeviceInfo,
        timeout: TimeInterval
    ) async -> LocalSendDeviceInfo? {
        guard let payload = try? JSONEncoder().encode(myInfo) else { return nil }
        guard let response = try? await request(
            method: "POST",
            path: LocalSendProtocol.registerPath,
            host: host,
            port: port,
            body: payload,
            timeout: timeout
        ) else { return nil }

        guard response.statusCode == 200 else { return nil }
        return try? JSONDecoder().decode(LocalSendDeviceInfo.self, from: response.body)
    }

    /// Petición HTTP/1.1 genérica sobre TLS. Cierra la conexión al terminar
    /// (`Connection: close`), que es lo que espera el otro extremo.
    static func request(
        method: String,
        path: String,
        host: String,
        port: Int,
        body: Data,
        timeout: TimeInterval
    ) async throws -> Response {
        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(rawValue: UInt16(port)) ?? .init(integerLiteral: 53317)
        )

        let collector = PeerCertificateCollector()
        let parameters = NWParameters(tls: tlsOptions(collector: collector), tcp: tcpOptions())
        let connection = NWConnection(to: endpoint, using: parameters)

        var head = "\(method) \(path) HTTP/1.1\r\n"
        head += "Host: \(host):\(port)\r\n"
        head += "Content-Type: application/json\r\n"
        head += "Content-Length: \(body.count)\r\n"
        head += "Connection: close\r\n\r\n"
        var payload = Data(head.utf8)
        payload.append(body)

        let exchange = HTTPClientExchange(connection: connection, request: payload, timeout: timeout)
        let raw = try await exchange.run()
        guard let parsed = parseResponse(raw) else { throw ClientError.malformedResponse }

        return Response(
            statusCode: parsed.status,
            body: parsed.body,
            peerFingerprint: collector.fingerprint()
        )
    }

    private static func tcpOptions() -> NWProtocolTCP.Options {
        let options = NWProtocolTCP.Options()
        // Sin esto una IP muerta del subnet mantiene el SYN reintentándose
        // mucho más de lo que dura nuestro propio timeout.
        options.connectionTimeout = 2
        options.noDelay = true
        return options
    }

    private static func tlsOptions(collector: PeerCertificateCollector) -> NWProtocolTLS.Options {
        let options = NWProtocolTLS.Options()
        let security = options.securityProtocolOptions
        sec_protocol_options_set_min_tls_protocol_version(security, .TLSv12)

        // Aceptamos el certificado autofirmado del par (ver comentario de
        // cabecera) y de paso nos quedamos con su huella.
        sec_protocol_options_set_verify_block(
            security,
            { _, trust, complete in
                collector.capture(sec_trust_copy_ref(trust).takeRetainedValue())
                complete(true)
            },
            DispatchQueue.global(qos: .userInitiated)
        )
        return options
    }

    private static func parseResponse(_ data: Data) -> (status: Int, body: Data)? {
        guard let separator = data.range(of: Data("\r\n\r\n".utf8)) else { return nil }
        let headerText = String(decoding: data.subdata(in: 0..<separator.lowerBound), as: UTF8.self)
        guard let statusLine = headerText.components(separatedBy: "\r\n").first else { return nil }
        let parts = statusLine.split(separator: " ")
        guard parts.count >= 2, let status = Int(parts[1]) else { return nil }
        return (status, data.subdata(in: separator.upperBound..<data.count))
    }
}

// Caja segura para sacar el certificado del par desde el verify block, que
// corre en una cola propia de `Network`, hasta el código que lo espera.
final class PeerCertificateCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var certificateDER: Data?

    func capture(_ trust: SecTrust) {
        guard let chain = SecTrustCopyCertificateChain(trust) as? [SecCertificate],
              let leaf = chain.first else { return }
        let der = SecCertificateCopyData(leaf) as Data
        lock.lock()
        certificateDER = der
        lock.unlock()
    }

    func fingerprint() -> String? {
        lock.lock()
        let der = certificateDER
        lock.unlock()
        guard let der else { return nil }
        return SHA256.hash(data: der).map { String(format: "%02x", $0) }.joined()
    }
}
