import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:task/data/repositories/image_repository.dart';
import 'package:task/data/services/image_picker_service.dart';
import 'package:task/data/services/permission_service.dart';
import 'package:task/domain/models/uploaded_image.dart';

enum DeniedPermissionType {
  camera,
  gallery,
}

class UploadViewModel extends ChangeNotifier {
  UploadViewModel({
    required this._pickerService,
    required this._imageRepository,
    required this._permissionService,
  });

  final ImagePickerService _pickerService;
  final ImageRepository _imageRepository;
  final PermissionService _permissionService;

  String? _selectedImagePath;
  String? get selectedImagePath => _selectedImagePath;

  bool _isPicking = false;
  bool get isPicking => _isPicking;

  bool _isSubmitting = false;
  bool get isSubmitting => _isSubmitting;

  UploadStage _uploadStage = UploadStage.idle;
  UploadStage get uploadStage => _uploadStage;

  double? _uploadProgress;
  double? get uploadProgress => _uploadProgress;

  String? _validationError;
  String? get validationError => _validationError;

  String? _statusError;
  String? get statusError => _statusError;

  DeniedPermissionType? _permanentlyDeniedPermission;
  DeniedPermissionType? get permanentlyDeniedPermission =>
      _permanentlyDeniedPermission;

  bool get hasSelectedImage => _selectedImagePath != null;

  Future<void> pickFromGallery() async {
    await _pickImage(
      permissionType: DeniedPermissionType.gallery,
      requestPermission: _permissionService.requestGalleryPermission,
      pickerAction: _pickerService.pickFromGallery,
      deniedMessage: 'File/gallery permission is required to pick an image.',
    );
  }

  Future<void> pickFromCamera() async {
    await _pickImage(
      permissionType: DeniedPermissionType.camera,
      requestPermission: _permissionService.requestCameraPermission,
      pickerAction: _pickerService.pickFromCamera,
      deniedMessage: 'Camera permission is required to take a photo.',
    );
  }

  Future<void> _pickImage({
    required DeniedPermissionType permissionType,
    required Future<PermissionGrantResult> Function() requestPermission,
    required Future<String?> Function() pickerAction,
    required String deniedMessage,
  }) async {
    if (_isPicking || _isSubmitting) return;
    _isPicking = true;
    _statusError = null;
    _permanentlyDeniedPermission = null;
    notifyListeners();

    try {
      final permissionResult = await requestPermission();
      if (permissionResult == PermissionGrantResult.permanentlyDenied) {
        _permanentlyDeniedPermission = permissionType;
        return;
      }
      if (permissionResult != PermissionGrantResult.granted) {
        _statusError = deniedMessage;
        return;
      }

      final path = await pickerAction();
      if (path != null) {
        _selectedImagePath = path;
        _validationError = null;
      }
    } on PlatformException catch (error) {
      _statusError = error.message ?? 'Unable to access media source.';
    } catch (_) {
      _statusError = 'Unable to pick image. Please try again.';
    } finally {
      _isPicking = false;
      notifyListeners();
    }
  }

  Future<void> openAppSettings() => _permissionService.openSettings();

  void clearSelection() {
    if (_isSubmitting) return;
    _selectedImagePath = null;
    _validationError = null;
    _statusError = null;
    _permanentlyDeniedPermission = null;
    notifyListeners();
  }

  void clearValidationError() {
    if (_validationError != null) {
      _validationError = null;
      notifyListeners();
    }
  }

  void clearStatusError() {
    if (_statusError != null) {
      _statusError = null;
      notifyListeners();
    }
  }

  void clearPermanentlyDeniedPermission() {
    if (_permanentlyDeniedPermission != null) {
      _permanentlyDeniedPermission = null;
      notifyListeners();
    }
  }

  Future<UploadedImage?> submit(String referenceName) async {
    final path = _selectedImagePath;
    if (path == null || _isSubmitting) return null;

    final trimmedName = referenceName.trim();
    if (trimmedName.isEmpty) {
      _validationError = 'Please enter a reference name';
      notifyListeners();
      return null;
    }

    _isSubmitting = true;
    _uploadStage = UploadStage.compressing;
    _uploadProgress = null;
    _validationError = null;
    _statusError = null;
    notifyListeners();

    try {
      final saved = await _imageRepository.uploadImage(
        sourcePath: path,
        referenceName: trimmedName,
        onStageChanged: (stage) {
          _uploadStage = stage;
          if (stage == UploadStage.compressing) {
            _uploadProgress = null;
          }
          notifyListeners();
        },
        onProgress: (progress) {
          _uploadProgress = progress;
          notifyListeners();
        },
      );
      _selectedImagePath = null;
      return saved;
    } on StateError catch (error) {
      _statusError = error.message;
      return null;
    } on FirebaseException catch (error) {
      _statusError = error.message ?? 'Upload failed (${error.code}).';
      return null;
    } catch (_) {
      _statusError = 'Failed to upload image. Please try again.';
      return null;
    } finally {
      _isSubmitting = false;
      _uploadStage = UploadStage.idle;
      _uploadProgress = null;
      notifyListeners();
    }
  }
}
