// lib/core/services/social_auth_service.dart
//
// Google / Apple sign-in. Firebase Auth does the actual OAuth dance and
// hands back an ID token; the backend verifies that token itself (see
// App\Services\FirebaseIdTokenVerifier) and issues the app's own Sanctum
// token — Firebase is only ever the identity broker here, never the app's
// session.

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:mubtaath/core/services/dio_client.dart';
import 'package:mubtaath/core/services/secure_storage_service.dart';

// Apple's identityToken JWT embeds a hash of a nonce we choose; Firebase
// checks it against the raw nonce we pass separately as replay protection.
// Skipping this (e.g. passing authorizationCode as accessToken instead,
// which isn't a valid substitute) makes signInWithCredential legitimately
// reject the credential — the native Apple sheet completes fine, but the
// Firebase exchange right after it fails.
String _generateNonce([int length = 32]) {
  const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
  final random = Random.secure();
  return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
}

String _sha256OfString(String input) => sha256.convert(utf8.encode(input)).toString();

class SocialAuthResult {
  final bool success;
  final bool cancelled;
  final bool isNewUser;
  final bool needsPhone;
  final String? userId;
  final String? errorMessage;

  const SocialAuthResult({
    required this.success,
    this.cancelled    = false,
    this.isNewUser    = false,
    this.needsPhone   = false,
    this.userId,
    this.errorMessage,
  });
}

class SocialAuthService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn();

  static Future<SocialAuthResult> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return const SocialAuthResult(success: false, cancelled: true);

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken:     googleAuth.idToken,
      );

      final userCred = await FirebaseAuth.instance.signInWithCredential(credential);
      final idToken = await userCred.user?.getIdToken();
      if (idToken == null) {
        return const SocialAuthResult(success: false, errorMessage: 'socialAuthTokenError');
      }

      return _exchangeWithBackend(provider: 'google', idToken: idToken);
    } catch (_) {
      return const SocialAuthResult(success: false, errorMessage: 'socialAuthError');
    }
  }

  static Future<SocialAuthResult> signInWithApple() async {
    try {
      final rawNonce = _generateNonce();
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: _sha256OfString(rawNonce),
      );

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken:  appleCredential.identityToken,
        rawNonce: rawNonce,
      );

      final userCred = await FirebaseAuth.instance.signInWithCredential(oauthCredential);
      final idToken = await userCred.user?.getIdToken();
      if (idToken == null) {
        return const SocialAuthResult(success: false, errorMessage: 'socialAuthTokenError');
      }

      // Apple only ever includes the name on this FIRST native result — it's
      // never present in the ID token, so it has to be forwarded explicitly
      // right now or it's lost for good.
      final nameParts = [appleCredential.givenName, appleCredential.familyName]
          .where((p) => p != null && p.trim().isNotEmpty)
          .join(' ');

      return _exchangeWithBackend(
        provider: 'apple',
        idToken:  idToken,
        fullName: nameParts.isNotEmpty ? nameParts : null,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return const SocialAuthResult(success: false, cancelled: true);
      }
      return const SocialAuthResult(success: false, errorMessage: 'socialAuthError');
    } catch (_) {
      return const SocialAuthResult(success: false, errorMessage: 'socialAuthError');
    }
  }

  static Future<SocialAuthResult> _exchangeWithBackend({
    required String provider,
    required String idToken,
    String? fullName,
  }) async {
    try {
      final resp = await appDio.post('/auth/social-login', data: {
        'provider': provider,
        'idToken':  idToken,
        if (fullName != null) 'fullName': fullName,
      });
      final data = resp.data['data'] as Map<String, dynamic>;
      final token = data['accessToken'] as String;
      await SecureStorageService.saveAuthToken(token);
      final user = data['user'] as Map<String, dynamic>?;

      return SocialAuthResult(
        success:    true,
        isNewUser:  data['isNewUser']  as bool? ?? false,
        needsPhone: data['needsPhone'] as bool? ?? false,
        userId:     user?['id']?.toString(),
      );
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] as String?;
      return SocialAuthResult(success: false, errorMessage: msg ?? 'socialAuthError');
    }
  }
}
