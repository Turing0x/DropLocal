import Foundation
import CryptoKit

// Construye un certificado X.509 autofirmado (ECDSA P-256 / SHA-256) a
// partir de una clave sin pasar por una CA ni por OpenSSL. Determinista:
// la misma clave y el mismo `notBefore` producen siempre el mismo DER, y
// por tanto la misma huella (sha256 del certificado) — necesario para que
// el "dispositivo de confianza" de la Sprint 6 pueda reconocer al mismo
// iPhone entre arranques de la app.
enum X509CertificateBuilder {
    private static let oidECPublicKey = "1.2.840.10045.2.1"
    private static let oidPrime256v1 = "1.2.840.10045.3.1.7"
    private static let oidEcdsaWithSHA256 = "1.2.840.10045.4.3.2"
    private static let oidCommonName = "2.5.4.3"

    static func makeSelfSignedCertificate(
        privateKey: P256.Signing.PrivateKey,
        commonName: String,
        notBefore: Date,
        notAfter: Date
    ) throws -> Data {
        let publicKeyPoint = privateKey.publicKey.x963Representation

        let serialHash = SHA256.hash(data: publicKeyPoint)
        let serialBytes = Array(serialHash.prefix(8))

        let signatureAlgorithmID = DER.sequence(DER.objectIdentifier(oidEcdsaWithSHA256))
        let name = makeName(commonName: commonName)

        let subjectPublicKeyInfo = DER.sequence(
            DER.sequence(DER.objectIdentifier(oidECPublicKey) + DER.objectIdentifier(oidPrime256v1))
                + DER.bitString(Array(publicKeyPoint))
        )

        let validity = DER.sequence(DER.utcTime(notBefore) + DER.utcTime(notAfter))

        let tbsCertificate = DER.sequence(
            DER.explicit(0, DER.integer(2)) // version v3
                + DER.integer(unsignedBytes: serialBytes)
                + signatureAlgorithmID
                + name // issuer
                + validity
                + name // subject (autofirmado: issuer == subject)
                + subjectPublicKeyInfo
        )

        let signature = try privateKey.signature(for: Data(tbsCertificate))

        let certificate = DER.sequence(
            tbsCertificate
                + signatureAlgorithmID
                + DER.bitString(Array(signature.derRepresentation))
        )

        return Data(certificate)
    }

    private static func makeName(commonName: String) -> [UInt8] {
        let attribute = DER.sequence(DER.objectIdentifier(oidCommonName) + DER.utf8String(commonName))
        return DER.sequence(DER.set(attribute))
    }
}
