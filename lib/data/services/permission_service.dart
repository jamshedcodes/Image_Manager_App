import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

enum PermissionGrantResult {
  granted,
  denied,
  permanentlyDenied,
}

abstract interface class PermissionService {
  Future<PermissionGrantResult> requestCameraPermission();
  Future<PermissionGrantResult> requestGalleryPermission();
  Future<bool> openSettings();
}

class DevicePermissionService implements PermissionService {
  @override
  Future<PermissionGrantResult> requestCameraPermission() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return PermissionGrantResult.granted;
    }
    final status = await Permission.camera.request();
    return _mapStatus(status);
  }

  @override
  Future<PermissionGrantResult> requestGalleryPermission() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return PermissionGrantResult.granted;
    }

    final photosStatus = await Permission.photos.request();
    final mappedPhotos = _mapStatus(photosStatus);
    if (mappedPhotos == PermissionGrantResult.granted ||
        mappedPhotos == PermissionGrantResult.permanentlyDenied) {
      return mappedPhotos;
    }

    // Android 12 and below require READ_EXTERNAL_STORAGE via Permission.storage.
    if (Platform.isAndroid) {
      final storageStatus = await Permission.storage.request();
      return _mapStatus(storageStatus);
    }

    return mappedPhotos;
  }

  @override
  Future<bool> openSettings() => openAppSettings();

  PermissionGrantResult _mapStatus(PermissionStatus status) {
    if (status.isGranted || status.isLimited) {
      return PermissionGrantResult.granted;
    }
    if (status.isPermanentlyDenied || status.isRestricted) {
      return PermissionGrantResult.permanentlyDenied;
    }
    return PermissionGrantResult.denied;
  }
}
