import Foundation
import Network

// Descubrimiento de pares LocalSend.
//
// Hallazgo importante de la Sprint 1: la especificación de LocalSend NO usa
// mDNS/Bonjour. Se verificó contra el repositorio oficial de la
// especificación y contra el cliente de referencia: no hay una sola
// referencia a NSD ni a Bonjour en su código. Esto contradice la suposición
// de la sección 6 del handoff, y por eso el `NWBrowser` sobre
// `_locdrop._tcp` del protocolo viejo no sirve para hablar con clientes de
// escritorio reales.
//
// El descubrimiento de verdad tiene dos vías:
//
//   1. Escaneo HTTP activo de la subred (la vía FIABLE). Se manda
//      `POST /api/localsend/v2/register` a cada IP candidata del subnet. Es
//      TCP normal y corriente: no necesita ningún entitlement especial.
//
//   2. Multicast UDP a 224.0.0.167:53317 (MEJOR ESFUERZO). En iOS el
//      multicast exige el entitlement restringido
//      `com.apple.developer.networking.multicast`, que Apple concede solo
//      previa solicitud justificada y que todavía no tenemos. Se intenta de
//      todas formas dentro de un do/catch que se traga el error: si Apple lo
//      bloquea, el escaneo de subred sigue funcionando por su cuenta y el
//      descubrimiento no se resiente.
//
// Ningún fichero de esta capa importa SwiftUI (regla de la sección 7).
actor Discovery {

    // Concurrencia acotada del escaneo: 254 conexiones TLS simultáneas
    // saturarían la pila de red del dispositivo y dispararían falsos
    // negativos por timeout. Con ~28 en vuelo el barrido de un /24 tarda
    // unos pocos segundos.
    private static let maxConcurrentProbes = 28

    private var scanTask: Task<Void, Never>?

    /// Se invoca por cada par que responde al escaneo.
    typealias PeerFound = @Sendable (LocalSendDeviceInfo, String) async -> Void

    // MARK: - Escaneo de subred

    /// Barre la subred local mandando `/register` a cada IP candidata.
    /// Devuelve cuando ha terminado el barrido completo.
    func scanSubnet(myInfo: LocalSendDeviceInfo, onPeer: @escaping PeerFound) async {
        let interfaces = LocalInterfaces.ipv4Interfaces()
        guard let interface = interfaces.first else { return }

        let candidates = LocalInterfaces.hostAddresses(for: interface)
        guard !candidates.isEmpty else { return }

        let port = myInfo.port ?? Int(LocalSendProtocol.defaultPort)

        await withTaskGroup(of: Void.self) { group in
            var index = 0
            var inFlight = 0

            while index < candidates.count {
                // Semáforo pobre pero suficiente: se mantienen como mucho
                // `maxConcurrentProbes` sondas vivas a la vez.
                if inFlight >= Self.maxConcurrentProbes {
                    await group.next()
                    inFlight -= 1
                }

                let host = candidates[index]
                index += 1
                inFlight += 1

                group.addTask {
                    guard let info = await HTTPClient.register(
                        host: host,
                        port: port,
                        myInfo: myInfo,
                        timeout: HTTPClient.scanTimeout
                    ) else { return }
                    await onPeer(info, host)
                }
            }

            await group.waitForAll()
        }
    }

    /// Lanza el escaneo en segundo plano, cancelando el anterior si lo hubiera.
    func startScan(myInfo: LocalSendDeviceInfo, onPeer: @escaping PeerFound) {
        scanTask?.cancel()
        scanTask = Task { [weak self] in
            await self?.scanSubnet(myInfo: myInfo, onPeer: onPeer)
        }
    }

    func stop() {
        scanTask?.cancel()
        scanTask = nil
    }

    // MARK: - Vía manual por IP

    /// Añadir un dispositivo a mano escribiendo su IP. Es la vía de respaldo
    /// de la sección 6 del handoff, para cuando el escaneo automático no
    /// llega: redes grandes recortadas por el límite de 256 direcciones,
    /// subredes distintas o Wi-Fi con aislamiento parcial de clientes.
    /// Usa un timeout más generoso que el escaneo porque aquí hay un humano
    /// esperando una respuesta concreta, no 254 sondas a ciegas.
    func probe(host: String, port: Int? = nil, myInfo: LocalSendDeviceInfo) async -> (LocalSendDeviceInfo, String)? {
        let target = port ?? Int(LocalSendProtocol.defaultPort)
        guard let info = await HTTPClient.register(
            host: host,
            port: target,
            myInfo: myInfo,
            timeout: HTTPClient.manualTimeout
        ) else { return nil }
        return (info, host)
    }

    // MARK: - Anuncio multicast (mejor esfuerzo)

    /// Manda un anuncio UDP al grupo multicast de LocalSend. Sin el
    /// entitlement de multicast iOS lo descarta; por eso no se comprueba el
    /// resultado ni se propaga ningún error. Si algún día llega el
    /// entitlement, esto empieza a funcionar solo y se suma como tercera vía.
    func announceMulticast(myInfo: LocalSendDeviceInfo) {
        var announcement = myInfo
        announcement.announce = true
        guard let payload = try? JSONEncoder().encode(announcement) else { return }

        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(LocalSendProtocol.multicastGroup),
            port: NWEndpoint.Port(rawValue: LocalSendProtocol.multicastPort) ?? .any
        )
        let connection = NWConnection(to: endpoint, using: .udp)
        connection.start(queue: DispatchQueue.global(qos: .utility))
        connection.send(content: payload, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}
