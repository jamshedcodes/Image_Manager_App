import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';

import 'package:task/data/repositories/image_repository.dart';
import 'package:task/domain/models/uploaded_image.dart';

class ImagesViewModel extends ChangeNotifier {
  ImagesViewModel({
    required this._imageRepository,
    Future<void> Function(String url)? cacheEvictor,
  }) : _cacheEvictor = cacheEvictor ?? _defaultCacheEvictor;

  final ImageRepository _imageRepository;
  final Future<void> Function(String url) _cacheEvictor;

  StreamSubscription<List<UploadedImage>>? _subscription;
  List<UploadedImage> _allImages = const <UploadedImage>[];
  final Set<String> _previousUrls = <String>{};
  final Set<String> _brokenImageIds = <String>{};

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<UploadedImage> get images => _allImages
      .where((item) => !_brokenImageIds.contains(item.id))
      .toList(growable: false);

  static Future<void> _defaultCacheEvictor(String url) async {
    await CachedNetworkImage.evictFromCache(url);
  }

  void startListening() {
    _subscription?.cancel();
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _subscription = _imageRepository.watchImages().listen(
      _onStreamData,
      onError: (_) {
        _isLoading = false;
        _errorMessage = 'Unable to sync images from Cloud Firestore.';
        notifyListeners();
      },
    );
  }

  void _onStreamData(List<UploadedImage> nextImages) {
    final nextUrls = nextImages
        .where((item) => item.isRemoteUrl)
        .map((item) => item.imageUrl)
        .toSet();
    final removedUrls = _previousUrls.difference(nextUrls);
    for (final url in removedUrls) {
      unawaited(_cacheEvictor(url));
    }

    _previousUrls
      ..clear()
      ..addAll(nextUrls);

    final activeIds = nextImages.map((item) => item.id).toSet();
    _brokenImageIds.removeWhere((id) => !activeIds.contains(id));

    _allImages = nextImages;
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  void markBrokenImage(String id) {
    if (_brokenImageIds.add(id)) {
      notifyListeners();
    }
  }

  Future<void> deleteImage(UploadedImage image) async {
    try {
      await _imageRepository.deleteImage(image);
      if (image.isRemoteUrl) {
        await _cacheEvictor(image.imageUrl);
      }
    } catch (_) {
      _errorMessage = 'Failed to delete image. Please try again.';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
