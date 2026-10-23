// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/config/app_config.dart';
import 'package:fluffychat/utils/platform_infos.dart';
import 'package:matrix/matrix.dart';
import 'package:path_provider_foundation/path_provider_foundation.dart';

/// Returns `null` when the App Group entitlement is missing from the applied
/// provisioning profile, which is the normal case for unprovisioned builds.
Future<String?> iosAppGroupContainerPath() async {
  if (!PlatformInfos.isIOS) return null;
  try {
    return await PathProviderFoundation().getContainerPath(
      appGroupIdentifier: AppConfig.iosAppGroupId,
    );
  } catch (e, s) {
    Logs().w('Unable to read iOS app group container', e, s);
    return null;
  }
}
