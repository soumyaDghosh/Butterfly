import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:butterfly/models/defaults.dart';
import 'package:butterfly_api/butterfly_api.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'package:path/path.dart' as p;

import '../cubits/settings.dart';
import 'file_system.dart';
import 'file_system_io.dart';

enum FileSyncStatus { localLatest, remoteLatest, synced, conflict, offline }

@immutable
class SyncFile {
  final bool isDirectory;
  final AssetLocation location;
  final DateTime? localLastModified, syncedLastModified, remoteLastModified;

  const SyncFile(
      {required this.isDirectory,
      required this.location,
      required this.localLastModified,
      required this.syncedLastModified,
      this.remoteLastModified});

  FileSyncStatus get status {
    if (remoteLastModified == null) {
      return FileSyncStatus.offline;
    }
    if (localLastModified == null || syncedLastModified == null) {
      return FileSyncStatus.remoteLatest;
    }
    if (syncedLastModified!.isBefore(remoteLastModified!)) {
      if (localLastModified!.isBefore(remoteLastModified!)) {
        return FileSyncStatus.remoteLatest;
      }
      if (!isDirectory) {
        return FileSyncStatus.conflict;
      }
      return FileSyncStatus.localLatest;
    }
    if (!localLastModified!.isAfter(syncedLastModified!)) {
      return FileSyncStatus.synced;
    }
    if (localLastModified!.isAfter(syncedLastModified!)) {
      return FileSyncStatus.localLatest;
    }
    return FileSyncStatus.remoteLatest;
  }

  String get path => location.path;
}

mixin DavRemoteSystem {
  DavRemoteStorage get remote;

  Future<String> getRemoteCacheDirectory() async {
    var path = await getButterflyDirectory();
    path = p.joinAll(
        [...path.split('/'), 'Remotes', ...remote.identifier.split('/')]);
    return path;
  }

  Future<String> getAbsoluteCachePath(String path) async {
    var cacheDir = await getRemoteCacheDirectory();
    if (path.startsWith('/')) {
      path = path.substring(1);
    }
    return p.join(cacheDir, path);
  }

  Future<Uint8List?> getCachedContent(String path) async {
    if (!remote.hasDocumentCached(path)) return null;
    var absolutePath = await getAbsoluteCachePath(path);
    var file = File(absolutePath);
    if (await file.exists()) {
      return await file.readAsBytes();
    }
    return null;
  }

  Future<void> cacheContent(String path, List<int> content) async {
    var absolutePath = await getAbsoluteCachePath(path);
    var file = File(absolutePath);
    final directory = Directory(absolutePath);
    if (await directory.exists()) return;
    if (!(await file.exists())) {
      await file.create(recursive: true);
    }
    await file.writeAsBytes(content);
  }

  Future<void> deleteCachedContent(String path) async {
    var absolutePath = await getAbsoluteCachePath(path);
    var file = File(absolutePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> clearCachedContent() async {
    var cacheDir = await getRemoteCacheDirectory();
    var directory = Directory(cacheDir);
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  Future<Map<String, Uint8List>> getCachedFiles() async {
    var cacheDir = await getRemoteCacheDirectory();
    var files = <String, Uint8List>{};
    var dir = Directory(cacheDir);
    var list = await dir.list().toList();
    for (var file in list) {
      if (file is File) {
        var name = p.relative(file.path, from: cacheDir);
        var content = await file.readAsBytes();
        files[name] = content;
      }
    }
    return files;
  }

  Future<DateTime?> getCachedFileModified(String path) async {
    var absolutePath = await getAbsoluteCachePath(path);
    final file = File(absolutePath);
    if (await file.exists()) {
      return file.lastModified();
    }
    final directory = Directory(absolutePath);
    if (await directory.exists()) {
      return remote.lastSynced;
    }
    return null;
  }

  Future<Map<String, DateTime>> getCachedFileModifieds() async {
    var cacheDir = await getRemoteCacheDirectory();
    var files = <String, DateTime>{};
    var dir = Directory(cacheDir);
    var list = await dir.list().toList();
    for (final file in list) {
      final name = p.relative(file.path, from: cacheDir);
      final modified = await getCachedFileModified(name);
      if (modified != null) {
        files[name] = modified;
      }
    }
    return files;
  }

  Future<DateTime?> getRemoteFileModified(String path) async => null;

  Future<SyncFile> getSyncFile(String path) async {
    var localLastModified = await getCachedFileModified(path);
    var remoteLastModified = await getRemoteFileModified(path);
    var syncedLastModified = remote.lastSynced;
    final directory = Directory(await getAbsoluteCachePath(path));

    return SyncFile(
        isDirectory: await directory.exists(),
        location: AssetLocation(remote: remote.identifier, path: path),
        localLastModified: localLastModified,
        remoteLastModified: remoteLastModified,
        syncedLastModified: syncedLastModified);
  }

  Future<List<SyncFile>> getSyncFiles() async {
    var files = <SyncFile>[];
    var cacheDir = await getRemoteCacheDirectory();
    var dir = Directory(cacheDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    var list = await dir.list().toList();
    for (var file in list) {
      if (file is File) {
        var name = p.relative(file.path, from: cacheDir);
        var localLastModified = await file.lastModified();
        var remoteLastModified = await getRemoteFileModified(name);
        var syncedLastModified = remote.lastSynced;
        files.add(SyncFile(
            isDirectory: false,
            location: AssetLocation(remote: remote.identifier, path: name),
            localLastModified: localLastModified,
            remoteLastModified: remoteLastModified,
            syncedLastModified: syncedLastModified));
      }
    }
    return files;
  }
}

class DavRemoteDocumentFileSystem extends DocumentFileSystem
    with DavRemoteSystem {
  @override
  final DavRemoteStorage remote;

  DavRemoteDocumentFileSystem(this.remote);

  final http.Client client = http.Client();
  Future<http.StreamedResponse> _createRequest(List<String> path,
      {String method = 'GET', List<int>? body}) async {
    path = List<String>.from(path);
    if (path.firstOrNull?.isEmpty ?? false) {
      path.removeAt(0);
    }
    final url = remote.buildDocumentsUri(path: path);
    final request = http.Request(method, url);
    if (body != null) {
      request.bodyBytes = body;
    }
    request.headers['Authorization'] =
        'Basic ${base64Encode(utf8.encode('${remote.username}:${await remote.getRemotePassword()}'))}';
    return client.send(request);
  }

  @override
  Future<String> getRemoteCacheDirectory() async =>
      p.join(await super.getRemoteCacheDirectory(), 'Documents');

  @override
  Future<AppDocumentDirectory> createDirectory(String path) async {
    if (path.startsWith('/')) {
      path = path.substring(1);
    }
    if (!path.endsWith('/')) {
      path = '$path/';
    }
    final response = await _createRequest(path.split('/'), method: 'MKCOL');
    if (response.statusCode != 201) {
      throw Exception('Failed to create directory: ${response.statusCode}');
    }
    return AppDocumentDirectory(
        AssetLocation(
            remote: remote.identifier,
            path: path.substring(0, path.length - 1)),
        const []);
  }

  @override
  Future<void> deleteAsset(String path) async {
    final response = await _createRequest(path.split('/'), method: 'DELETE');
    if (response.statusCode != 204) {
      throw Exception('Failed to delete asset: ${response.statusCode}');
    }
  }

  @override
  Future<AppDocumentEntity?> getAsset(String path,
      {bool forceRemote = false}) async {
    if (path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    if (path.startsWith('/')) {
      path = path.substring(1);
    }
    final cached = await getCachedContent(path);
    if (cached != null && !forceRemote) {
      return AppDocumentFile(
          AssetLocation(remote: remote.identifier, path: path), cached);
    }

    var response = await _createRequest(path.split('/'), method: 'PROPFIND');
    if (response.statusCode != 207) {
      return null;
    }
    var content = await response.stream.bytesToString();
    final xml = XmlDocument.parse(content);
    final fileName = remote.buildDocumentsUri(path: path.split('/')).path;
    final currentElement = xml.findAllElements('d:response').where((element) {
      final current = element.getElement('d:href')?.value;
      return current == fileName || current == '$fileName/';
    }).first;
    final resourceType = currentElement
        .findElements('d:propstat')
        .first
        .findElements('d:prop')
        .first
        .findElements('d:resourcetype')
        .first;
    if (resourceType.getElement('d:collection') != null) {
      final assets = await Future.wait(xml
          .findAllElements('d:response')
          .where((element) =>
              element.getElement('d:href')?.value?.startsWith(fileName) ??
              false)
          .where((element) {
        final current = element.getElement('d:href')?.value;
        return current != fileName && current != '$fileName/';
      }).map((e) async {
        final currentResourceType = e
            .findElements('d:propstat')
            .first
            .findElements('d:prop')
            .first
            .findElements('d:resourcetype')
            .first;
        var path = e
                .findElements('d:href')
                .first
                .value
                ?.substring(remote.buildDocumentsUri().path.length) ??
            '';
        if (path.endsWith('/')) {
          path = path.substring(0, path.length - 1);
        }
        if (!path.startsWith('/')) {
          path = '/$path';
        }
        path = Uri.decodeComponent(path);
        if (currentResourceType.getElement('d:collection') != null) {
          return AppDocumentEntity.file(
              AssetLocation(remote: remote.identifier, path: path), const []);
        } else {
          return AppDocumentEntity.fileFromMap(
              AssetLocation(remote: remote.identifier, path: path), const {});
        }
      }).toList());
      return AppDocumentEntity.directory(
          AssetLocation(remote: remote.identifier, path: path), assets);
    }
    response = await _createRequest(path.split('/'), method: 'GET');
    if (response.statusCode != 200) {
      throw Exception('Failed to get asset: ${response.statusCode}');
    }
    var fileContent = await response.stream.toBytes();
    return AppDocumentFile(
        AssetLocation(remote: remote.identifier, path: path), fileContent);
  }

  @override
  Future<DateTime?> getRemoteFileModified(String path) async {
    final response = await _createRequest(path.split('/'), method: 'PROPFIND');
    if (response.statusCode != 207) {
      return null;
    }
    final body = await response.stream.bytesToString();
    final xml = XmlDocument.parse(body);
    final lastModified = xml
        .findAllElements('d:response')
        .firstOrNull
        ?.findElements('d:propstat')
        .firstOrNull
        ?.findElements('d:prop')
        .firstOrNull
        ?.findElements('d:getlastmodified')
        .firstOrNull
        ?.value;
    if (lastModified == null) {
      return null;
    }
    //  Parse lastModified rfc1123-date to Iso8601

    return HttpDate.parse(lastModified);
  }

  @override
  Future<bool> hasAsset(String path) async {
    final response = await _createRequest(path.split('/'));
    return response.statusCode == 200;
  }

  @override
  Future<AppDocumentFile> updateFile(String path, List<int> data,
      {bool forceSync = false}) async {
    if (!forceSync && remote.hasDocumentCached(path)) {
      cacheContent(path, data);
      return AppDocumentFile(
          AssetLocation(remote: remote.identifier, path: path), data);
    }
    // Create directory if not exists
    final directoryPath = path.substring(0, path.lastIndexOf('/'));
    if (!await hasAsset(directoryPath)) {
      await createDirectory(directoryPath);
    }
    final response =
        await _createRequest(path.split('/'), method: 'PUT', body: data);
    if (response.statusCode != 201 && response.statusCode != 204) {
      throw Exception(
          'Failed to update document: ${response.statusCode} ${response.reasonPhrase}');
    }
    return AppDocumentFile(
        AssetLocation(remote: remote.identifier, path: path), data);
  }

  List<String> getCachedFilePaths() {
    final files = <String>[];

    for (final file in remote.cachedDocuments) {
      final alreadySyncedFile =
          files.firstWhereOrNull((file) => file.startsWith(file));
      if (alreadySyncedFile == file) {
        continue;
      }
      if (alreadySyncedFile != null &&
          alreadySyncedFile.startsWith(file) &&
          !alreadySyncedFile.substring(file.length + 1).contains('/')) {
        files.remove(alreadySyncedFile);
      }
      files.add(file);
    }
    return files;
  }

  Future<List<SyncFile>> getAllSyncFiles() async {
    final paths = getCachedFilePaths();
    final files = <SyncFile>[];
    for (final path in paths) {
      final asset = await getAsset(path);
      if (asset == null) continue;
      files.add(await getSyncFile(asset.pathWithLeadingSlash));
      if (asset is AppDocumentDirectory) {
        for (final file in asset.assets) {
          files.add(await getSyncFile(file.pathWithLeadingSlash));
        }
      }
    }
    return files;
  }

  Future<void> uploadCachedContent(String path) async {
    final content = await getCachedContent(path);
    if (content == null) {
      return;
    }
    await updateFile(path, content, forceSync: true);
  }

  Future<void> cache(String path) async {
    final asset = await getAsset(path);
    if (asset is AppDocumentDirectory) {
      var filePath = path;
      if (filePath.startsWith('/')) {
        filePath = filePath.substring(1);
      }
      filePath = p.join(await getRemoteCacheDirectory(), filePath);
      final directory = Directory(filePath);
      if (!(await directory.exists())) {
        await directory.create(recursive: true);
      }
    } else if (asset is AppDocumentFile) {
      cacheContent(path, asset.data);
    }
  }

  @override
  Future<AppDocumentFile> updateDocument(String path, NoteData document,
          {bool forceSync = false}) =>
      updateFile(path, document.save(), forceSync: forceSync);

  @override
  Future<AppDocumentFile> importDocument(NoteData document,
      {String path = '', bool forceSync = false}) {
    if (path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    return createFile('$path/${document.name}.bfly', document.save(),
        forceSync: forceSync);
  }

  @override
  Future<AppDocumentFile> createFile(String path, List<int> data,
          {bool forceSync = false}) async =>
      updateFile(await findAvailableName(path), data);
}

class DavRemoteTemplateFileSystem extends TemplateFileSystem
    with DavRemoteSystem {
  @override
  final DavRemoteStorage remote;

  DavRemoteTemplateFileSystem(this.remote);

  final http.Client client = http.Client();
  Future<http.StreamedResponse> _createRequest(String path,
      {String method = 'GET', String? body, Uint8List? bodyBytes}) async {
    final url = remote.buildTemplatesUri(path: path.split('/'));
    final request = http.Request(method, url);
    if (body != null) {
      request.body = body;
    } else if (bodyBytes != null) {
      request.bodyBytes = bodyBytes;
    }
    request.headers['Authorization'] =
        'Basic ${base64Encode(utf8.encode('${remote.username}:${await remote.getRemotePassword()}'))}';
    return client.send(request);
  }

  @override
  Future<bool> createDefault(BuildContext context, {bool force = false}) async {
    try {
      var defaults = await DocumentDefaults.getDefaults(context);
      // test if directory exists
      final response = await _createRequest('', method: 'PROPFIND');
      if (response.statusCode != 404 && !force) {
        return false;
      }
      // Create directory if it doesn't exist
      await _createRequest('', method: 'MKCOL');
      await Future.wait(defaults.map((e) => updateTemplate(e)));
      return true;
    } on SocketException catch (_) {
      return false;
    }
  }

  @override
  Future<void> deleteTemplate(String name) async {
    final response = await _createRequest(name, method: 'DELETE');
    if (response.statusCode != 204) {
      throw Exception('Failed to delete template: ${response.statusCode}');
    }
  }

  @override
  Future<NoteData?> getTemplate(String name) async {
    if (name.startsWith('/')) {
      name = name.substring(1);
    }
    try {
      final response = await _createRequest(name);
      if (response.statusCode != 200) {
        return null;
      }
      final content = await response.stream.toBytes();
      cacheContent(name, content);
      return NoteData.fromData(content);
    } catch (e) {
      return getCachedTemplate(name);
    }
  }

  Future<NoteData?> getCachedTemplate(String name) async {
    final content = await getCachedContent(name);
    if (content == null) {
      return null;
    }
    return NoteData.fromData(content);
  }

  @override
  Future<List<NoteData>> getTemplates() async {
    try {
      final response = await _createRequest('', method: 'PROPFIND');
      if (response.statusCode == 404) {
        return [];
      }
      if (response.statusCode != 207) {
        throw Exception(
            'Failed to get templates: ${response.statusCode} ${response.reasonPhrase}');
      }
      final content = await response.stream.bytesToString();
      final xml = XmlDocument.parse(content);
      clearCachedContent();
      return (await Future.wait(xml
              .findAllElements('d:href')
              .where((element) => element.value?.endsWith('.bfly') ?? false)
              .map((e) {
        var path = e.value!.substring(remote.buildTemplatesUri().path.length);
        path = Uri.decodeComponent(path);
        return getTemplate(path);
      })))
          .whereNotNull()
          .toList();
    } on SocketException catch (_) {
      return await getCachedTemplates();
    }
  }

  @override
  Future<bool> hasTemplate(String name) {
    return _createRequest(name).then((response) => response.statusCode == 200);
  }

  @override
  Future<void> updateTemplate(NoteData template) {
    return _createRequest('${template.name}.bfly',
        method: 'PUT', bodyBytes: Uint8List.fromList(template.save()));
  }

  Future<List<NoteData>> getCachedTemplates() async {
    final cachedFiles = await getCachedFiles();
    return cachedFiles.values.map(NoteData.fromData).toList();
  }

  @override
  Future<String> getRemoteCacheDirectory() async =>
      p.join(await super.getRemoteCacheDirectory(), 'Templates');
}

class DavRemotePackFileSystem extends PackFileSystem with DavRemoteSystem {
  @override
  final DavRemoteStorage remote;

  DavRemotePackFileSystem(this.remote);

  final http.Client client = http.Client();
  Future<http.StreamedResponse> _createRequest(String path,
      {String method = 'GET', Uint8List? bodyBytes, String? body}) async {
    final url = remote.buildPacksUri(path: path.split('/'));
    final request = http.Request(method, url);
    if (body != null) {
      request.body = body;
    } else if (bodyBytes != null) {
      request.bodyBytes = bodyBytes;
    }
    request.headers['Authorization'] =
        'Basic ${base64Encode(utf8.encode('${remote.username}:${await remote.getRemotePassword()}'))}';
    return client.send(request);
  }

  @override
  Future<void> deletePack(String name) async {
    final response = await _createRequest(name, method: 'DELETE');
    if (response.statusCode != 204) {
      throw Exception('Failed to delete pack: ${response.statusCode}');
    }
  }

  @override
  Future<NoteData?> getPack(String name) async {
    if (name.startsWith('/')) {
      name = name.substring(1);
    }
    try {
      final response = await _createRequest(name);
      if (response.statusCode != 200) {
        return null;
      }
      final content = await response.stream.toBytes();
      cacheContent(name, content);
      return NoteData.fromData(content);
    } catch (e) {
      return getCachedPack(name);
    }
  }

  Future<NoteData?> getCachedPack(String name) async {
    final content = await getCachedContent(name);
    if (content == null) {
      return null;
    }
    return NoteData.fromData(content);
  }

  @override
  Future<List<NoteData>> getPacks() async {
    try {
      final response = await _createRequest('', method: 'PROPFIND');
      if (response.statusCode == 404) {
        return [];
      }
      if (response.statusCode != 207) {
        throw Exception(
            'Failed to get packs: ${response.statusCode} ${response.reasonPhrase}');
      }
      final content = await response.stream.bytesToString();
      final xml = XmlDocument.parse(content);
      clearCachedContent();
      return (await Future.wait(xml
              .findAllElements('d:href')
              .where((element) => element.value?.endsWith('.bfly') ?? false)
              .map((e) {
        var path = e.value!.substring(remote.buildPacksUri().path.length);
        path = Uri.decodeComponent(path);
        return getPack(path);
      })))
          .whereNotNull()
          .toList();
    } on SocketException catch (_) {
      return await getCachedPacks();
    }
  }

  @override
  Future<bool> hasPack(String name) {
    return _createRequest(name).then((response) => response.statusCode == 200);
  }

  @override
  Future<void> updatePack(NoteData pack) {
    return _createRequest('${pack.name}.bfly',
        method: 'PUT', bodyBytes: Uint8List.fromList(pack.save()));
  }

  Future<List<NoteData>> getCachedPacks() async {
    final cachedFiles = await getCachedFiles();
    return cachedFiles.values.map(NoteData.fromData).toList();
  }

  @override
  Future<String> getRemoteCacheDirectory() async =>
      p.join(await super.getRemoteCacheDirectory(), 'Packs');

  @override
  Future<bool> createDefault(BuildContext context, {bool force = false}) async {
    try {
      // test if directory exists
      final response = await _createRequest('', method: 'PROPFIND');
      if (response.statusCode != 404 && !force) {
        return false;
      }
      // Create directory if it doesn't exist
      await _createRequest('', method: 'MKCOL');
      await updatePack(await DocumentDefaults.getCorePack());
      return true;
    } on SocketException catch (_) {
      return false;
    }
  }
}
