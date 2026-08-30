import Foundation
import Observation
import UIKit

// Estado de descubrimiento para la interfaz. Une las dos direcciones del
// registro LocalSend en una sola lista:
//
//   - saliente: nosotros escaneamos la subred y encontramos pares;
//   - entrante: un par nos encuentra a NOSOTROS y nos manda su
//     `POST /register`, que atiende `HTTPServer` y desemboca aquí mismo.
//
// Las dos vías acaban en `upsert`, deduplicando por huella, de modo que da
// igual quién descubriera a quién: el dispositivo aparece una sola vez.
@MainActor
@Observable
final class DiscoveryStore {

    private(set) var devices: [Device] = []
    private(set) var isScanning = false
    private(set) var lastError: String?

    private let server = HTTPServer()
    private let discovery = Discovery()
    private var scanLoop: Task<Void, Never>?

    // Cada cuánto se repite el barrido de subred. Los pares aparecen y
    // desaparecen (portátiles que se suspenden, móviles que bloquean
    // pantalla), así que un único escaneo al arrancar no basta.
    private static let rescanInterval: Duration = .seconds(15)

    var myFingerprint: String? {
        try? TLSIdentity.current().fingerprint
    }

    /// Nuestra propia ficha, la que se manda en cada `/register` saliente y
    /// la que se devuelve en `/info` y en los `/register` entrantes.
    var myInfo: LocalSendDeviceInfo {
        LocalSendDeviceInfo(
            alias: UIDevice.current.name,
            version: LocalSendProtocol.version,
            deviceModel: UIDevice.current.model,
            deviceType: .mobile,
            fingerprint: (try? TLSIdentity.current().fingerprint) ?? "",
            port: Int(LocalSendProtocol.defaultPort),
            protocolName: "https",
            // `download` es la Download API de la sección 5 de la
            // especificación (servir ficheros por HTTP para que el par tire
            // de ellos). No está implementada, así que se anuncia en falso:
            // prometerla y no cumplirla rompería a los clientes de escritorio.
            download: false,
            announce: nil
        )
    }

    // MARK: - Ciclo de vida

    func start() {
        guard scanLoop == nil else { return }

        do {
            try server.start(
                myInfo: { [weak self] in
                    self?.myInfo ?? LocalSendDeviceInfo(
                        alias: "Nexo", version: LocalSendProtocol.version,
                        deviceModel: nil, deviceType: .mobile, fingerprint: "",
                        port: nil, protocolName: "https", download: false, announce: nil
                    )
                },
                onRegister: { [weak self] remoteHost, peerInfo in
                    // Un par nos ha encontrado. Se registra igual que si lo
                    // hubiéramos encontrado nosotros y se le devuelve nuestra
                    // ficha, que es lo que exige el protocolo.
                    self?.upsert(from: peerInfo, host: remoteHost)
                    return self?.myInfo ?? peerInfo
                }
            )
        } catch {
            lastError = error.localizedDescription
        }

        let info = myInfo
        Task { await discovery.announceMulticast(myInfo: info) }

        scanLoop = Task { [weak self] in
            while !Task.isCancelled {
                await self?.runScan()
                try? await Task.sleep(for: Self.rescanInterval)
            }
        }
    }

    func stop() {
        scanLoop?.cancel()
        scanLoop = nil
        Task { await discovery.stop() }
        server.stop()
        isScanning = false
    }

    // MARK: - Escaneo

    func runScan() async {
        guard !isScanning else { return }
        isScanning = true
        let info = myInfo
        await discovery.scanSubnet(myInfo: info) { [weak self] peerInfo, host in
            await self?.upsert(from: peerInfo, host: host)
        }
        isScanning = false
    }

    /// Vía de respaldo: el usuario escribe una IP a mano.
    /// Devuelve `true` si había un dispositivo LocalSend en esa dirección.
    @discardableResult
    func addManually(host: String) async -> Bool {
        let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        let info = myInfo
        guard let (peerInfo, resolvedHost) = await discovery.probe(host: trimmed, myInfo: info) else {
            lastError = "No hay ningún dispositivo LocalSend en \(trimmed)."
            return false
        }
        upsert(from: peerInfo, host: resolvedHost)
        lastError = nil
        return true
    }

    // MARK: - Registro

    /// Punto único de entrada a la lista, venga el par del escaneo saliente o
    /// de un `/register` entrante. Deduplica por huella y refresca `lastSeen`.
    func upsert(from info: LocalSendDeviceInfo, host: String) {
        guard !info.fingerprint.isEmpty else { return }
        // Nunca nos listamos a nosotros mismos: el escaneo se cruza con
        // nuestra propia IP en cuanto hay más de una interfaz activa.
        guard info.fingerprint != myFingerprint else { return }

        let device = Device(
            fingerprint: info.fingerprint,
            alias: info.alias,
            deviceModel: info.deviceModel,
            deviceType: info.deviceType,
            host: host,
            port: info.port ?? Int(LocalSendProtocol.defaultPort),
            useHTTPS: (info.protocolName ?? "https").lowercased() == "https",
            lastSeen: Date()
        )

        if let index = devices.firstIndex(where: { $0.fingerprint == device.fingerprint }) {
            devices[index] = device
        } else {
            devices.append(device)
        }
        devices.sort { $0.alias.localizedCaseInsensitiveCompare($1.alias) == .orderedAscending }
    }
}
