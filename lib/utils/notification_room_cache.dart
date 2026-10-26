// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';
import 'dart:io';

import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/utils/matrix_sdk_extensions/flutter_matrix_dart_sdk_database/app_group.dart';
import 'package:fluffychat/utils/matrix_sdk_extensions/matrix_locals.dart';
import 'package:fluffychat/utils/platform_infos.dart';
import 'package:flutter/foundation.dart';
import 'package:matrix/matrix.dart';
import 'package:path/path.dart';

const notificationRoomCacheFileName = 'notification_rooms.json';

/// Writes the room names and avatars which the Notification Service Extension
/// needs into the App Group container.
///
/// The SQLite database itself must not be shared with the extension, because
/// iOS terminates apps which are suspended while holding a lock on a database
/// in a shared container (RUNNINGBOARD 0xdead10cc).
Future<void> updateNotificationRoomCache(Iterable<Client> clients) async {
  if (!PlatformInfos.isIOS) return;
  final containerPath = await iosAppGroupContainerPath();
  if (containerPath == null) return;
  final matrixLocals = MatrixLocals(
    await lookupL10n(PlatformDispatcher.instance.locale),
  );
  final rooms = <String, Map<String, String?>>{
    for (final client in clients)
      if (client.isLogged())
        for (final room in client.rooms)
          room.id: {
            'name': room.getLocalizedDisplayname(matrixLocals),
            'avatar': room.avatar?.toString(),
          },
  };
  try {
    await File(
      join(containerPath, notificationRoomCacheFileName),
    ).writeAsString(jsonEncode({'rooms': rooms}));
  } catch (e, s) {
    Logs().w('Unable to write the notification room cache', e, s);
  }
}
