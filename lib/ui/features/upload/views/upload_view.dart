import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:task/data/repositories/image_repository.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/dashed_border_box.dart';
import '../view_models/upload_view_model.dart';

class UploadView extends StatefulWidget {
  const UploadView({
    super.key,
    required this.onImageSubmitted,
  });

  final VoidCallback onImageSubmitted;

  @override
  State<UploadView> createState() => _UploadViewState();
}

class _UploadViewState extends State<UploadView> {
  final TextEditingController _nameController = TextEditingController();
  UploadViewModel? _viewModel;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final viewModel = context.read<UploadViewModel>();
    if (_viewModel != viewModel) {
      _viewModel?.removeListener(_handleViewModelUpdates);
      _viewModel = viewModel;
      _viewModel!.addListener(_handleViewModelUpdates);
    }
  }

  @override
  void dispose() {
    _viewModel?.removeListener(_handleViewModelUpdates);
    _nameController.dispose();
    super.dispose();
  }

  void _handleViewModelUpdates() {
    final viewModel = _viewModel;
    if (!mounted || viewModel == null) return;

    final permanentlyDenied = viewModel.permanentlyDeniedPermission;
    if (permanentlyDenied != null) {
      viewModel.clearPermanentlyDeniedPermission();
      _showPermissionSettingsDialog(permanentlyDenied);
      return;
    }

    final error = viewModel.statusError;
    if (error != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error)));
      viewModel.clearStatusError();
    }
  }

  Future<void> _showPermissionSettingsDialog(
    DeniedPermissionType type,
  ) async {
    final isCamera = type == DeniedPermissionType.camera;
    final label = isCamera ? 'Camera' : 'Files & Photos';
    final viewModel = context.read<UploadViewModel>();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('$label Permission Required'),
          content: Text(
            'Please allow $label access in app settings to ${isCamera ? 'take a photo' : 'pick an image'}.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await viewModel.openAppSettings();
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
              ),
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleSubmit() async {
    HapticFeedback.lightImpact();
    FocusScope.of(context).unfocus();
    final saved = await context.read<UploadViewModel>().submit(
      _nameController.text,
    );
    if (saved != null && mounted) {
      _nameController.clear();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Image uploaded'),
            duration: Duration(seconds: 2),
          ),
        );
      widget.onImageSubmitted();
    }
  }

  void _handleClearSelection() {
    HapticFeedback.selectionClick();
    _nameController.clear();
    context.read<UploadViewModel>().clearSelection();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UploadViewModel>(
      builder: (context, viewModel, _) {
        final selectedPath = viewModel.selectedImagePath;
        if (selectedPath == null) {
          return _PickerPromptBody(
            isBusy: viewModel.isPicking,
            onGalleryTap: () {
              HapticFeedback.lightImpact();
              viewModel.pickFromGallery();
            },
            onCameraTap: () {
              HapticFeedback.lightImpact();
              viewModel.pickFromCamera();
            },
          );
        }

        return _SelectedImageFormBody(
          imagePath: selectedPath,
          controller: _nameController,
          validationError: viewModel.validationError,
          isSubmitting: viewModel.isSubmitting,
          uploadStage: viewModel.uploadStage,
          uploadProgress: viewModel.uploadProgress,
          onRemoveTap: _handleClearSelection,
          onNameChanged: (_) => viewModel.clearValidationError(),
          onSubmitTap: _handleSubmit,
        );
      },
    );
  }
}

class _PickerPromptBody extends StatelessWidget {
  const _PickerPromptBody({
    required this.isBusy,
    required this.onGalleryTap,
    required this.onCameraTap,
  });

  final bool isBusy;
  final VoidCallback onGalleryTap;
  final VoidCallback onCameraTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight - 48).clamp(0, double.infinity),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DashedBorderBox(
                      key: const Key('browser_gallery_button'),
                      height: 170,
                      borderRadius: 12,
                      borderColor: AppColors.primaryGreen,
                      onTap: isBusy ? null : onGalleryTap,
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.image,
                            size: 52,
                            color: AppColors.primaryGreen,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Browser Gallery',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: AppColors.divider,
                            thickness: 1,
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'OR',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: AppColors.divider,
                            thickness: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    DashedBorderBox(
                      key: const Key('open_camera_button'),
                      height: 50,
                      borderRadius: 10,
                      borderColor: AppColors.primaryGreen,
                      onTap: isBusy ? null : onCameraTap,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.photo_camera,
                            size: 20,
                            color: AppColors.primaryGreen,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Open camera',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SelectedImageFormBody extends StatelessWidget {
  const _SelectedImageFormBody({
    required this.imagePath,
    required this.controller,
    required this.validationError,
    required this.isSubmitting,
    required this.uploadStage,
    required this.uploadProgress,
    required this.onRemoveTap,
    required this.onNameChanged,
    required this.onSubmitTap,
  });

  final String imagePath;
  final TextEditingController controller;
  final String? validationError;
  final bool isSubmitting;
  final UploadStage uploadStage;
  final double? uploadProgress;
  final VoidCallback onRemoveTap;
  final ValueChanged<String> onNameChanged;
  final VoidCallback onSubmitTap;

  String _stageLabel() {
    switch (uploadStage) {
      case UploadStage.compressing:
        return 'Compressing image...';
      case UploadStage.uploading:
        final pct = ((uploadProgress ?? 0) * 100).round();
        return 'Uploading image... $pct%';
      case UploadStage.idle:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final previewHeight =
                (constraints.maxHeight * 0.60).clamp(200.0, 520.0);
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: previewHeight,
                    width: double.infinity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(
                          File(imagePath),
                          fit: BoxFit.cover,
                          cacheWidth: 1280,
                          errorBuilder: (_, _, _) => Container(
                            color: Colors.grey.shade200,
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.broken_image_outlined,
                              size: 48,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 14,
                          right: 14,
                          child: Semantics(
                            button: true,
                            label: 'Remove selected image',
                            child: Material(
                              color: AppColors.removeRed,
                              shape: const CircleBorder(),
                              elevation: 1,
                              child: InkWell(
                                key: const Key('remove_image_button'),
                                customBorder: const CircleBorder(),
                                onTap: isSubmitting ? null : onRemoveTap,
                                child: const Padding(
                                  padding: EdgeInsets.all(6),
                                  child: Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                    child: Column(
                      children: [
                        TextField(
                          key: const Key('reference_name_field'),
                          controller: controller,
                          enabled: !isSubmitting,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.done,
                          onChanged: onNameChanged,
                          onSubmitted: (_) => onSubmitTap(),
                          decoration: InputDecoration(
                            hintText: 'Reference Name',
                            hintStyle: const TextStyle(
                              color: AppColors.hintText,
                              fontSize: 15,
                            ),
                            errorText: validationError,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: AppColors.inputBorder,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: AppColors.inputBorder,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: AppColors.primaryGreen,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                        if (isSubmitting) ...[
                          const SizedBox(height: 16),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              key: const Key('upload_progress_indicator'),
                              value: uploadStage == UploadStage.uploading
                                  ? uploadProgress
                                  : null,
                              color: AppColors.primaryGreen,
                              backgroundColor: AppColors.divider,
                              minHeight: 6,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _stageLabel(),
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        FilledButton(
                          key: const Key('submit_button'),
                          onPressed: isSubmitting ? null : onSubmitTap,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(124, 46),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Submit',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
