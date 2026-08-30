import Foundation
import CommonCrypto

// Cifra con pbeWithSHA1And3-KeyTripleDES-CBC (RFC 7292 / PKCS#12), el
// algoritmo clásico que exige el formato para "envolver" la clave privada
// dentro del .p12. CryptoKit no expone cifradores de bloque en modo CBC
// (solo AEAD), así que aquí hace falta `CommonCrypto` — es una librería del
// sistema (parte del SDK, sin añadir ningún paquete), usada únicamente
// para este contenedor de paso que se descarta tras `SecPKCS12Import`.
enum PBE3DES {
    static func encrypt(_ plaintext: Data, key: Data, iv: Data) -> Data {
        precondition(key.count == kCCKeySize3DES, "clave 3DES debe tener 24 bytes")
        precondition(iv.count == kCCBlockSize3DES, "IV 3DES debe tener 8 bytes")

        var outLength = 0
        var output = Data(count: plaintext.count + kCCBlockSize3DES)
        let status = output.withUnsafeMutableBytes { outBytes -> CCCryptorStatus in
            key.withUnsafeBytes { keyBytes in
                iv.withUnsafeBytes { ivBytes in
                    plaintext.withUnsafeBytes { inBytes in
                        CCCrypt(
                            CCOperation(kCCEncrypt),
                            CCAlgorithm(kCCAlgorithm3DES),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyBytes.baseAddress, key.count,
                            ivBytes.baseAddress,
                            inBytes.baseAddress, plaintext.count,
                            outBytes.baseAddress, outBytes.count,
                            &outLength
                        )
                    }
                }
            }
        }
        precondition(status == kCCSuccess, "fallo cifrando el keyBag del PKCS#12 (\(status))")
        return output.prefix(outLength)
    }
}
