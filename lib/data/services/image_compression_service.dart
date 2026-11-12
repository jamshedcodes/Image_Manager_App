import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

abstract interface class ImageCompressionService {
  Future<File> compressImage(
    String sourcePath, {
    int quality = 78,
    int maxDimension = 1280,
  });
}

class DeviceImageCompressionService implements ImageCompressionService {
  DeviceImageCompressionService({
    Future<Directory> Function()? tempDirectoryProvider,
  }) : _tempDirectoryProvider = tempDirectoryProvider ?? getTemporaryDirectory;

  final Future<Directory> Function() _tempDirectoryProvider;

  @override
  Future<File> compressImage(
    String sourcePath, {
    int quality = 78,
    int maxDimension = 1280,
  }) async {
    final tempDir = await _tempDirectoryProvider();
    final targetPath = p.join(
      tempDir.path,
      'compressed_${DateTime.now().microsecondsSinceEpoch}.jpg',
    );

    final compressed = await FlutterImageCompress.compressAndGetFile(
      sourcePath,
      targetPath,
      minWidth: maxDimension,
      minHeight: maxDimension,
      quality: quality,
      format: CompressFormat.jpeg,
    );

    if (compressed == null) {
      return File(sourcePath);
    }
    return File(compressed.path);
  }
}
