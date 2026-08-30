import Foundation
import Darwin

// Enumeración de las IPv4 locales y cálculo del rango de hosts de la subred,
// vía `getifaddrs`. No hay API pública en `Network.framework` que dé la
// máscara de red de la interfaz, así que se baja a POSIX.
enum LocalInterfaces {

    struct IPv4Interface: Sendable {
        let name: String        // "en0", "en1", "pdp_ip0"...
        let address: String     // "192.168.1.42"
        let netmask: String     // "255.255.255.0"

        // La Wi-Fi es `en0` en un iPhone. Se prioriza porque la transferencia
        // local pasa por ahí; `pdp_ip0` (datos móviles) no sirve para esto.
        var isLikelyWiFi: Bool { name == "en0" }
    }

    /// Todas las IPv4 no-loopback del dispositivo, con la Wi-Fi primero.
    static func ipv4Interfaces() -> [IPv4Interface] {
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return [] }
        defer { freeifaddrs(head) }

        var found: [IPv4Interface] = []
        var cursor: UnsafeMutablePointer<ifaddrs>? = first

        while let entry = cursor {
            defer { cursor = entry.pointee.ifa_next }

            let flags = Int32(entry.pointee.ifa_flags)
            guard flags & IFF_UP == IFF_UP, flags & IFF_LOOPBACK == 0 else { continue }
            guard let rawAddress = entry.pointee.ifa_addr,
                  rawAddress.pointee.sa_family == UInt8(AF_INET),
                  let rawMask = entry.pointee.ifa_netmask else { continue }

            guard let address = presentation(of: rawAddress),
                  let netmask = presentation(of: rawMask) else { continue }

            found.append(IPv4Interface(
                name: String(cString: entry.pointee.ifa_name),
                address: address,
                netmask: netmask
            ))
        }

        return found.sorted { lhs, rhs in
            if lhs.isLikelyWiFi != rhs.isLikelyWiFi { return lhs.isLikelyWiFi }
            return lhs.name < rhs.name
        }
    }

    private static func presentation(of address: UnsafeMutablePointer<sockaddr>) -> String? {
        var storage = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        let result = getnameinfo(
            address,
            socklen_t(address.pointee.sa_len),
            &storage,
            socklen_t(storage.count),
            nil,
            0,
            NI_NUMERICHOST
        )
        guard result == 0 else { return nil }
        // `getnameinfo` deja una cadena C: hay que cortar en el terminador
        // nulo antes de decodificar (`String(cString:)` está obsoleto).
        let bytes = storage.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        return String(decoding: bytes, as: UTF8.self)
    }

    /// Direcciones de host candidatas de la subred de `interface`, excluyendo
    /// la propia, la de red y la de difusión.
    ///
    /// La máscara se toma de `getifaddrs`, no se asume /24: hay routers
    /// domésticos con /23 y redes de oficina con /16. Ahora bien, un /16 son
    /// 65.534 direcciones y escanearlas sería absurdo, así que el resultado
    /// se recorta a `limit`. En una red así de grande el escaneo automático
    /// no va a encontrar al par y el usuario tendrá que usar la vía manual
    /// por IP — es una limitación asumida, no un fallo silencioso.
    static func hostAddresses(for interface: IPv4Interface, limit: Int = 256) -> [String] {
        guard let address = packedIPv4(interface.address),
              let mask = packedIPv4(interface.netmask), mask != 0 else { return [] }

        let network = address & mask
        let broadcast = network | ~mask
        guard broadcast > network + 1 else { return [] }

        var candidates: [String] = []
        candidates.reserveCapacity(min(limit, Int(broadcast - network - 1)))

        var current = network + 1
        while current < broadcast, candidates.count < limit {
            if current != address {
                candidates.append(unpackedIPv4(current))
            }
            current += 1
        }
        return candidates
    }

    static func packedIPv4(_ text: String) -> UInt32? {
        let parts = text.split(separator: ".")
        guard parts.count == 4 else { return nil }
        var value: UInt32 = 0
        for part in parts {
            guard let octet = UInt32(part), octet <= 255 else { return nil }
            value = (value << 8) | octet
        }
        return value
    }

    static func unpackedIPv4(_ value: UInt32) -> String {
        "\((value >> 24) & 0xFF).\((value >> 16) & 0xFF).\((value >> 8) & 0xFF).\(value & 0xFF)"
    }
}
