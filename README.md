# Image_Manager_App

A Flutter application (**Image Manager**) for capturing, compressing, uploading, and managing reference images in real time.

## Features

- **Gallery & Camera Capture:** Pick photos from the device gallery or capture new photos with runtime permission handling (`permission_handler`, `image_picker`).
- **Client-Side Compression:** Compresses and resizes selected images (`flutter_image_compress`) before upload.
- **Upload Workflow & Progress:** Preview the selected image, enter a validated **Reference Name**, track live upload progress, and receive upload confirmations.
- **Real-Time Cloud Sync:** Uploads images to Cloudinary via `dio` and syncs metadata in real time with Cloud Firestore and Firebase Auth (`CloudinaryFirestoreImageService`), with support for Firebase Storage (`USE_FIREBASE_STORAGE=true`), custom REST backends (`API_BASE_URL`), or a local persistent fallback.
- **Cached 2-Column Gallery:** Displays synced images in a responsive 2-column grid (`cached_network_image`) with full-screen preview, deletion with cache eviction, and error/retry states.
- **Provider MVVM Architecture:** Pure `ChangeNotifier` + `Provider` state management (`HomeViewModel`, `UploadViewModel`, `ImagesViewModel`) with zero `setState`.
- **Custom Branding:** Configured with the **Image Manager** app name, custom Android adaptive/legacy launcher icons, iOS AppIcon set, and native launch splash screens.

## Tech Stack

- **Framework:** Flutter (Dart SDK `^3.13.1`)
- **State Management:** `provider`
- **Networking & Media:** `dio`, `image_picker`, `flutter_image_compress`, `cached_network_image`, `permission_handler`
- **Backend & Sync:** `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_storage`

## Project Structure

```text
lib/
├── core/config/             # Cloudinary configuration
├── data/
│   ├── repositories/        # ImageRepository abstraction
│   └── services/            # Cloudinary+Firestore, Firebase Storage, Dio REST, compression, picker & permissions
├── domain/models/           # UploadedImage model
└── ui/
    ├── core/                # App theme and reusable dashed border widget
    └── features/
        ├── home/            # HomeShell & HomeViewModel (tab navigation)
        ├── upload/          # UploadView & UploadViewModel
        └── images/          # ImagesView & ImagesViewModel
```

## Getting Started

1. **Clone the repository**
   ```bash
   git clone https://github.com/jamshedcodes/Image_Manager_App.git
   cd Image_Manager_App
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   flutter run
   ```

   Optional backend overrides via `--dart-define`:
   ```bash
   flutter run --dart-define=CLOUDINARY_CLOUD_NAME=<your_cloud_name> --dart-define=CLOUDINARY_UPLOAD_PRESET=<your_preset>
   flutter run --dart-define=USE_FIREBASE_STORAGE=true
   flutter run --dart-define=API_BASE_URL=https://your-api.example.com
   ```

4. **Run tests**
   ```bash
   flutter test
   ```

# Image_Manager_App
Flutter Image Manager app built with Provider MVVM, Cloudinary + Dio uploads, Cloud Firestore real-time sync, client-side image compression, permission handling, and a cached gallery grid with preview and deletion.
