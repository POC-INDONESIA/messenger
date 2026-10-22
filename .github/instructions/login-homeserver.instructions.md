---
applyTo: "lib/pages/login/**,lib/pages/intro/**,lib/pages/sign_in/**,lib/pages/bootstrap/**,lib/utils/sign_in_flows/**,lib/config/app_config.dart,lib/config/setting_keys.dart"
description: "POCIND login, homeserver and branding rules"
---

# Login / homeserver / branding rules (POCIND fork)

This fork targets a **modified Matrix homeserver** (`matrix.pocindonesia.com`). The client must
keep talking plain Matrix: `m.login.password`, `m.login.sso`, native OIDC. Never add a
client-side "special" login path, hidden credentials, or hardcoded tokens — any server-side
customization must be reachable through standard `/_matrix/client/v3/login` flows.

## Flow map (keep this order intact)

1. `intro_page_presenter._login()` — if `AppSettings.presetHomeserver.value` is non-empty, skips
   the server picker and calls `connectToHomeserverFlow(..., signUp: false)`; otherwise routes to
   `/home/sign_in`.
2. `sign_in_page` / `sign_in_view_model` — list from `AppConfig.homeserverList` + free-text entry.
3. `check_homeserver.dart` — `checkHomeserver(fetchAuthMetadata: true)` then dispatch
   OIDC (`AuthMetadata` + `AppSettings.enableMatrixNativeOIDC`) → SSO (`m.login.sso`)
   → password form. Only the OIDC/SSO branch persists `AppSettings.defaultHomeserver`.
4. `login.dart` — maps identifier to user / email (`medium: 'email'`) / msisdn
   (`medium: 'msisdn'`), calls `client.login(LoginType.mLoginPassword, ...)`, then `/backup`.

## Constraints

- `presetHomeserver` being set is what hides the server picker and registration in
  `intro_page.dart` (`hasPresetHomeserver`). `AppConfig.enableRegistration` and
  `allowOtherHomeservers` are **dead flags** — do not use them for gating.
- `AppConfig.enableE2ee` is `false` on purpose (server rejects `m.room.encryption`). Do not
  re-enable vodozemac init, backup bootstrap, or verification prompts in these pages without an
  explicit request; `/backup` is bypassed by `AppRoutes.backupRedirect`.
- Branding constants, if changed, belong in `app_config.dart` (ids, URL schemes, deep links,
  colors) and `setting_keys.dart` (`applicationName`, `defaultHomeserver`, `presetHomeserver`).
  Mirror them into `config.sample.json` and platform manifests — never add literals elsewhere.
- Still-upstream endpoints (`crash.fluffy.chat`, `push.fluffychat.im`, `fluffychat.im` website /
  privacy / tos / logo, GitHub `krille-chan/fluffychat` URLs) are known gaps. If a task mentions
  "remove upstream references", these are the places to look.
- Login UI is upstream-identical: username field accepts MXID, email or phone. Do not add extra
  fields unless the modified server actually requires them.
- Use `L10n.of(context)` for every user-visible string; add keys to `lib/l10n/intl_en.arb` (and
  `intl_id.arb` for Indonesian) plus `flutter gen-l10n`. Never edit `lib/l10n/l10n*.dart`.
- Material widgets come from `package:material_ui/material_ui.dart`.
