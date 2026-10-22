// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/utils/sign_in_flows/sso_login.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<Client> _createClient() async {
  sqfliteFfiInit();
  final client = Client(
    'sso-login-test',
    database: await MatrixSdkDatabase.init(
      'sso-login-test',
      database: await databaseFactoryFfi.openDatabase(':memory:'),
      sqfliteFactory: databaseFactoryFfi,
    ),
  );
  client.homeserver = Uri.parse('https://matrix.example.org');
  return client;
}

List<LoginFlow> _loginFlows(List<Map<String, String>> identityProviders) => [
  LoginFlow(
    type: 'm.login.sso',
    additionalProperties: {'identity_providers': identityProviders},
  ),
];

Future<void> _pumpLoginButton(
  WidgetTester tester,
  Client client,
  List<LoginFlow> loginFlows,
) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              // FlutterWebAuth2 has no platform implementation in widget tests.
              try {
                await ssoLoginFlow(client, context, false, loginFlows);
              } catch (_) {}
            },
            child: const Text('login'),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapLoginButton(WidgetTester tester) async {
  await tester.tap(find.text('login'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  testWidgets('a single SSO provider skips the provider selection', (
    tester,
  ) async {
    final client = (await tester.runAsync(_createClient))!;
    await _pumpLoginButton(
      tester,
      client,
      _loginFlows([
        {'id': 'oidc-poc', 'name': 'POC Indonesia'},
      ]),
    );

    await _tapLoginButton(tester);

    expect(find.text('Log in to matrix.example.org'), findsNothing);
    expect(find.text('POC Indonesia'), findsNothing);
  });

  testWidgets('multiple SSO providers still show the provider selection', (
    tester,
  ) async {
    final client = (await tester.runAsync(_createClient))!;
    await _pumpLoginButton(
      tester,
      client,
      _loginFlows([
        {'id': 'oidc-poc', 'name': 'POC Indonesia'},
        {'id': 'other', 'name': 'Other IdP'},
      ]),
    );

    await _tapLoginButton(tester);

    expect(find.text('Log in to matrix.example.org'), findsOneWidget);
    expect(find.text('POC Indonesia'), findsOneWidget);
    expect(find.text('Other IdP'), findsOneWidget);
  });
}
