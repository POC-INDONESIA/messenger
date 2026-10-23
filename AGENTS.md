# AGENTS.md — POCIND MESSENGER

Flutter chat client, forked from **FluffyChat 2.11.0** and rebranded as **POCIND MESSENGER**.
It talks to a **modified Matrix homeserver** at `matrix.pocindonesia.com` (custom login policy,
E2EE refused server-side).

> The pubspec package is still named `fluffychat` — all app imports use
> `package:fluffychat/...`. Never rename it.

## Toolchain & commands

Flutter version is pinned in `.fvmrc` (3.47.7); Dart `>=3.11.1 <4.0.0`. A Rust toolchain is
only needed for vodozemac (crypto tests, web build).

```bash
flutter pub get
flutter analyze                                  # must be warning-free
dart format lib/ test/ --set-exit-if-changed     # CI gate (CONTRIBUTING's `flutter format` is stale)
flutter test                                     # all tests
flutter test test/command_hint_test.dart         # single test file
flutter run
flutter gen-l10n                                 # after editing lib/l10n/*.arb
```

Full CI check list: [`.github/workflows/integrate.yaml`](.github/workflows/integrate.yaml)
(reuse lint, license checker, sweeper, dependency_validator, dart_code_linter metrics,
empty-translation check, no commented-out Dart). Run the relevant subset before claiming success.

Integration tests need Docker + Synapse: `./scripts/prepare_integration_test.sh`, then
`flutter test integration_test/mobile_test.dart`. See [README.md](README.md).

## Architecture

- **Matrix Dart SDK (`package:matrix`) is the model layer.** `Client`, `Room`, `Event`, `Timeline`
  are SDK types; app behavior is added through extensions in `lib/utils/matrix_sdk_extensions/`.
  Prefer an extension over subclassing or wrapping SDK objects.
- **No Riverpod / GetIt / BLoC.** Only `Provider` for two things: `Matrix.of(context)`
  (app-wide `MatrixState`) and `ThemeBuilder.of(context)`.
- **Controller/View pattern** (mandatory for new pages, see [CONTRIBUTING.md](CONTRIBUTING.md)):
  `page.dart` has the `StatefulWidget` and `class XController extends State<XPage>`;
  `page_view.dart` has a stateless `XView` whose **only constructor parameter is the controller**
  and whose callbacks are parameterless controller methods. Non-trivial logic belongs in
  `lib/utils/`, not in views.
- **Newer MVVM pattern** for complex pages: `ViewModelBuilder<T extends ValueNotifier>` +
  `XViewModel extends ValueNotifier<XState>`. Used by sign-in, bootstrap, call, settings.
- **Navigation**: `go_router`, routes in `lib/config/routes.dart`; the router instance is static
  (`FluffyChatApp.router`) so hot reload keeps state.
- **Multi-account**: `MatrixState.clients` is a list, `MatrixState.client` is the active one.

Entry point `lib/main.dart` → `ClientManager.getClients()` → `FluffyChatApp` in
`lib/widgets/fluffy_chat_app.dart`.

## Repository conventions

- **Import Material from `package:material_ui/material_ui.dart`, never
  `package:flutter/material.dart`.** Mixing both creates incompatible widget/theme types.
  (`material_ui` is pinned to an exact version in `pubspec.yaml`.)
- Lints are strict: `prefer_single_quotes`, `require_trailing_commas`, `prefer_final_locals`,
  `directives_ordering`, `avoid_print` (use `Logs()` from `package:matrix`), `avoid-dynamic`.
  See [analysis_options.yaml](analysis_options.yaml).
- **No explanatory comments.** Comments only for workarounds (with an upstream link) or to explain
  something genuinely surprising. CI also rejects commented-out Dart ending in `;`.
- Every source file starts with SPDX headers (see [REUSE.toml](REUSE.toml)); reuse an existing
  header block verbatim.
- Avoid `else`; use guards, early returns, `switch`.
- Do not put feature code in `android/`, `ios/`, `web/`, `linux/`, `macos/`, `windows/` — platform
  dirs are intentionally kept close to upstream to reduce upgrade conflicts.
- `CONTRIBUTING.md` forbids LLM-generated contributions to upstream FluffyChat; this fork's own
  changes are separate from upstream PRs.

## Localization (must follow)

- Source of truth: `lib/l10n/intl_en.arb` (+ ~60 locales, `intl_id.arb` is actively maintained).
- Generated and **checked in but never hand-edited**: `lib/l10n/l10n.dart`, `lib/l10n/l10n_*.dart`
  (excluded from analysis). Add keys to the ARB files and run `flutter gen-l10n`.
- Usage: `L10n.of(context).key` in widgets; `lookupL10n(locale)` outside a `BuildContext`.
- Adding/removing a locale also requires `./scripts/generate-locale-config.sh` and committing the
  Android `locale_config.xml` — CI fails on drift. Empty translations (`": ""`) fail CI.
- Config: [l10n.yaml](l10n.yaml).

## POCIND fork specifics (differs from upstream)

- **Branding lives in** `lib/config/app_config.dart` (colors, `appId = com.pocindonesia.chat`,
  schemes `im.pocindchat` / `im.pocindchat.auth`, deep link `im.pocindchat://chat/`, push app id
  `com.pocindonesia.chat`) and `lib/config/setting_keys.dart`
  (`applicationName = 'POCIND MESSENGER'`, `defaultHomeserver` / `presetHomeserver =
  'matrix.pocindonesia.com'`). When rebranding, these are the single sources of truth — mirror them,
  don't scatter literals.
- **`presetHomeserver` is non-empty by default, which changes the UX**: the intro page skips the
  homeserver picker (`intro_page_presenter._login()` calls `connectToHomeserverFlow` directly),
  and `intro_page.dart` hides "create account" and "login with Matrix ID". Registration is not
  reachable from the UI even though `AppConfig.enableRegistration = true` and the
  `/home/sign_in` + `/home/sign_up` routes still exist. `enableRegistration` /
  `allowOtherHomeservers` are effectively dead flags — gate on `hasPresetHomeserver` instead.
- **E2EE is disabled deliberately** (`AppConfig.enableE2ee = false`): vodozemac is not initialized,
  `/backup` redirects straight to `/rooms`, and the encryption UI/settings remain in the code but
  are non-functional. Do **not** assume crypto identity or a recovery key exists. If touching
  backup/bootstrap/verification code, verify it is unreachable first.
- **Upstream endpoints are still hardcoded** and are the usual cause of "wrong environment" bugs:
  `AppConfig.homeserverList` (raw.githubusercontent FluffyChat list),
  `crashReportEndpoint = crash.fluffy.chat`, `sourceCodeUrl`, `latestReleaseApiUrl`,
  `changelogUrl`, and `AppSettings.pushNotificationsGatewayUrl = push.fluffychat.im`,
  `website` / `privacyPolicy` / `tos` / `logoUrl` = fluffychat.im. `recommended_homeservers.json`
  in this repo is **not read at runtime**.
- **Branding gaps**: `web/index.html`, `web/manifest.json` still say FluffyChat.
  Kotlin sources live under the old path `android/app/src/main/kotlin/chat/fluffy/fluffychat/`
  but declare `package com.pocindonesia.chat` — scripts referencing the old path break.

## Login flow (where "customized login" lives)

The client only speaks standard Matrix (`m.login.password`, SSO, OIDC); the POCIND-specific
behaviour comes from the **server's** supported flows plus the preset homeserver. Order of events:

1. `lib/pages/intro/intro_page_presenter.dart` → `_login()` skips the picker when
   `presetHomeserver` is set, else routes to `/home/sign_in`.
2. `lib/pages/sign_in/` — server list from `AppConfig.homeserverList`, free-text entry.
3. `lib/utils/sign_in_flows/check_homeserver.dart` → `client.checkHomeserver(fetchAuthMetadata: true)`
   then dispatches: native OIDC → SSO → password form (`/home/login`).
4. `lib/pages/login/login.dart` → `login()` maps the identifier to
   `AuthenticationUserIdentifier` / email / msisdn and calls `client.login(...)`, then `context.go('/backup')`.
   `_checkWellKnown` re-targets `client.homeserver` if the typed MXID domain differs.

Do not hardcode usernames, passwords, or tokens in these files, and do not add a client-side
"special" login branch — server-side customization must stay discoverable through standard
`/_matrix/client/v3/login` flows.

## Testing notes

- `test/utils/test_client.dart` (`prepareTestClient()`) gives a ready client with `FakeMatrixApi`
  and in-memory sqflite — use it instead of building clients by hand.
- Tests that touch crypto lazily run `./scripts/prepare_vodozemac.sh` (clones + `cargo build`).
- Golden tests: `test/screenshots/chat_list_test.dart`; refresh with `--update-goldens`.
- Several legacy tests (`widget_test.dart`, `archive_test.dart`, `homeserver_picker_test.dart`)
  are commented-out stubs — don't treat them as coverage.

## Known stale/broken helpers

- `scripts/generate_command_hints_glue.sh` emits an import of `package:flutter_gen/gen_l10n/l10n.dart`
  while the project uses `package:fluffychat/l10n/l10n.dart`. Fix the script before using it.
- `dart_dependency_validator.yaml` intentionally ignores `handy_window`,
  `media_kit_libs_linux`, `media_kit_libs_windows_audio` — do not remove those ignores.
