// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';
import 'dart:math';

import 'package:fluffychat/config/app_config.dart';
import 'package:fluffychat/config/setting_keys.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/utils/client_manager.dart';
import 'package:fluffychat/utils/platform_infos.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:matrix/matrix.dart';

import 'app_group.dart';

const _passwordStorageKey = 'database_password';

const _appGroupIosOptions = IOSOptions(
  groupId: AppConfig.iosAppGroupId,
  accessibility: .first_unlock,
);

const _defaultIosOptions = IOSOptions(accessibility: .first_unlock);

Future<IOSOptions> iosSecureStorageOptions() async {
  if (!PlatformInfos.isIOS) return _appGroupIosOptions;
  return await iosAppGroupContainerPath() == null
      ? _defaultIosOptions
      : _appGroupIosOptions;
}

Future<String?> getDatabaseCipher({IOSOptions? iOptions}) async {
  String? password;
  final options = iOptions ?? await iosSecureStorageOptions();

  try {
    password = await FlutterSecureStorage(
      iOptions: options,
    ).read(key: _passwordStorageKey, iOptions: options);
    if (password != null) return password;

    if (PlatformInfos.isIOS && options.groupId != null) {
      final legacyPassword = await FlutterSecureStorage().read(
        key: _passwordStorageKey,
      );
      if (legacyPassword != null) {
        Logs().i('Migrate database key location on iOS...');
        await FlutterSecureStorage().delete(key: _passwordStorageKey);
        await FlutterSecureStorage(iOptions: options).write(
          key: _passwordStorageKey,
          value: legacyPassword,
          iOptions: options,
        );
        return legacyPassword;
      }
    }

    final rng = Random.secure();
    final list = Uint8List(32);
    list.setAll(0, Iterable.generate(list.length, (i) => rng.nextInt(256)));
    final newPassword = base64UrlEncode(list);
    await FlutterSecureStorage(
      iOptions: options,
    ).write(key: _passwordStorageKey, value: newPassword, iOptions: options);
    // workaround for if we just wrote to the key and it still doesn't exist
    password = await FlutterSecureStorage(
      iOptions: options,
    ).read(key: _passwordStorageKey, iOptions: options);
    if (password == null) throw MissingPluginException();
    return password;
  } on MissingPluginException catch (e) {
    FlutterSecureStorage(
      iOptions: options,
    ).delete(key: _passwordStorageKey, iOptions: options).catchError((_) {});
    Logs().w('Database encryption is not supported on this platform', e);
    _sendNoEncryptionWarning(e);
  } catch (e, s) {
    FlutterSecureStorage(
      iOptions: options,
    ).delete(key: _passwordStorageKey, iOptions: options).catchError((_) {});
    Logs().w('Unable to init database encryption', e, s);
    _sendNoEncryptionWarning(e);
  }
  return null;
}

Future<void> _sendNoEncryptionWarning(Object exception) async {
  final isStored = AppSettings.noEncryptionWarningShown.value;

  if (isStored == true) return;

  final l10n = await lookupL10n(PlatformDispatcher.instance.locale);
  ClientManager.sendInitNotification(
    l10n.noDatabaseEncryption,
    exception.toString(),
  );

  await AppSettings.noEncryptionWarningShown.setItem(true);
}
