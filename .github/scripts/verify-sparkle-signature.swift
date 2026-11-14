// Usage: swift verify-sparkle-signature.swift <base64 public key> <file> <base64 edSignature>
// Exits 0 only when the signature over the file verifies with the public key the app ships with.
import CryptoKit
import Foundation

let args = CommandLine.arguments
guard args.count == 4,
      let keyData = Data(base64Encoded: args[1]),
      let signature = Data(base64Encoded: args[3]),
      let file = FileManager.default.contents(atPath: args[2]),
      let key = try? Curve25519.Signing.PublicKey(rawRepresentation: keyData)
else {
    FileHandle.standardError.write(Data("usage: verify-sparkle-signature <public key> <file> <signature>, all readable\n".utf8))
    exit(2)
}
guard key.isValidSignature(signature, for: file) else {
    FileHandle.standardError.write(Data("signature does not verify with the app's public key\n".utf8))
    exit(1)
}
