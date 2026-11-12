class CloudinaryConfig {
  const CloudinaryConfig({
    required this.cloudName,
    required this.uploadPreset,
  });

  static const String _envCloudName = String.fromEnvironment(
    'CLOUDINARY_CLOUD_NAME',
    defaultValue: '',
  );
  static const String _envUploadPreset = String.fromEnvironment(
    'CLOUDINARY_UPLOAD_PRESET',
    defaultValue: '',
  );

  static const String _defaultCloudName = 'oavgldk2';
  static const String _defaultUploadPreset = 'p2rj0noz';

  factory CloudinaryConfig.fromEnvironment() {
    return CloudinaryConfig(
      cloudName: _envCloudName.isNotEmpty ? _envCloudName : _defaultCloudName,
      uploadPreset:
          _envUploadPreset.isNotEmpty ? _envUploadPreset : _defaultUploadPreset,
    );
  }

  final String cloudName;
  final String uploadPreset;

  bool get isConfigured =>
      cloudName.trim().isNotEmpty && uploadPreset.trim().isNotEmpty;
}
