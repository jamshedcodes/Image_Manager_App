import 'package:cloud_firestore/cloud_firestore.dart';

class UploadedImage {
  const UploadedImage({
    required this.id,
    required this.referenceName,
    required this.imageUrl,
    required this.storagePath,
    required this.uploadedBy,
    this.createdAt,
  });

  final String id;
  final String referenceName;
  final String imageUrl;
  final String storagePath;
  final String uploadedBy;
  final DateTime? createdAt;

  bool get isRemoteUrl =>
      imageUrl.startsWith('http://') || imageUrl.startsWith('https://');

  factory UploadedImage.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final timestamp = data['createdAt'];
    return UploadedImage(
      id: doc.id,
      referenceName: (data['referenceName'] as String?) ?? '',
      imageUrl: (data['imageUrl'] as String?) ?? '',
      storagePath: (data['storagePath'] as String?) ?? '',
      uploadedBy: (data['uploadedBy'] as String?) ?? '',
      createdAt: timestamp is Timestamp ? timestamp.toDate() : null,
    );
  }

  factory UploadedImage.fromJson(Map<String, dynamic> json) {
    final rawCreatedAt = json['createdAt'];
    return UploadedImage(
      id: (json['id'] as String?) ?? '',
      referenceName: (json['referenceName'] as String?) ?? '',
      imageUrl: (json['imageUrl'] as String?) ?? '',
      storagePath: (json['storagePath'] as String?) ?? '',
      uploadedBy: (json['uploadedBy'] as String?) ?? 'local',
      createdAt: rawCreatedAt is String ? DateTime.tryParse(rawCreatedAt) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'referenceName': referenceName,
      'imageUrl': imageUrl,
      'storagePath': storagePath,
      'uploadedBy': uploadedBy,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toFirestoreMap() {
    return <String, dynamic>{
      'referenceName': referenceName,
      'imageUrl': imageUrl,
      'storagePath': storagePath,
      'uploadedBy': uploadedBy,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
