import Foundation
import CryptoKit

// Empaqueta certificado + clave privada en un .p12 para pasarlo a
// `SecPKCS12Import`, el único punto de entrada que tiene iOS para obtener
// un `SecIdentity` (a diferencia de macOS, iOS no permite construir uno a
// partir de un certificado y una clave sueltos en el llavero).
//
// Va "sin cifrar" por dentro (certificado y clave en texto plano dentro del
// contenedor): el .p12 se genera en memoria, se usa una vez para importar y
// se descarta en el acto — nunca toca disco ni sale del proceso — así que
// no hay nada que proteger ahí. Solo se firma con un MAC de integridad
// (HMAC-SHA1, tal como exige RFC 7292) para que `SecPKCS12Import` lo acepte.
enum PKCS12Builder {
    private static let oidPKCS7Data = "1.2.840.113549.1.7.1"
    private static let oidCertBag = "1.2.840.113549.1.12.10.1.3"
    private static let oidShroudedKeyBag = "1.2.840.113549.1.12.10.1.2"
    private static let oidX509Certificate = "1.2.840.113549.1.9.22.1"
    private static let oidSHA1 = "1.3.14.3.2.26"
    private static let oidECPublicKey = "1.2.840.10045.2.1"
    private static let oidPrime256v1 = "1.2.840.10045.3.1.7"
    private static let oidPbeWithSHA1And3KeyTripleDESCBC = "1.2.840.113549.1.12.1.3"
    private static let oidLocalKeyID = "1.2.840.113549.1.9.21"

    static let importPassword = "nexo"
    private static let macIterations = 2048
    private static let keyIterations = 2048

    static func build(certificateDER: Data, privateKey: P256.Signing.PrivateKey) -> Data {
        // `SecPKCS12Import` empareja certificado y clave por este atributo:
        // sin un `localKeyId` idéntico en los dos bags, importa el
        // certificado pero no arma ninguna identidad (comprobado en este
        // mismo Mac contra `SecPKCS12Import` — con MAC válido y la clave
        // descifrando correctamente, seguía sin aparecer `kSecImportItemIdentity`
        // hasta añadir esto). El valor en sí es arbitrario; solo debe coincidir.
        let localKeyID = Array(Insecure.SHA1.hash(data: privateKey.publicKey.x963Representation))
        let bagAttributes = DER.set(
            DER.sequence(DER.objectIdentifier(oidLocalKeyID) + DER.set(DER.octetString(localKeyID)))
        )

        let certBag = DER.sequence(
            DER.objectIdentifier(oidCertBag)
                + DER.explicit(0, DER.sequence(
                    DER.objectIdentifier(oidX509Certificate)
                        + DER.explicit(0, DER.octetString(Array(certificateDER)))
                ))
                + bagAttributes
        )

        let keyBag = DER.sequence(
            DER.objectIdentifier(oidShroudedKeyBag)
                + DER.explicit(0, encryptedPrivateKeyInfo(privateKey))
                + bagAttributes
        )

        let safeContents = DER.sequence(certBag + keyBag)

        let dataContentInfo = { (payload: [UInt8]) -> [UInt8] in
            DER.sequence(
                DER.objectIdentifier(oidPKCS7Data)
                    + DER.explicit(0, DER.octetString(payload))
            )
        }

        let authenticatedSafe = DER.sequence(dataContentInfo(safeContents))
        let authSafeContentInfo = dataContentInfo(authenticatedSafe)

        let macSalt = randomBytes(8)
        let macKey = PKCS12KDF.deriveMacKey(
            password: importPassword,
            salt: Data(macSalt),
            iterations: macIterations,
            outputLength: 20
        )
        let digest = HMAC<Insecure.SHA1>.authenticationCode(
            for: Data(authenticatedSafe),
            using: SymmetricKey(data: macKey)
        )

        let macData = DER.sequence(
            DER.sequence( // DigestInfo
                DER.sequence(DER.objectIdentifier(oidSHA1) + DER.null())
                    + DER.octetString(Array(digest))
            )
                + DER.octetString(macSalt)
                + DER.integer(macIterations)
        )

        let pfx = DER.sequence(
            DER.integer(3)
                + authSafeContentInfo
                + macData
        )

        return Data(pfx)
    }

    /// EncryptedPrivateKeyInfo (PKCS#8): el PrivateKeyInfo de la clave EC,
    /// cifrado con pbeWithSHA1And3-KeyTripleDES-CBC — el algoritmo que
    /// `SecPKCS12Import` sabe reconocer y emparejar con el certificado en
    /// una identidad. Un keyBag sin cifrar se ignora silenciosamente
    /// (comprobado contra `SecPKCS12Import` en este mismo Mac: el import
    /// devuelve el certificado pero ninguna identidad).
    private static func encryptedPrivateKeyInfo(_ privateKey: P256.Signing.PrivateKey) -> [UInt8] {
        let plaintext = Data(privateKeyInfo(privateKey))
        let salt = randomBytes(8)
        let saltData = Data(salt)
        let key = PKCS12KDF.deriveEncryptionKey(password: importPassword, salt: saltData, iterations: keyIterations, outputLength: 24)
        let iv = PKCS12KDF.deriveIV(password: importPassword, salt: saltData, iterations: keyIterations, outputLength: 8)
        let encrypted = PBE3DES.encrypt(plaintext, key: key, iv: iv)

        let algorithmParams = DER.sequence(DER.octetString(salt) + DER.integer(keyIterations))
        let algorithmIdentifier = DER.sequence(DER.objectIdentifier(oidPbeWithSHA1And3KeyTripleDESCBC) + algorithmParams)

        return DER.sequence(algorithmIdentifier + DER.octetString(Array(encrypted)))
    }

    /// PrivateKeyInfo (PKCS#8), sin cifrar, para una clave EC P-256.
    private static func privateKeyInfo(_ privateKey: P256.Signing.PrivateKey) -> [UInt8] {
        let ecParams = DER.explicit(0, DER.objectIdentifier(oidPrime256v1))
        let publicKeyBits = DER.explicit(1, DER.bitString(Array(privateKey.publicKey.x963Representation)))
        let ecPrivateKey = DER.sequence(
            DER.integer(1)
                + DER.octetString(Array(privateKey.rawRepresentation))
                + ecParams
                + publicKeyBits
        )

        return DER.sequence(
            DER.integer(0)
                + DER.sequence(DER.objectIdentifier(oidECPublicKey) + DER.objectIdentifier(oidPrime256v1))
                + DER.octetString(ecPrivateKey)
        )
    }

    private static func randomBytes(_ count: Int) -> [UInt8] {
        (0..<count).map { _ in UInt8.random(in: 0...255) }
    }
}
