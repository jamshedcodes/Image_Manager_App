import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path/path.dart' as p;

import 'package:task/core/config/cloudinary_config.dart';
import 'package:task/data/services/firebase_image_service.dart';
import 'package:task/domain/models/uploaded_image.dart';

class CloudinaryFirestoreImageService implements CloudImageService {
  CloudinaryFirestoreImageService({
    required this._config,
    Dio? dio,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 20),
                receiveTimeout: const Duration(seconds: 45),
              ),
            ),
        _firestoreOverride = firestore,
        _authOverride = auth;

  static const String _collectionName = 'images';

  final CloudinaryConfig _config;
  final Dio _dio;
  final FirebaseFirestore? _firestoreOverride;
  final FirebaseAuth? _authOverride;

  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _imagesCollection =>
      _firestore.collection(_collectionName);

  Future<String> _ensureAuthenticatedUserId() async {
    final existingUser = _auth.currentUser;
    if (existingUser != null) {
      return existingUser.uid;
    }
    final credential = await _auth.signInAnonymously();
    return credential.user?.uid ?? 'anonymous';
  }

  @override
  Stream<List<UploadedImage>> watchImages() async* {
    await _ensureAuthenticatedUserId();
    yield* _imagesCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(UploadedImage.fromFirestore)
              .where((item) => item.imageUrl.isNotEmpty)
              .toList(growable: false),
        );
  }

  Future<({String imageUrl, String storagePath})> uploadToCloudinary({
    required File file,
    required String folder,
    void Function(double progress)? onProgress,
  }) async {
    if (!_config.isConfigured) {
      throw StateError(
        'Cloudinary is not configured. Set CLOUDINARY_CLOUD_NAME and '
        'CLOUDINARY_UPLOAD_PRESET in lib/core/config/cloudinary_config.dart.',
      );
    }

    final endpoint =
        'https://api.cloudinary.com/v1_1/${_config.cloudName.trim()}/image/upload';

    final formData = FormData.fromMap(<String, dynamic>{
      'file': await MultipartFile.fromFile(
        file.path,
        filename: p.basename(file.path),
      ),
      'upload_preset': _config.uploadPreset.trim(),
      'folder': folder,
    });

    final response = await _dio.post<Map<String, dynamic>>(
      endpoint,
      data: formData,
      onSendProgress: (sent, total) {
        if (total > 0 && onProgress != null) {
          onProgress((sent / total).clamp(0.0, 1.0));
        }
      },
    );

    final body = response.data ?? const <String, dynamic>{};
    final secureUrl = body['secure_url'] as String?;
    final publicId = body['public_id'] as String?;
    if (secureUrl == null || secureUrl.isEmpty || publicId == null) {
      throw StateError('Unexpected Cloudinary response.');
    }

    return (imageUrl: secureUrl, storagePath: publicId);
  }

  @override
  Future<UploadedImage> uploadImage({
    required File file,
    required String referenceName,
    void Function(double progress)? onProgress,
  }) async {
    final uid = await _ensureAuthenticatedUserId();
    final uploaded = await uploadToCloudinary(
      file: file,
      folder: 'images_manager/$uid',
      onProgress: onProgress,
    );

    final docRef = _imagesCollection.doc();
    final trimmedName = referenceName.trim();

    await docRef.set(<String, dynamic>{
      'referenceName': trimmedName,
      'imageUrl': uploaded.imageUrl,
      'storagePath': uploaded.storagePath,
      'uploadedBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return UploadedImage(
      id: docRef.id,
      referenceName: trimmedName,
      imageUrl: uploaded.imageUrl,
      storagePath: uploaded.storagePath,
      uploadedBy: uid,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<void> deleteImage(UploadedImage image) async {
    await _imagesCollection.doc(image.id).delete();
  }
}
