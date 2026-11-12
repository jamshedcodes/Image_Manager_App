import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import 'package:task/data/services/firebase_image_service.dart';
import 'package:task/domain/models/uploaded_image.dart';

class DioCloudImageService implements CloudImageService {
  DioCloudImageService({
    required String baseUrl,
    Dio? dio,
  }) : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl,
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 30),
              ),
            );

  final Dio _dio;
  final StreamController<List<UploadedImage>> _controller =
      StreamController<List<UploadedImage>>.broadcast();
  List<UploadedImage> _items = const <UploadedImage>[];

  @override
  Stream<List<UploadedImage>> watchImages() async* {
    await _refresh();
    yield _items;
    yield* _controller.stream;
  }

  Future<void> _refresh() async {
    final response = await _dio.get<List<dynamic>>('/images');
    final data = response.data ?? const <dynamic>[];
    _items = data
        .whereType<Map<String, dynamic>>()
        .map(UploadedImage.fromJson)
        .toList(growable: false);
    if (!_controller.isClosed) {
      _controller.add(_items);
    }
  }

  @override
  Future<UploadedImage> uploadImage({
    required File file,
    required String referenceName,
    void Function(double progress)? onProgress,
  }) async {
    final formData = FormData.fromMap(<String, dynamic>{
      'referenceName': referenceName.trim(),
      'file': await MultipartFile.fromFile(
        file.path,
        filename: p.basename(file.path),
      ),
    });

    final response = await _dio.post<Map<String, dynamic>>(
      '/images',
      data: formData,
      onSendProgress: (sent, total) {
        if (total > 0 && onProgress != null) {
          onProgress((sent / total).clamp(0.0, 1.0));
        }
      },
    );

    final created = UploadedImage.fromJson(
      response.data ?? const <String, dynamic>{},
    );
    _items = <UploadedImage>[created, ..._items];
    if (!_controller.isClosed) {
      _controller.add(_items);
    }
    return created;
  }

  @override
  Future<void> deleteImage(UploadedImage image) async {
    await _dio.delete<void>('/images/${image.id}');
    _items = _items.where((item) => item.id != image.id).toList(growable: false);
    if (!_controller.isClosed) {
      _controller.add(_items);
    }
  }
}
