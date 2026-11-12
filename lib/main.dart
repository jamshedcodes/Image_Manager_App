import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/config/cloudinary_config.dart';
import 'data/repositories/image_repository.dart';
import 'data/services/cloudinary_firestore_image_service.dart';
import 'data/services/dio_image_service.dart';
import 'data/services/firebase_image_service.dart';
import 'data/services/image_compression_service.dart';
import 'data/services/image_picker_service.dart';
import 'data/services/local_persistent_image_service.dart';
import 'data/services/permission_service.dart';
import 'firebase_options.dart';
import 'ui/core/theme/app_theme.dart';
import 'ui/features/home/view_models/home_view_model.dart';
import 'ui/features/home/views/home_shell.dart';
import 'ui/features/images/view_models/images_view_model.dart';
import 'ui/features/images/views/images_view.dart';
import 'ui/features/upload/view_models/upload_view_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const apiBaseUrl = String.fromEnvironment('API_BASE_URL');
  const useFirebaseStorage = bool.fromEnvironment('USE_FIREBASE_STORAGE');
  final CloudImageService cloudService = await _resolveImageService(
    apiBaseUrl: apiBaseUrl,
    useFirebaseStorage: useFirebaseStorage,
  );

  runApp(ImageReferenceApp(cloudService: cloudService));
}

Future<CloudImageService> _resolveImageService({
  required String apiBaseUrl,
  required bool useFirebaseStorage,
}) async {
  if (apiBaseUrl.isNotEmpty) {
    return DioCloudImageService(baseUrl: apiBaseUrl);
  }
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    if (useFirebaseStorage) {
      return FirebaseCloudImageService();
    }
    return CloudinaryFirestoreImageService(
      config: CloudinaryConfig.fromEnvironment(),
    );
  } catch (_) {
    return LocalPersistentImageService();
  }
}

class ImageReferenceApp extends StatelessWidget {
  const ImageReferenceApp({
    super.key,
    this.cloudService,
    this.compressionService,
    this.pickerService,
    this.permissionService,
    this.cacheEvictor,
    this.imageBuilder,
  });

  final CloudImageService? cloudService;
  final ImageCompressionService? compressionService;
  final ImagePickerService? pickerService;
  final PermissionService? permissionService;
  final Future<void> Function(String url)? cacheEvictor;
  final CloudImageWidgetBuilder? imageBuilder;

  @override
  Widget build(BuildContext context) {
    final resolvedCloud = cloudService ?? LocalPersistentImageService();
    final resolvedCompression =
        compressionService ?? DeviceImageCompressionService();
    final resolvedPicker = pickerService ?? DeviceImagePickerService();
    final resolvedPermissions = permissionService ?? DevicePermissionService();

    return MultiProvider(
      providers: [
        Provider<ImageRepository>(
          create: (_) => ImageRepository(
            cloudService: resolvedCloud,
            compressionService: resolvedCompression,
          ),
        ),
        ChangeNotifierProvider<HomeViewModel>(
          create: (_) => HomeViewModel(),
        ),
        ChangeNotifierProvider<UploadViewModel>(
          create: (context) => UploadViewModel(
            pickerService: resolvedPicker,
            imageRepository: context.read<ImageRepository>(),
            permissionService: resolvedPermissions,
          ),
        ),
        ChangeNotifierProvider<ImagesViewModel>(
          create: (context) => ImagesViewModel(
            imageRepository: context.read<ImageRepository>(),
            cacheEvictor: cacheEvictor,
          )..startListening(),
        ),
      ],
      child: MaterialApp(
        title: 'Image Manager',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: HomeShell(imageBuilder: imageBuilder),
      ),
    );
  }
}
