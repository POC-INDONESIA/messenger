// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:io';

import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/utils/client_manager.dart';
import 'package:fluffychat/utils/platform_infos.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:matrix/matrix.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:universal_html/html.dart' as html;

import 'app_group.dart';
import 'cipher.dart';

Future<DatabaseApi> flutterMatrixSdkDatabaseBuilder(String clientName) async {
  try {
    return await _constructDatabase(clientName);
  } catch (e, s) {
    Logs().wtf('Unable to construct database!', e, s);

    try {
      // Send error notification:
      final l10n = await lookupL10n(PlatformDispatcher.instance.locale);
      // We expect that the database cannot be open on iOS 2.8.0 due to that
      // the team ID has changed and te app can no longer access the database
      // key in the iOS keychain. This should be removed from 2.9.0 on.
      if (!PlatformInfos.isIOS) {
        ClientManager.sendInitNotification(l10n.initAppError, e.toString());
      }
    } catch (e, s) {
      Logs().e('Unable to send error notification', e, s);
    }

    // Delete database file:
    if (!kIsWeb) {
      final dbFile = File(await _getDatabasePath(clientName));
      if (await dbFile.exists()) await dbFile.delete();
    }

    // Try again
    return await _constructDatabase(clientName);
  }
}

Future<Directory?> getFileStorageLocation() async {
  try {
    late final Directory temporaryDirectory;
    if (PlatformInfos.isIOS) {
      final containerPath = await iosAppGroupContainerPath();
      temporaryDirectory = containerPath == null
          ? await getTemporaryDirectory()
          : Directory(containerPath);
    } else if (PlatformInfos.isLinux) {
      temporaryDirectory = await getApplicationCacheDirectory();
    } else {
      temporaryDirectory = await getTemporaryDirectory();
    }
    return await Directory(
      join(temporaryDirectory.path, 'fluffychat_download_cache'),
    ).create(recursive: true);
  } on MissingPlatformDirectoryException catch (_) {
    Logs().w(
      'No temporary directory for file cache available on this platform.',
    );
  }
  return null;
}

Future<MatrixSdkDatabase> _constructDatabase(String clientName) async {
  if (kIsWeb) {
    html.window.navigator.storage?.persist();
    return await MatrixSdkDatabase.init(clientName);
  }

  final secureStorageOptions = await iosSecureStorageOptions();
  final cipher = await getDatabaseCipher(iOptions: secureStorageOptions);

  final fileStorageLocation = await getFileStorageLocation();

  final path = await _getDatabasePath(clientName);

  // import the SQLite / SQLCipher shared objects / dynamic libraries
  final factory = createDatabaseFactoryFfi();

  // required for [getDatabasesPath]
  databaseFactory = factory;

  // migrate from potential previous SQLite database path to current one
  await _migrateLegacyLocation(path, clientName);
  await _migrateFromAppGroup(path, clientName);

  // in case we got a cipher, we use the encryption helper
  // to manage SQLite encryption
  final helper = cipher == null
      ? null
      : SQfLiteEncryptionHelper(factory: factory, path: path, cipher: cipher);

  // check whether the DB is already encrypted and otherwise do so
  await helper?.ensureDatabaseFileEncrypted();

  final openDatabaseOptions = OpenDatabaseOptions(
    version: 1,
    // most important : apply encryption when opening the DB
    onConfigure: (db) =>
        helper?.applyPragmaKey(db, ensureIncrementalAutoVacuum: true),
  );

  late final Database database;
  try {
    database = await factory.openDatabase(path, options: openDatabaseOptions);
  } catch (e, s) {
    Logs().wtf('Unable to open database! Delete file and try again...', e, s);
    await File(path).delete();
    database = await openDatabase(path, options: openDatabaseOptions);
  }

  final secureStorage = FlutterSecureStorage(iOptions: secureStorageOptions);

  return await MatrixSdkDatabase.init(
    clientName,
    database: database,
    maxFileSize: 1000 * 1000 * 10,
    fileStorageLocation: fileStorageLocation?.uri,
    deleteFilesAfterDuration: const Duration(days: 30),
    secureStorage: (
      read: (key) => secureStorage.read(key: key),
      write: (key, value) => secureStorage.write(key: key, value: value),
      delete: (key) => secureStorage.delete(key: key),
    ),
  );
}

Future<String> _getDatabaseDirectory() async {
  if (PlatformInfos.isIOS) {
    // The database must never live in the App Group container. iOS kills apps
    // which are suspended while holding a lock on a database in a shared
    // container (RUNNINGBOARD 0xdead10cc).
    return (await getLibraryDirectory()).path;
  }
  if (PlatformInfos.isMacOS) {
    return (await getLibraryDirectory()).path;
  }
  return (await getApplicationSupportDirectory()).path;
}

Future<String> _getDatabasePath(String clientName) async {
  final databaseDirectory = await _getDatabaseDirectory();

  return join(databaseDirectory, '$clientName.sqlite');
}

/// Moves a database which older versions kept in the App Group container into
/// the private app container.
Future<void> _migrateFromAppGroup(String sqlFilePath, String clientName) async {
  if (!PlatformInfos.isIOS) return;
  final containerPath = await iosAppGroupContainerPath();
  if (containerPath == null) return;
  final legacyPath = join(containerPath, '$clientName.sqlite');
  if (legacyPath == sqlFilePath) return;
  if (!await File(legacyPath).exists()) return;
  if (await File(sqlFilePath).exists()) return;
  for (final suffix in ['', '-wal', '-shm', '-journal']) {
    final legacyFile = File('$legacyPath$suffix');
    if (!await legacyFile.exists()) continue;
    await legacyFile.copy('$sqlFilePath$suffix');
  }
  Logs().i('Migrated database out of the App Group container');
  for (final suffix in ['', '-wal', '-shm', '-journal']) {
    final legacyFile = File('$legacyPath$suffix');
    if (await legacyFile.exists()) {
      try {
        await legacyFile.delete();
      } catch (e, s) {
        Logs().w('Unable to delete legacy database file', e, s);
      }
    }
  }
}

Future<void> _migrateLegacyLocation(
  String sqlFilePath,
  String clientName,
) async {
  final oldPath = PlatformInfos.isDesktop
      ? (await getApplicationSupportDirectory()).path
      : PlatformInfos.isIOS
      ? (await getLibraryDirectory()).path
      : await getDatabasesPath();

  final oldFilePath = join(oldPath, '$clientName.sqlite');
  if (oldFilePath == sqlFilePath) return;

  final maybeOldFile = File(oldFilePath);
  if (await maybeOldFile.exists()) {
    Logs().i(
      'Migrate legacy location for database from "$oldFilePath" to "$sqlFilePath"',
    );
    await maybeOldFile.copy(sqlFilePath);
    await maybeOldFile.delete();
  }
}
