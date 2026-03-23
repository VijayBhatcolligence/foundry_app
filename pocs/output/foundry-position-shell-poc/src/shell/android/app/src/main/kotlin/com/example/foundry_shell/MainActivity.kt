package com.example.foundry_shell

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.KeyFactory
import java.security.Signature
import java.security.spec.X509EncodedKeySpec
import android.util.Base64

class MainActivity : FlutterActivity() {
    private val CRYPTO_CHANNEL = "com.foundry.shell/crypto"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Register crypto bridge method channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CRYPTO_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "verifyRSASignature" -> {
                    try {
                        val publicKeyPem = call.argument<String>("publicKeyPem")
                        val message = call.argument<ByteArray>("message")
                        val signature = call.argument<ByteArray>("signature")

                        if (publicKeyPem == null || message == null || signature == null) {
                            result.error("INVALID_ARGS", "Missing required arguments", null)
                            return@setMethodCallHandler
                        }

                        val verified = verifyRSASignature(publicKeyPem, message, signature)
                        result.success(verified)
                    } catch (e: Exception) {
                        result.error("CRYPTO_ERROR", "Signature verification failed: ${e.message}", null)
                    }
                }
                "ping" -> {
                    result.success("pong")
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    /**
     * Verify RSA-2048 PKCS1-v1_5 signature using Android platform crypto APIs
     *
     * @param publicKeyPem PEM-encoded RSA public key
     * @param message Original message bytes
     * @param signature RSA signature bytes (256 bytes for RSA-2048)
     * @return true if signature is valid, false otherwise
     */
    private fun verifyRSASignature(publicKeyPem: String, message: ByteArray, signature: ByteArray): Boolean {
        try {
            // Parse PEM format - remove headers and whitespace
            val publicKeyPEM = publicKeyPem
                .replace("-----BEGIN PUBLIC KEY-----", "")
                .replace("-----END PUBLIC KEY-----", "")
                .replace("\\s".toRegex(), "")

            // Decode base64 to get DER-encoded key bytes
            val publicKeyBytes = Base64.decode(publicKeyPEM, Base64.DEFAULT)

            // Create RSA public key from DER bytes
            val keySpec = X509EncodedKeySpec(publicKeyBytes)
            val keyFactory = KeyFactory.getInstance("RSA")
            val publicKey = keyFactory.generatePublic(keySpec)

            // Verify signature using SHA256withRSA
            val verifier = Signature.getInstance("SHA256withRSA")
            verifier.initVerify(publicKey)
            verifier.update(message)

            return verifier.verify(signature)
        } catch (e: Exception) {
            // Log error but return false instead of throwing
            android.util.Log.e("CryptoBridge", "RSA verification error: ${e.message}")
            return false
        }
    }
}
