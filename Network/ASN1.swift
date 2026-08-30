import Foundation

// Codificador DER mínimo. No existe en iOS ninguna API pública para crear
// un certificado autofirmado ni un contenedor PKCS#12 desde cero (a
// diferencia de macOS, que sí tiene `SecIdentityCreateWithCertificate`),
// así que hay que construir el certificado X.509 y el .p12 a mano, byte a
// byte, y pasarlos por `SecPKCS12Import`. Es la única vía sin dependencias
// externas. Ver X509CertificateBuilder.swift y PKCS12Builder.swift.
enum DER {
    // Tags ASN.1 que usamos.
    static let tagInteger: UInt8 = 0x02
    static let tagBitString: UInt8 = 0x03
    static let tagOctetString: UInt8 = 0x04
    static let tagNull: UInt8 = 0x05
    static let tagObjectIdentifier: UInt8 = 0x06
    static let tagUTF8String: UInt8 = 0x0C
    static let tagPrintableString: UInt8 = 0x13
    static let tagUTCTime: UInt8 = 0x17
    static let tagSequence: UInt8 = 0x30
    static let tagSet: UInt8 = 0x31

    static func length(_ count: Int) -> [UInt8] {
        if count < 0x80 {
            return [UInt8(count)]
        }
        var bytes: [UInt8] = []
        var value = count
        while value > 0 {
            bytes.insert(UInt8(value & 0xFF), at: 0)
            value >>= 8
        }
        return [0x80 | UInt8(bytes.count)] + bytes
    }

    static func tlv(_ tag: UInt8, _ content: [UInt8]) -> [UInt8] {
        [tag] + length(content.count) + content
    }

    static func sequence(_ content: [UInt8]) -> [UInt8] { tlv(tagSequence, content) }
    static func set(_ content: [UInt8]) -> [UInt8] { tlv(tagSet, content) }

    // Contexto específico, constructed: [n] EXPLICIT ...
    static func explicit(_ n: UInt8, _ content: [UInt8]) -> [UInt8] {
        tlv(0xA0 | n, content)
    }

    static func integer(_ value: Int) -> [UInt8] {
        var v = value
        if v == 0 { return tlv(tagInteger, [0x00]) }
        var bytes: [UInt8] = []
        let isNegative = v < 0
        if isNegative { v = -v }
        while v > 0 {
            bytes.insert(UInt8(v & 0xFF), at: 0)
            v >>= 8
        }
        if !isNegative, let first = bytes.first, first & 0x80 != 0 {
            bytes.insert(0x00, at: 0)
        }
        return tlv(tagInteger, bytes)
    }

    /// INTEGER a partir de bytes sin signo ya calculados (p.ej. el número de
    /// serie), añadiendo el 0x00 de relleno si el bit alto queda a 1.
    static func integer(unsignedBytes bytes: [UInt8]) -> [UInt8] {
        var b = bytes
        if let first = b.first, first & 0x80 != 0 {
            b.insert(0x00, at: 0)
        }
        return tlv(tagInteger, b)
    }

    static func bitString(_ bytes: [UInt8], unusedBits: UInt8 = 0) -> [UInt8] {
        tlv(tagBitString, [unusedBits] + bytes)
    }

    static func octetString(_ bytes: [UInt8]) -> [UInt8] { tlv(tagOctetString, bytes) }

    static func null() -> [UInt8] { [tagNull, 0x00] }

    static func objectIdentifier(_ dotted: String) -> [UInt8] {
        let parts = dotted.split(separator: ".").compactMap { UInt(String($0)) }
        precondition(parts.count >= 2)
        var bytes: [UInt8] = [UInt8(parts[0] * 40 + parts[1])]
        for part in parts.dropFirst(2) {
            bytes.append(contentsOf: encodeBase128(part))
        }
        return tlv(tagObjectIdentifier, bytes)
    }

    private static func encodeBase128(_ value: UInt) -> [UInt8] {
        var v = value
        var chunks: [UInt8] = [UInt8(v & 0x7F)]
        v >>= 7
        while v > 0 {
            chunks.insert(UInt8(v & 0x7F) | 0x80, at: 0)
            v >>= 7
        }
        return chunks
    }

    static func printableString(_ string: String) -> [UInt8] {
        tlv(tagPrintableString, Array(string.utf8))
    }

    static func utf8String(_ string: String) -> [UInt8] {
        tlv(tagUTF8String, Array(string.utf8))
    }

    // Formato UTCTime: "YYMMDDHHmmssZ" (válido hasta 2049, de sobra aquí).
    static func utcTime(_ date: Date) -> [UInt8] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyMMddHHmmss'Z'"
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return tlv(tagUTCTime, Array(formatter.string(from: date).utf8))
    }
}
