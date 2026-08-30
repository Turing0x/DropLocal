import Foundation
import CryptoKit
import Security
import Network

// Identidad TLS del dispositivo: una clave EC P-256 y su certificado
// autofirmado, generados una vez y persistidos tal cual en el llavero.
//
// Importante: NO se regenera el certificado en cada arranque a partir de
// la clave. ECDSA firma con un nonce aleatorio, así que firmar el mismo
// certificado dos veces con la misma clave da bytes distintos cada vez
// (comprobado: dos regeneraciones seguidas con la misma clave y las mismas
// fechas dieron huellas distintas). Si la huella cambiase en cada arranque,
// LocalSend nunca podría "recordar" este dispositivo (Sprint 6). Por eso
// se guarda el DER del certificado ya firmado, no solo la clave.
enum TLSIdentity {
    private static let keychainService = "com.threedotsdev.nexo.tls-identity"
    private static let keychainAccount = "device-identity"
    private static let commonName = "Nexo"
    private static let validityYears = 10
    private static let keyLength = 32

    // `@unchecked Sendable`: los tres campos son inmutables y los tipos de
    // Security (`SecIdentity`, `SecCertificate`) son seguros de compartir
    // entre hilos; lo que el compilador no puede demostrar es la parte del
    // puente con CoreFoundation.
    struct Loaded: @unchecked Sendable {
        let secIdentity: SecIdentity
        let certificate: SecCertificate
        let fingerprint: String // sha256 hex, en minúsculas, sin separadores
    }

    // La identidad se calcula una vez por proceso y se cachea. Con
    // concurrencia estricta un `static var` suelto no vale (se consulta desde
    // el actor principal y desde las colas de `Network`), así que la caché va
    // detrás de un cerrojo.
    private static let cacheLock = NSLock()
    nonisolated(unsafe) private static var cached: Loaded?

    static func current() throws -> Loaded {
        cacheLock.lock()
        let existing = cached
        cacheLock.unlock()
        if let existing { return existing }

        let (privateKey, certificateDER) = try loadOrCreateIdentity()
        let fingerprint = SHA256.hash(data: certificateDER)
            .map { String(format: "%02x", $0) }
            .joined()

        let pkcs12 = PKCS12Builder.build(certificateDER: certificateDER, privateKey: privateKey)

        var importResult: CFArray?
        let status = SecPKCS12Import(
            pkcs12 as CFData,
            [kSecImportExportPassphrase as String: PKCS12Builder.importPassword] as CFDictionary,
            &importResult
        )
        guard status == errSecSuccess,
              let items = importResult as? [[String: Any]],
              let first = items.first,
              let identityRef = first[kSecImportItemIdentity as String] else {
            throw TLSIdentityError.importFailed(status)
        }
        let secIdentity = identityRef as! SecIdentity

        var certificate: SecCertificate?
        SecIdentityCopyCertificate(secIdentity, &certificate)
        guard let certificate else {
            throw TLSIdentityError.importFailed(status)
        }

        let loaded = Loaded(secIdentity: secIdentity, certificate: certificate, fingerprint: fingerprint)
        cacheLock.lock()
        cached = loaded
        cacheLock.unlock()
        return loaded
    }

    private static func loadOrCreateIdentity() throws -> (P256.Signing.PrivateKey, Data) {
        if let stored = readKeychainBlob(), stored.count > keyLength {
            let key = try P256.Signing.PrivateKey(rawRepresentation: stored.prefix(keyLength))
            let certificateDER = stored.suffix(from: keyLength)
            return (key, Data(certificateDER))
        }

        let key = P256.Signing.PrivateKey()
        let notBefore = Date()
        let notAfter = Calendar(identifier: .gregorian).date(byAdding: .year, value: validityYears, to: notBefore)!
        let certificateDER = try X509CertificateBuilder.makeSelfSignedCertificate(
            privateKey: key,
            commonName: commonName,
            notBefore: notBefore,
            notAfter: notAfter
        )

        try writeKeychainBlob(key.rawRepresentation + certificateDER)
        return (key, certificateDER)
    }

    private static func readKeychainBlob() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    private static func writeKeychainBlob(_ data: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
        ]
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw TLSIdentityError.keychainWriteFailed(status)
        }
    }
}

enum TLSIdentityError: LocalizedError {
    case importFailed(OSStatus)
    case keychainWriteFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .importFailed(let status):
            return "No se pudo importar la identidad TLS (SecPKCS12Import: \(status))."
        case .keychainWriteFailed(let status):
            return "No se pudo guardar la identidad TLS en el llavero (\(status))."
        }
    }
}
