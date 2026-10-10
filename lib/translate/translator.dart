import 'dart:convert';

import 'package:http/http.dart' as http;

/// Languages text can be translated into, by code, each under its own name.
const translationLanguages = {
  'fa': 'فارسی',
  'en': 'English',
  'ar': 'العربية',
  'tr': 'Türkçe',
  'de': 'Deutsch',
  'fr': 'Français',
  'es': 'Español',
  'ru': 'Русский',
  'zh-CN': '中文',
};

/// Translates text with Google Translate's web endpoints, which need no
/// key or account. The text is sent to Google; the language it is written
/// in is detected there.
class Translator {
  Translator({http.Client? client, List<Uri>? endpoints})
    : _client = client ?? http.Client(),
      _endpoints = endpoints ?? _google;

  /// Google turns some networks away from one of these and not the other,
  /// so they are tried in turn.
  static final _google = [
    Uri.parse(
      'https://clients5.google.com/translate_a/t?client=dict-chrome-ex',
    ),
    Uri.parse(
      'https://translate.googleapis.com/translate_a/single?client=gtx&dt=t',
    ),
  ];

  final http.Client _client;
  final List<Uri> _endpoints;

  /// Longest text the endpoints take in one request.
  static const maxLength = 5000;

  /// [text] in the language with code [to]. Throws when no endpoint can be
  /// reached or answers with a translation.
  Future<String> translate(String text, {required String to}) async {
    Exception? failure;
    for (final endpoint in _endpoints) {
      try {
        final response = await _client
            .post(
              endpoint.replace(
                queryParameters: {
                  ...endpoint.queryParameters,
                  'sl': 'auto',
                  'tl': to,
                },
              ),
              body: {
                'q': text.length > maxLength
                    ? text.substring(0, maxLength)
                    : text,
              },
            )
            .timeout(const Duration(seconds: 15));
        if (response.statusCode != 200) {
          throw http.ClientException('HTTP ${response.statusCode}', endpoint);
        }
        return parseTranslation(utf8.decode(response.bodyBytes));
      } on Exception catch (e) {
        failure = e;
      }
    }
    throw failure ?? StateError('No endpoints');
  }

  void close() => _client.close();
}

/// The translated text out of an endpoint's answer. One endpoint answers
/// with the translation and the language it found; the other with a list
/// of sentences, each starting with its translation.
String parseTranslation(String body) {
  final Object? json = jsonDecode(body);
  final text = switch (json) {
    [[final String translated, ...], ...] => translated,
    [final List sentences, ...] => [
      for (final sentence in sentences)
        if (sentence case [final String translated, ...]) translated,
    ].join(),
    _ => '',
  };
  if (text.isEmpty) throw const FormatException('No translation in the answer');
  return text;
}
