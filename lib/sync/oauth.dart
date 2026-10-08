import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

/// The app registration a user made with a cloud provider, and where that
/// provider's sign-in lives.
class OAuthConfig {
  const OAuthConfig({
    required this.authorizeUrl,
    required this.tokenUrl,
    required this.clientId,
    required this.scopes,
    this.clientSecret,
    this.extraAuthParams = const {},
    this.redirectHost = '127.0.0.1',
  });

  final Uri authorizeUrl;
  final Uri tokenUrl;
  final String clientId;

  /// Google issues one even for desktop apps; Microsoft's public clients
  /// have none.
  final String? clientSecret;

  final List<String> scopes;
  final Map<String, String> extraAuthParams;

  /// Host named in the redirect address. Each provider accepts a loopback
  /// address on any port, but is particular about how it is spelled.
  final String redirectHost;
}

class OAuthTokens {
  const OAuthTokens({
    required this.accessToken,
    required this.expiresAt,
    this.refreshToken,
  });

  final String accessToken;
  final DateTime expiresAt;

  /// Absent when a refresh response doesn't rotate it; the old one stays.
  final String? refreshToken;
}

class OAuthException implements Exception {
  const OAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

String _randomUrlSafe(int bytes) {
  final random = Random.secure();
  return base64Url
      .encode([for (var i = 0; i < bytes; i++) random.nextInt(256)])
      .replaceAll('=', '');
}

/// Signs the user in through their browser.
///
/// The app listens on a loopback port, sends the browser to the provider,
/// and the provider sends the browser back to that port with a one-time
/// code, which is then exchanged for tokens. PKCE ties the code to this
/// sign-in attempt, so a code caught by anything else on the machine is
/// useless.
Future<OAuthTokens> signIn(
  OAuthConfig config, {
  required Future<void> Function(Uri url) openBrowser,
  String donePage = 'You can close this window and return to the app.',
  Duration timeout = const Duration(minutes: 5),
  http.Client? client,
}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  try {
    final redirect = 'http://${config.redirectHost}:${server.port}';
    final verifier = _randomUrlSafe(48);
    final state = _randomUrlSafe(16);
    final challenge = base64Url
        .encode(sha256.convert(ascii.encode(verifier)).bytes)
        .replaceAll('=', '');

    await openBrowser(
      config.authorizeUrl.replace(
        queryParameters: {
          ...config.authorizeUrl.queryParameters,
          'client_id': config.clientId,
          'redirect_uri': redirect,
          'response_type': 'code',
          'scope': config.scopes.join(' '),
          'state': state,
          'code_challenge': challenge,
          'code_challenge_method': 'S256',
          ...config.extraAuthParams,
        },
      ),
    );

    String? code;
    await for (final request in server.timeout(
      timeout,
      onTimeout: (sink) => sink.close(),
    )) {
      final query = request.uri.queryParameters;
      // Browsers also ask for a favicon; only the real redirect counts.
      final relevant = query.containsKey('code') || query.containsKey('error');
      request.response
        ..statusCode = relevant ? 200 : 404
        ..headers.contentType = ContentType.html
        ..write(
          '<!doctype html><meta charset="utf-8"><title>Varagh</title>'
          '<body style="font-family:sans-serif;text-align:center;'
          'padding-top:4em">${const HtmlEscape().convert(donePage)}</body>',
        );
      await request.response.close();
      if (!relevant) continue;
      if (query['error'] != null) {
        throw OAuthException(
          query['error_description'] ?? query['error'] ?? 'Sign-in refused',
        );
      }
      if (query['state'] != state) {
        throw const OAuthException('Sign-in response did not match');
      }
      code = query['code'];
      break;
    }
    if (code == null) throw const OAuthException('Sign-in timed out');

    return await _requestTokens(config, {
      'grant_type': 'authorization_code',
      'code': code,
      'redirect_uri': redirect,
      'code_verifier': verifier,
    }, client);
  } finally {
    await server.close(force: true);
  }
}

/// Trades a refresh token for a fresh access token.
Future<OAuthTokens> refreshTokens(
  OAuthConfig config,
  String refreshToken, {
  http.Client? client,
}) => _requestTokens(config, {
  'grant_type': 'refresh_token',
  'refresh_token': refreshToken,
}, client);

Future<OAuthTokens> _requestTokens(
  OAuthConfig config,
  Map<String, String> fields,
  http.Client? client,
) async {
  final response = await (client?.post ?? http.post)(
    config.tokenUrl,
    body: {
      ...fields,
      'client_id': config.clientId,
      if (config.clientSecret case final secret? when secret.isNotEmpty)
        'client_secret': secret,
    },
  );
  final Object? body;
  try {
    body = jsonDecode(response.body);
  } on FormatException {
    throw OAuthException('Sign-in failed (${response.statusCode})');
  }
  if (response.statusCode != 200 || body is! Map) {
    final detail = body is Map
        ? body['error_description'] ?? body['error']
        : null;
    throw OAuthException('${detail ?? 'Sign-in failed'}');
  }
  return OAuthTokens(
    accessToken: body['access_token'] as String,
    refreshToken: body['refresh_token'] as String?,
    // Renewed a minute early so a request never goes out on its last gasp.
    expiresAt: DateTime.now().add(
      Duration(seconds: ((body['expires_in'] as num?)?.toInt() ?? 3600) - 60),
    ),
  );
}
