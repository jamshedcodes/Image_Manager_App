import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p;

import 'package:task/domain/models/uploaded_image.dart';

abstract interface class CloudImageService {
  Stream<List<UploadedImage>> watchImages();

  Future<UploadedImage> uploadImage({
    required File file,
    required String referenceName,
    void Function(double progress)? onProgress,
  });

  Future<void> deleteImage(UploadedImage image);
}

class FirebaseCloudImageService implements CloudImageService {
  FirebaseCloudImageService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _auth = auth ?? FirebaseAuth.instance;

  static const String _collectionName = 'images';
  static const String _storageFolder = 'uploads';

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final FirebaseAuth _auth;

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
    // Ensure auth before attaching snapshot listener to satisfy Firestore rules.
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

  @override
  Future<UploadedImage> uploadImage({
    required File file,
    required String referenceName,
    void Function(double progress)? onProgress,
  }) async {
    final uid = await _ensureAuthenticatedUserId();
    final extension = p.extension(file.path).toLowerCase();
    final safeExtension = extension.isEmpty ? '.jpg' : extension;
    final fileName = '${DateTime.now().microsecondsSinceEpoch}$safeExtension';
    final storagePath = '$_storageFolder/$uid/$fileName';

    final ref = _storage.ref().child(storagePath);
    final uploadTask = ref.putFile(
      file,
      SettableMetadata(contentType: 'image/jpeg'),
    );

    final progressSub = uploadTask.snapshotEvents.listen((snapshot) {
      final total = snapshot.totalBytes;
      if (total > 0 && onProgress != null) {
        onProgress((snapshot.bytesTransferred / total).clamp(0.0, 1.0));
      }
    });

    try {
      final snapshot = await uploadTask;
      final imageUrl = await snapshot.ref.getDownloadURL();
      final docRef = _imagesCollection.doc();
      final trimmedName = referenceName.trim();

      await docRef.set(<String, dynamic>{
        'referenceName': trimmedName,
        'imageUrl': imageUrl,
        'storagePath': storagePath,
        'uploadedBy': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return UploadedImage(
        id: docRef.id,
        referenceName: trimmedName,
        imageUrl: imageUrl,
        storagePath: storagePath,
        uploadedBy: uid,
        createdAt: DateTime.now(),
      );
    } finally {
      await progressSub.cancel();
    }
  }

  @override
  Future<void> deleteImage(UploadedImage image) async {
    if (image.storagePath.isNotEmpty) {
      try {
        await _storage.ref().child(image.storagePath).delete();
      } on FirebaseException catch (error) {
        if (error.code != 'object-not-found') {
          rethrow;
        }
      }
    }
    await _imagesCollection.doc(image.id).delete();
  }
}
