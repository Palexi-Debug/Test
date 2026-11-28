import Foundation
import CommonCrypto
import CryptoKit
import Security

/// Portierung von `Cryptor` aus liblanis: RSA-Handshake und AES (OpenSSL-Format
/// "Salted__", Schlüsselableitung wie EVP_BytesToKey mit MD5).
enum LanisCrypto {
    static let passphraseSize = 46

    static func randomBytes(_ n: Int) -> Data {
        var b = [UInt8](repeating: 0, count: n)
        _ = SecRandomCopyBytes(kSecRandomDefault, n, &b)
        return Data(b)
    }

    private static func md5(_ d: Data) -> Data {
        Data(Insecure.MD5.hash(data: d))
    }

    /// Schlüssel (32 Byte) und IV (16 Byte) aus Passphrase und Salt.
    static func bytesToKeys(salt: Data, passphrase: Data) -> (key: Data, iv: Data) {
        var hashes = Data()
        var current = Data()
        while hashes.count < 48 {
            var input = Data()
            if !current.isEmpty { input.append(current) }
            input.append(passphrase)
            input.append(salt)
            current = md5(input)
            hashes.append(current)
        }
        return (hashes.subdata(in: 0..<32), hashes.subdata(in: 32..<48))
    }

    private static func aes(_ op: Int, data: Data, key: Data, iv: Data) -> Data? {
        var out = Data(count: data.count + kCCBlockSizeAES128)
        let outCapacity = out.count
        var moved = 0
        let status: CCCryptorStatus = out.withUnsafeMutableBytes { outPtr in
            data.withUnsafeBytes { dataPtr in
                key.withUnsafeBytes { keyPtr in
                    iv.withUnsafeBytes { ivPtr in
                        CCCrypt(CCOperation(op), CCAlgorithm(kCCAlgorithmAES),
                                CCOptions(kCCOptionPKCS7Padding),
                                keyPtr.baseAddress, key.count,
                                ivPtr.baseAddress,
                                dataPtr.baseAddress, data.count,
                                outPtr.baseAddress, outCapacity, &moved)
                    }
                }
            }
        }
        guard status == CCCryptorStatus(kCCSuccess) else { return nil }
        return out.prefix(moved)
    }

    /// Entschlüsselt Base64-Text im "Salted__"-Format.
    static func decrypt(_ base64: String, passphrase: Data) -> Data? {
        guard let raw = Data(base64Encoded: base64.trimmingCharacters(in: .whitespacesAndNewlines)),
              raw.count > 16,
              raw.prefix(8) == Data("Salted__".utf8) else { return nil }
        let salt = raw.subdata(in: 8..<16)
        let body = raw.subdata(in: 16..<raw.count)
        let k = bytesToKeys(salt: salt, passphrase: passphrase)
        return aes(kCCDecrypt, data: body, key: k.key, iv: k.iv)
    }

    static func decryptString(_ base64: String, passphrase: Data) -> String? {
        guard let d = decrypt(base64, passphrase: passphrase) else { return nil }
        return String(data: d, encoding: .utf8)
    }

    static func encryptString(_ text: String, passphrase: Data) -> String? {
        let salt = randomBytes(8)
        let k = bytesToKeys(salt: salt, passphrase: passphrase)
        guard let c = aes(kCCEncrypt, data: Data(text.utf8), key: k.key, iv: k.iv) else { return nil }
        var all = Data("Salted__".utf8)
        all.append(salt)
        all.append(c)
        return all.base64EncodedString()
    }

    // MARK: RSA

    private static func readTLV(_ d: [UInt8], _ i: inout Int) -> (tag: UInt8, range: Range<Int>)? {
        guard i + 2 <= d.count else { return nil }
        let tag = d[i]
        i += 1
        var len = Int(d[i])
        i += 1
        if len & 0x80 != 0 {
            let n = len & 0x7F
            guard n > 0, n <= 4, i + n <= d.count else { return nil }
            len = 0
            for _ in 0..<n {
                len = (len << 8) | Int(d[i])
                i += 1
            }
        }
        guard i + len <= d.count else { return nil }
        let r = i..<(i + len)
        i += len
        return (tag, r)
    }

    /// PEM (PKCS#1 oder X.509) -> rohes PKCS#1-RSAPublicKey (DER).
    static func pkcs1Key(fromPEM pem: String) -> Data? {
        let isSPKI = pem.contains("BEGIN PUBLIC KEY")
        let b64 = pem.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("-----") }
            .joined()
        guard let der = Data(base64Encoded: b64) else { return nil }
        if !isSPKI { return der }
        let b = [UInt8](der)
        var i = 0
        guard let outer = readTLV(b, &i), outer.tag == 0x30 else { return nil }
        var j = outer.range.lowerBound
        guard let alg = readTLV(b, &j), alg.tag == 0x30 else { return nil }
        guard let bits = readTLV(b, &j), bits.tag == 0x03, bits.range.count > 1 else { return nil }
        return Data(b[(bits.range.lowerBound + 1)..<bits.range.upperBound])
    }

    static func rsaEncrypt(_ data: Data, pem: String) -> Data? {
        guard let der = pkcs1Key(fromPEM: pem) else { return nil }
        let attrs: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass as String: kSecAttrKeyClassPublic,
        ]
        var err: Unmanaged<CFError>?
        guard let key = SecKeyCreateWithData(der as CFData, attrs as CFDictionary, &err) else { return nil }
        guard let enc = SecKeyCreateEncryptedData(key, .rsaEncryptionPKCS1, data as CFData, &err) else { return nil }
        return enc as Data
    }
}
