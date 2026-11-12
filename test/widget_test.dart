import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:task/data/services/firebase_image_service.dart';
import 'package:task/data/services/image_compression_service.dart';
import 'package:task/data/services/image_picker_service.dart';
import 'package:task/data/services/permission_service.dart';
import 'package:task/domain/models/uploaded_image.dart';
import 'package:task/main.dart';

/// Valid 1x1 transparent PNG bytes so `Image.file` decodes cleanly in widget tests.
final _samplePngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aW0cAAAAASUVORK5CYII=',
);

class _FakeImagePickerService implements ImagePickerService {
  _FakeImagePickerService({
    this.galleryPath,
    this.cameraPath,
  });

  String? galleryPath;
  String? cameraPath;

  @override
  Future<String?> pickFromGallery() async => galleryPath;

  @override
  Future<String?> pickFromCamera() async => cameraPath;
}

class _FakePermissionService implements PermissionService {
  _FakePermissionService({
    this.cameraResult = PermissionGrantResult.granted,
    this.galleryResult = PermissionGrantResult.granted,
  });

  PermissionGrantResult cameraResult;
  PermissionGrantResult galleryResult;
  bool openedSettings = false;

  @override
  Future<PermissionGrantResult> requestCameraPermission() async => cameraResult;

  @override
  Future<PermissionGrantResult> requestGalleryPermission() async =>
      galleryResult;

  @override
  Future<bool> openSettings() async {
    openedSettings = true;
    return true;
  }
}

class _FakeCompressionService implements ImageCompressionService {
  int? lastQuality;
  int? lastMaxDimension;

  @override
  Future<File> compressImage(
    String sourcePath, {
    int quality = 78,
    int maxDimension = 1280,
  }) async {
    lastQuality = quality;
    lastMaxDimension = maxDimension;
    return File(sourcePath);
  }
}

class _FakeCloudImageService implements CloudImageService {
  _FakeCloudImageService({List<UploadedImage>? initialImages}) {
    if (initialImages != null) {
      _items.addAll(initialImages);
    }
  }

  final List<UploadedImage> _items = <UploadedImage>[];
  final StreamController<List<UploadedImage>> _controller =
      StreamController<List<UploadedImage>>.broadcast();
  Completer<void>? pendingUploadCompleter;
  bool failNextWatch = false;

  @override
  Stream<List<UploadedImage>> watchImages() async* {
    if (failNextWatch) {
      failNextWatch = false;
      throw Exception('Network unavailable');
    }
    yield List<UploadedImage>.unmodifiable(_items);
    yield* _controller.stream;
  }

  void emitRemoteDeletion(String id) {
    _items.removeWhere((item) => item.id == id);
    _controller.add(List<UploadedImage>.unmodifiable(_items));
  }

  @override
  Future<UploadedImage> uploadImage({
    required File file,
    required String referenceName,
    void Function(double progress)? onProgress,
  }) async {
    onProgress?.call(0.5);
    if (pendingUploadCompleter != null) {
      await pendingUploadCompleter!.future;
    }
    onProgress?.call(1.0);

    final id = 'doc_${_items.length + 1}';
    final created = UploadedImage(
      id: id,
      referenceName: referenceName.trim(),
      imageUrl: 'https://example.com/$id.jpg',
      storagePath: 'uploads/test_uid/$id.jpg',
      uploadedBy: 'test_uid',
      createdAt: DateTime.now(),
    );
    _items.insert(0, created);
    _controller.add(List<UploadedImage>.unmodifiable(_items));
    return created;
  }

  @override
  Future<void> deleteImage(UploadedImage image) async {
    _items.removeWhere((item) => item.id == image.id);
    _controller.add(List<UploadedImage>.unmodifiable(_items));
  }

  Future<void> dispose() => _controller.close();
}

void main() {
  late Directory tempRoot;
  late File sampleGalleryFile;
  late File sampleCameraFile;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('task_widget_test_');
    sampleGalleryFile = File(p.join(tempRoot.path, 'gallery_sample.png'))
      ..writeAsBytesSync(_samplePngBytes);
    sampleCameraFile = File(p.join(tempRoot.path, 'camera_sample.png'))
      ..writeAsBytesSync(_samplePngBytes);
  });

  tearDown(() async {
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  });

  ImageReferenceApp buildTestApp({
    required _FakeImagePickerService pickerService,
    _FakePermissionService? permissionService,
    _FakeCloudImageService? cloudService,
    _FakeCompressionService? compressionService,
    List<String>? evictedUrls,
    Set<String>? brokenIds,
  }) {
    final cloud = cloudService ?? _FakeCloudImageService();
    return ImageReferenceApp(
      cloudService: cloud,
      compressionService: compressionService ?? _FakeCompressionService(),
      pickerService: pickerService,
      permissionService: permissionService ?? _FakePermissionService(),
      cacheEvictor: (url) async => evictedUrls?.add(url),
      imageBuilder: (_, item, onBrokenImage) {
        if (brokenIds != null && brokenIds.contains(item.id)) {
          WidgetsBinding.instance.addPostFrameCallback((_) => onBrokenImage());
          return const SizedBox.shrink();
        }
        return Container(
          key: Key('cloud_image_${item.id}'),
          color: Colors.green.shade100,
        );
      },
    );
  }

  testWidgets('Initial Upload screen shows gallery, camera, and bottom tabs',
      (WidgetTester tester) async {
    final cloud = _FakeCloudImageService();
    addTearDown(cloud.dispose);

    await tester.pumpWidget(
      buildTestApp(
        pickerService: _FakeImagePickerService(),
        cloudService: cloud,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Browser Gallery'), findsOneWidget);
    expect(find.text('OR'), findsOneWidget);
    expect(find.text('Open camera'), findsOneWidget);
    expect(find.text('Upload'), findsOneWidget);
    expect(find.text('Images'), findsOneWidget);
  });

  testWidgets('Pick, compress, show upload progress, submit, and sync to Images tab',
      (WidgetTester tester) async {
    final cloud = _FakeCloudImageService()
      ..pendingUploadCompleter = Completer<void>();
    addTearDown(cloud.dispose);
    final compression = _FakeCompressionService();
    final picker = _FakeImagePickerService(
      galleryPath: sampleGalleryFile.path,
      cameraPath: sampleCameraFile.path,
    );

    await tester.pumpWidget(
      buildTestApp(
        pickerService: picker,
        cloudService: cloud,
        compressionService: compression,
      ),
    );
    await tester.pumpAndSettle();

    // Pick from gallery and remove via red X button
    await tester.tap(find.byKey(const Key('browser_gallery_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('remove_image_button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('remove_image_button')));
    await tester.pumpAndSettle();
    expect(find.text('Browser Gallery'), findsOneWidget);

    // Pick from camera
    await tester.tap(find.byKey(const Key('open_camera_button')));
    await tester.pumpAndSettle();

    // Validation on empty reference name
    await tester.tap(find.byKey(const Key('submit_button')));
    await tester.pumpAndSettle();
    expect(find.text('Please enter a reference name'), findsOneWidget);

    // Enter name and start upload
    await tester.enterText(
      find.byKey(const Key('reference_name_field')),
      'Reference Name 1',
    );
    await tester.tap(find.byKey(const Key('submit_button')));
    await tester.pump();

    expect(find.byKey(const Key('upload_progress_indicator')), findsOneWidget);
    expect(compression.lastQuality, 78);
    expect(compression.lastMaxDimension, 1280);

    // Complete upload and verify automatic switch + Firestore stream sync
    cloud.pendingUploadCompleter!.complete();
    await tester.pumpAndSettle();

    expect(find.text('Reference Name 1'), findsOneWidget);
    expect(find.byKey(const Key('cloud_image_doc_1')), findsOneWidget);
  });

  testWidgets('Real-time deletion evicts cache and hides broken 404 images',
      (WidgetTester tester) async {
    const first = UploadedImage(
      id: 'img_1',
      referenceName: 'Reference Name 1',
      imageUrl: 'https://example.com/img_1.jpg',
      storagePath: 'uploads/uid/img_1.jpg',
      uploadedBy: 'uid',
    );
    const broken = UploadedImage(
      id: 'img_broken',
      referenceName: 'Broken Image',
      imageUrl: 'https://example.com/missing.jpg',
      storagePath: 'uploads/uid/missing.jpg',
      uploadedBy: 'uid',
    );

    final cloud = _FakeCloudImageService(initialImages: [first, broken]);
    addTearDown(cloud.dispose);
    final evictedUrls = <String>[];

    await tester.pumpWidget(
      buildTestApp(
        pickerService: _FakeImagePickerService(),
        cloudService: cloud,
        evictedUrls: evictedUrls,
        brokenIds: {'img_broken'},
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Images'));
    await tester.pumpAndSettle();

    // Broken image is hidden automatically, valid image remains visible
    expect(find.text('Broken Image'), findsNothing);
    expect(find.text('Reference Name 1'), findsOneWidget);

    // Simulate backend deletion (Cloud Function removes Firestore doc)
    cloud.emitRemoteDeletion('img_1');
    await tester.pumpAndSettle();

    expect(find.text('Reference Name 1'), findsNothing);
    expect(evictedUrls, contains('https://example.com/img_1.jpg'));
    expect(find.text('No images uploaded yet'), findsOneWidget);
  });

  testWidgets('Preview dialog deletes image and evicts cache',
      (WidgetTester tester) async {
    const item = UploadedImage(
      id: 'img_5',
      referenceName: 'Reference Name 5',
      imageUrl: 'https://example.com/img_5.jpg',
      storagePath: 'uploads/uid/img_5.jpg',
      uploadedBy: 'uid',
    );
    final cloud = _FakeCloudImageService(initialImages: [item]);
    addTearDown(cloud.dispose);
    final evictedUrls = <String>[];

    await tester.pumpWidget(
      buildTestApp(
        pickerService: _FakeImagePickerService(),
        cloudService: cloud,
        evictedUrls: evictedUrls,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Images'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reference Name 5'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Delete image'));
    await tester.pumpAndSettle();

    expect(find.text('Reference Name 5'), findsNothing);
    expect(evictedUrls, contains('https://example.com/img_5.jpg'));
  });

  testWidgets('Denied and permanently denied permissions show appropriate prompts',
      (WidgetTester tester) async {
    final cloud = _FakeCloudImageService();
    addTearDown(cloud.dispose);
    final permissions = _FakePermissionService(
      galleryResult: PermissionGrantResult.denied,
      cameraResult: PermissionGrantResult.permanentlyDenied,
    );

    await tester.pumpWidget(
      buildTestApp(
        pickerService: _FakeImagePickerService(
          galleryPath: sampleGalleryFile.path,
          cameraPath: sampleCameraFile.path,
        ),
        permissionService: permissions,
        cloudService: cloud,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('browser_gallery_button')));
    await tester.pumpAndSettle();
    expect(
      find.text('File/gallery permission is required to pick an image.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('open_camera_button')));
    await tester.pumpAndSettle();
    expect(find.text('Camera Permission Required'), findsOneWidget);

    await tester.tap(find.text('Open Settings'));
    await tester.pumpAndSettle();
    expect(permissions.openedSettings, isTrue);
  });

  testWidgets('Images tab shows error state and recovers on Retry',
      (WidgetTester tester) async {
    const item = UploadedImage(
      id: 'img_retry',
      referenceName: 'Recovered Image',
      imageUrl: 'https://example.com/recovered.jpg',
      storagePath: 'uploads/uid/recovered.jpg',
      uploadedBy: 'uid',
    );
    final cloud = _FakeCloudImageService(initialImages: [item])
      ..failNextWatch = true;
    addTearDown(cloud.dispose);

    await tester.pumpWidget(
      buildTestApp(
        pickerService: _FakeImagePickerService(),
        cloudService: cloud,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Images'));
    await tester.pumpAndSettle();

    expect(find.text('Unable to sync images from Cloud Firestore.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Recovered Image'), findsOneWidget);
  });
}
