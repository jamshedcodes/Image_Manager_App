import 'dart:io';

import 'package:task/data/services/firebase_image_service.dart';
import 'package:task/data/services/image_compression_service.dart';
import 'package:task/domain/models/uploaded_image.dart';

enum UploadStage {
  idle,
  compressing,
  uploading,
}

class ImageRepository {
  ImageRepository({
    required this._cloudService,
    required this._compressionService,
  });

  final CloudImageService _cloudService;
  final ImageCompressionService _compressionService;

  Stream<List<UploadedImage>> watchImages() => _cloudService.watchImages();

  Future<UploadedImage> uploadImage({
    required String sourcePath,
    required String referenceName,
    void Function(UploadStage stage)? onStageChanged,
    void Function(double progress)? onProgress,
  }) async {
    onStageChanged?.call(UploadStage.compressing);
    final compressedFile = await _compressionService.compressImage(sourcePath);

    onStageChanged?.call(UploadStage.uploading);
    onProgress?.call(0.0);

    try {
      return await _cloudService.uploadImage(
        file: compressedFile,
        referenceName: referenceName,
        onProgress: onProgress,
      );
    } finally {
      if (compressedFile.path != sourcePath && await compressedFile.exists()) {
        try {
          await compressedFile.delete();
        } on FileSystemException {
          // Ignore temp cleanup failures.
        }
      }
      onStageChanged?.call(UploadStage.idle);
    }
  }

  Future<void> deleteImage(UploadedImage image) =>
      _cloudService.deleteImage(image);
}
