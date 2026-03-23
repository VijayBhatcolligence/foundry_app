import Flutter
import UIKit
import Security
import CommonCrypto

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Register crypto bridge method channel
    if let controller = window?.rootViewController as? FlutterViewController {
      let cryptoChannel = FlutterMethodChannel(name: "com.foundry.shell/crypto",
                                               binaryMessenger: controller.binaryMessenger)

      cryptoChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
        switch call.method {
        case "verifyRSASignature":
          guard let args = call.arguments as? [String: Any],
                let publicKeyPem = args["publicKeyPem"] as? String,
                let message = args["message"] as? FlutterStandardTypedData,
                let signature = args["signature"] as? FlutterStandardTypedData else {
            result(FlutterError(code: "INVALID_ARGS", message: "Missing required arguments", details: nil))
            return
          }

          let verified = self?.verifyRSASignature(publicKeyPem: publicKeyPem,
                                                  message: message.data,
                                                  signature: signature.data) ?? false
          result(verified)

        case "ping":
          result("pong")

        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  /**
   * Verify RSA-2048 PKCS1-v1_5 signature using iOS Security framework
   *
   * - Parameters:
   *   - publicKeyPem: PEM-encoded RSA public key
   *   - message: Original message bytes
   *   - signature: RSA signature bytes (256 bytes for RSA-2048)
   * - Returns: true if signature is valid, false otherwise
   */
  private func verifyRSASignature(publicKeyPem: String, message: Data, signature: Data) -> Bool {
    do {
      // Parse PEM and create SecKey
      guard let publicKey = try? parsePublicKeyFromPEM(publicKeyPem) else {
        NSLog("[CryptoBridge] Failed to parse public key from PEM")
        return false
      }

      // Verify signature using Security framework
      var error: Unmanaged<CFError>?
      let verified = SecKeyVerifySignature(
        publicKey,
        .rsaSignatureMessagePKCS1v15SHA256,
        message as CFData,
        signature as CFData,
        &error
      )

      if let error = error {
        NSLog("[CryptoBridge] Verification error: \(error.takeRetainedValue())")
        return false
      }

      return verified
    } catch {
      NSLog("[CryptoBridge] RSA verification error: \(error)")
      return false
    }
  }

  /**
   * Parse PEM-encoded RSA public key to SecKey
   *
   * - Parameter pem: PEM-encoded public key string
   * - Returns: SecKey instance
   * - Throws: Error if parsing fails
   */
  private func parsePublicKeyFromPEM(_ pem: String) throws -> SecKey {
    // Strip PEM headers and newlines
    let stripped = pem
      .replacingOccurrences(of: "-----BEGIN PUBLIC KEY-----", with: "")
      .replacingOccurrences(of: "-----END PUBLIC KEY-----", with: "")
      .replacingOccurrences(of: "\n", with: "")
      .replacingOccurrences(of: "\r", with: "")
      .trimmingCharacters(in: .whitespacesAndNewlines)

    // Decode base64 to get DER-encoded key bytes
    guard let data = Data(base64Encoded: stripped) else {
      throw NSError(domain: "CryptoBridge", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to decode base64 PEM data"])
    }

    // Create SecKey from DER data
    let attributes: [String: Any] = [
      kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
      kSecAttrKeyClass as String: kSecAttrKeyClassPublic,
      kSecAttrKeySizeInBits as String: 2048
    ]

    var error: Unmanaged<CFError>?
    guard let key = SecKeyCreateWithData(data as CFData, attributes as CFDictionary, &error) else {
      if let error = error {
        throw error.takeRetainedValue() as Error
      }
      throw NSError(domain: "CryptoBridge", code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to create SecKey"])
    }

    return key
  }
}
