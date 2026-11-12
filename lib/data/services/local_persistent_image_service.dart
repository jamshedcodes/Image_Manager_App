import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:task/data/services/firebase_image_service.dart';
import 'package:task/domain/models/uploaded_image.dart';

class LocalPersistentImageService implements CloudImageService {
  LocalPersistentImageService({
    Future<Directory> Function()? directoryProvider,
  }) : _directoryProvider =
            directoryProvider ?? getApplicationDocumentsDirectory;

  static const String _imagesFolderName = 'uploaded_images';
  static const String _metadataFileName = 'uploaded_images.json';

  final Future<Directory> Function() _directoryProvider;
  final StreamController<List<UploadedImage>> _controller =
      StreamController<List<UploadedImage>>.broadcast();
  List<UploadedImage>? _items;

  Future<Directory> _getImagesDirectory() async {
    final baseDir = await _directoryProvider();
    final imagesDir = Directory(p.join(baseDir.path, _imagesFolderName));
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }
    return imagesDir;
  }

  Future<File> _getMetadataFile() async {
    final baseDir = await _directoryProvider();
    return File(p.join(baseDir.path, _metadataFileName));
  }

  Future<List<UploadedImage>> _loadFromDisk() async {
    final metadataFile = await _getMetadataFile();
    if (!await metadataFile.exists()) {
      return const <UploadedImage>[];
    }
    final raw = await metadataFile.readAsString();
    if (raw.trim().isEmpty) {
      return const <UploadedImage>[];
    }
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(UploadedImage.fromJson)
        .toList(growable: false);
  }

  Future<void> _saveToDisk(List<UploadedImage> items) async {
    final metadataFile = await _getMetadataFile();
    await metadataFile.writeAsString(
      jsonEncode(items.map((item) => item.toJson()).toList(growable: false)),
    );
  }

  @override
  Stream<List<UploadedImage>> watchImages() async* {
    _items ??= await _loadFromDisk();
    yield List<UploadedImage>.unmodifiable(_items!);
    yield* _controller.stream;
  }

  @override
  Future<UploadedImage> uploadImage({
    required File file,
    required String referenceName,
    void Function(double progress)? onProgress,
  }) async {
    _items ??= await _loadFromDisk();
    onProgress?.call(0.3);

    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final imagesDir = await _getImagesDirectory();
    final ext = p.extension(file.path).isEmpty ? '.jpg' : p.extension(file.path);
    final destinationPath = p.join(imagesDir.path, '$id$ext');
    await file.copy(destinationPath);
    onProgress?.call(0.8);

    final entry = UploadedImage(
      id: id,
      referenceName: referenceName.trim(),
      imageUrl: destinationPath,
      storagePath: destinationPath,
      uploadedBy: 'local',
      createdAt: DateTime.now(),
    );

    final updated = <UploadedImage>[entry, ..._items!];
    await _saveToDisk(updated);
    _items = updated;
    onProgress?.call(1.0);

    if (!_controller.isClosed) {
      _controller.add(List<UploadedImage>.unmodifiable(updated));
    }
    return entry;
  }

  @override
  Future<void> deleteImage(UploadedImage image) async {
    _items ??= await _loadFromDisk();
    final updated = _items!
        .where((item) => item.id != image.id)
        .toList(growable: false);
    await _saveToDisk(updated);
    _items = updated;

    final file = File(image.storagePath);
    if (await file.exists()) {
      await file.delete();
    }

    if (!_controller.isClosed) {
      _controller.add(List<UploadedImage>.unmodifiable(updated));
    }
  }
}
