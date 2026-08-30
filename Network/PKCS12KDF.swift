import Foundation
import CryptoKit

// Derivación de claves de PKCS#12 (RFC 7292, Apéndice B). No es PBKDF2: es
// un esquema propio basado en SHA-1 puro, así que no vale reutilizar nada
// de CryptoKit salvo el propio hash. Se usa solo para la huella de
// integridad del contenedor (MacData) — el certificado y la clave van sin
// cifrar dentro (ver PKCS12Builder.swift), así que esto es lo único que
// necesita esta derivación.
enum PKCS12KDF {
    private static let u = 20 // longitud de salida de SHA-1, en bytes
    private static let v = 64 // tamaño de bloque de entrada de SHA-1, en bytes

    static func deriveMacKey(password: String, salt: Data, iterations: Int, outputLength: Int) -> Data {
        derive(idByte: 3, password: password, salt: salt, iterations: iterations, outputLength: outputLength)
    }

    static func deriveEncryptionKey(password: String, salt: Data, iterations: Int, outputLength: Int) -> Data {
        derive(idByte: 1, password: password, salt: salt, iterations: iterations, outputLength: outputLength)
    }

    static func deriveIV(password: String, salt: Data, iterations: Int, outputLength: Int) -> Data {
        derive(idByte: 2, password: password, salt: salt, iterations: iterations, outputLength: outputLength)
    }

    private static func derive(idByte: UInt8, password: String, salt: Data, iterations: Int, outputLength: Int) -> Data {
        let passwordBytes = bmpString(password)
        let diversifier = [UInt8](repeating: idByte, count: v)

        func fill(_ bytes: [UInt8], to length: Int) -> [UInt8] {
            guard !bytes.isEmpty else { return [] }
            var result: [UInt8] = []
            while result.count < length {
                result.append(contentsOf: bytes)
            }
            return Array(result.prefix(length))
        }

        let saltBlock = fill(Array(salt), to: ((salt.count + v - 1) / v) * v)
        let passwordBlock = fill(passwordBytes, to: ((passwordBytes.count + v - 1) / v) * v)
        var i = saltBlock + passwordBlock

        var output: [UInt8] = []
        while output.count < outputLength {
            var a = Array(Insecure.SHA1.hash(data: diversifier + i))
            for _ in 1..<max(iterations, 1) {
                a = Array(Insecure.SHA1.hash(data: a))
            }
            output.append(contentsOf: a)

            guard output.count < outputLength, !i.isEmpty else { break }
            let b = fill(a, to: v)
            // I_j = (I_j + B + 1) mod 2^v (RFC 7292, Apéndice B.2, paso 6.C
            // — el "+1" es fácil de perder leyendo por encima y hace que la
            // clave derivada no coincida con ninguna otra implementación).
            // Se aplica como acarreo de entrada 1 en el byte menos
            // significativo, que se propaga igual que un acarreo normal.
            let blockCount = i.count / v
            for blockIndex in 0..<blockCount {
                var carry: UInt16 = 1
                let start = blockIndex * v
                for offset in stride(from: v - 1, through: 0, by: -1) {
                    let sum = UInt16(i[start + offset]) + UInt16(b[offset]) + carry
                    i[start + offset] = UInt8(sum & 0xFF)
                    carry = sum >> 8
                }
            }
        }

        return Data(output.prefix(outputLength))
    }

    /// BMPString: UTF-16BE con terminador nulo, como exige el Apéndice B.
    private static func bmpString(_ string: String) -> [UInt8] {
        var bytes: [UInt8] = []
        for scalar in string.unicodeScalars {
            let value = UInt16(scalar.value & 0xFFFF)
            bytes.append(UInt8(value >> 8))
            bytes.append(UInt8(value & 0xFF))
        }
        bytes.append(0x00)
        bytes.append(0x00)
        return bytes
    }
}
