import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:varagh/translate/translator.dart';

void main() {
  test('both answer shapes are read', () {
    expect(parseTranslation('[["سلام دنیا","en"]]'), 'سلام دنیا');
    expect(
      parseTranslation(
        '[[["سلام. ","Hello. ",null,null,10],["خداحافظ.","Bye.",null,null,3],'
        '[null,null,"slạm"]],null,"en"]',
      ),
      'سلام. خداحافظ.',
    );
  });

  test('an answer without a translation is an error', () {
    expect(() => parseTranslation('<html>Sorry...</html>'), throwsException);
    expect(() => parseTranslation('[]'), throwsException);
    expect(() => parseTranslation('[[]]'), throwsException);
  });

  test('the next endpoint is tried when one turns the request away', () async {
    final asked = <String>[];
    final translator = Translator(
      endpoints: [
        Uri.parse('https://one.test/t?client=a'),
        Uri.parse('https://two.test/single?client=b&dt=t'),
      ],
      client: MockClient((request) async {
        asked.add(request.url.host);
        expect(request.url.queryParameters['tl'], 'fa');
        expect(request.url.queryParameters['sl'], 'auto');
        expect(request.bodyFields['q'], 'Hello');
        if (request.url.host == 'one.test') {
          return http.Response('<html>Sorry...</html>', 200);
        }
        expect(request.url.queryParameters['dt'], 't');
        return http.Response.bytes(
          utf8.encode('[[["سلام","Hello"]],null,"en"]'),
          200,
        );
      }),
    );
    expect(await translator.translate('Hello', to: 'fa'), 'سلام');
    expect(asked, ['one.test', 'two.test']);
  });

  test('it fails when every endpoint does', () {
    final translator = Translator(
      client: MockClient((request) async => http.Response('', 429)),
    );
    expect(translator.translate('Hello', to: 'fa'), throwsException);
  });
}
