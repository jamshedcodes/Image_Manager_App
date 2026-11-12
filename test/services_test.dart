import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:task/core/config/cloudinary_config.dart';
import 'package:task/data/services/cloudinary_firestore_image_service.dart';
import 'package:task/data/services/dio_image_service.dart';
import 'package:task/data/services/local_persistent_image_service.dart';
import 'package:task/domain/models/uploaded_image.dart';

class _FakeDioAdapter implements HttpClientAdapter {
  final List<Map<String, dynamic>> serverRecords = <Map<String, dynamic>>[];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'GET' && options.path == '/images') {
      return ResponseBody.fromString(
        jsonEncode(serverRecords),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }

    if (options.method == 'POST' && options.path == '/images') {
      if (requestStream != null) {
        await requestStream.drain<void>();
      }
      final created = <String, dynamic>{
        'id': 'remote_1',
        'referenceName': 'Remote Image',
        'imageUrl': 'https://cdn.example.com/remote_1.jpg',
        'storagePath': 'uploads/remote_1.jpg',
        'uploadedBy': 'user_1',
        'createdAt': DateTime.now().toIso8601String(),
      };
      serverRecords.insert(0, created);
      return ResponseBody.fromString(
        jsonEncode(created),
        201,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }

    if (options.method == 'POST' &&
        options.path == 'https://api.cloudinary.com/v1_1/demo_cloud/image/upload') {
      if (requestStream != null) {
        await requestStream.drain<void>();
      }
      return ResponseBody.fromString(
        jsonEncode(<String, dynamic>{
          'secure_url':
              'https://res.cloudinary.com/demo_cloud/image/upload/v1/images_manager/sample.jpg',
          'public_id': 'images_manager/sample',
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }

    if (options.method == 'DELETE' && options.path.startsWith('/images/')) {
      final id = options.path.split('/').last;
      serverRecords.removeWhere((row) => row['id'] == id);
      return ResponseBody.fromString('', 204);
    }

    return ResponseBody.fromString('Not Found', 404);
  }
}

void main() {
  late Directory tempRoot;
  late Directory docsDir;
  late File sampleFile;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('task_services_test_');
    docsDir = Directory(p.join(tempRoot.path, 'docs'))..createSync();
    sampleFile = File(p.join(tempRoot.path, 'sample.jpg'))
      ..writeAsBytesSync(<int>[1, 2, 3, 4]);
  });

  tearDown(() async {
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  });

  test('LocalPersistentImageService saves, streams, persists, and deletes', () async {
    final service = LocalPersistentImageService(
      directoryProvider: () async => docsDir,
    );

    final emissions = <List<UploadedImage>>[];
    final sub = service.watchImages().listen(emissions.add);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(emissions.last, isEmpty);

    final progressValues = <double>[];
    final uploaded = await service.uploadImage(
      file: sampleFile,
      referenceName: 'Reference Name 1',
      onProgress: progressValues.add,
    );

    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(progressValues, isNotEmpty);
    expect(File(uploaded.imageUrl).existsSync(), isTrue);
    expect(emissions.last.length, 1);
    expect(emissions.last.first.referenceName, 'Reference Name 1');

    // Verify persistence across new service instance
    final reloaded = LocalPersistentImageService(
      directoryProvider: () async => docsDir,
    );
    final persistedList = await reloaded.watchImages().first;
    expect(persistedList.length, 1);
    expect(persistedList.first.id, uploaded.id);

    await service.deleteImage(uploaded);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(File(uploaded.imageUrl).existsSync(), isFalse);
    expect(emissions.last, isEmpty);

    await sub.cancel();
  });

  test('DioCloudImageService uploads, streams, and deletes via Dio', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
    dio.httpClientAdapter = _FakeDioAdapter();

    final service = DioCloudImageService(
      baseUrl: 'https://api.example.com',
      dio: dio,
    );

    final emissions = <List<UploadedImage>>[];
    final sub = service.watchImages().listen(emissions.add);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(emissions.last, isEmpty);

    final uploaded = await service.uploadImage(
      file: sampleFile,
      referenceName: 'Remote Image',
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(uploaded.isRemoteUrl, isTrue);
    expect(emissions.last.length, 1);

    await service.deleteImage(uploaded);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(emissions.last, isEmpty);

    await sub.cancel();
  });

  test('CloudinaryConfig and uploadToCloudinary validate and upload via Dio',
      () async {
    final dio = Dio()..httpClientAdapter = _FakeDioAdapter();
    expect(
      const CloudinaryConfig(cloudName: '', uploadPreset: '').isConfigured,
      isFalse,
    );

    const config = CloudinaryConfig(
      cloudName: 'demo_cloud',
      uploadPreset: 'unsigned_preset',
    );
    expect(config.isConfigured, isTrue);

    final service = CloudinaryFirestoreImageService(
      config: config,
      dio: dio,
    );
    final result = await service.uploadToCloudinary(
      file: sampleFile,
      folder: 'images_manager/uid',
    );
    expect(
      result.imageUrl,
      'https://res.cloudinary.com/demo_cloud/image/upload/v1/images_manager/sample.jpg',
    );
    expect(result.storagePath, 'images_manager/sample');
  });
}
