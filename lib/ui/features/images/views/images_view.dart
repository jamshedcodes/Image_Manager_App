import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../domain/models/uploaded_image.dart';
import '../../../core/theme/app_theme.dart';
import '../view_models/images_view_model.dart';

typedef CloudImageWidgetBuilder = Widget Function(
  BuildContext context,
  UploadedImage item,
  VoidCallback onBrokenImage,
);

class ImagesView extends StatelessWidget {
  const ImagesView({
    super.key,
    this.imageBuilder,
  });

  final CloudImageWidgetBuilder? imageBuilder;

  Widget _buildNetworkImage(
    BuildContext context,
    UploadedImage item,
    VoidCallback onBrokenImage, {
    int? memCacheWidth,
  }) {
    final customBuilder = imageBuilder;
    if (customBuilder != null) {
      return customBuilder(context, item, onBrokenImage);
    }

    if (!item.isRemoteUrl) {
      return Image.file(
        File(item.imageUrl),
        fit: BoxFit.cover,
        cacheWidth: memCacheWidth,
        errorBuilder: (_, _, _) {
          WidgetsBinding.instance.addPostFrameCallback((_) => onBrokenImage());
          return const SizedBox.shrink();
        },
      );
    }

    return CachedNetworkImage(
      imageUrl: item.imageUrl,
      fit: BoxFit.cover,
      memCacheWidth: memCacheWidth,
      fadeInDuration: const Duration(milliseconds: 200),
      placeholder: (_, _) => Container(
        color: Colors.grey.shade100,
        alignment: Alignment.center,
        child: const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primaryGreen,
          ),
        ),
      ),
      errorWidget: (_, _, _) {
        WidgetsBinding.instance.addPostFrameCallback((_) => onBrokenImage());
        return const SizedBox.shrink();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Consumer<ImagesViewModel>(
        builder: (context, viewModel, _) {
          if (viewModel.isLoading && viewModel.images.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            );
          }

          if (viewModel.errorMessage != null && viewModel.images.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      viewModel.errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: viewModel.startListening,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (viewModel.images.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.photo_library_outlined,
                      size: 48,
                      color: AppColors.hintText,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'No images uploaded yet',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Select or capture an image from the Upload tab.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            itemCount: viewModel.images.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 16,
              childAspectRatio: 0.78,
            ),
            itemBuilder: (context, index) {
              final item = viewModel.images[index];
              return _ImageGridTile(
                item: item,
                imageContent: _buildNetworkImage(
                  context,
                  item,
                  () => viewModel.markBrokenImage(item.id),
                  memCacheWidth: 600,
                ),
                onTap: () {
                  HapticFeedback.selectionClick();
                  _showPreviewDialog(context, viewModel, item);
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showPreviewDialog(
    BuildContext context,
    ImagesViewModel viewModel,
    UploadedImage item,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final screenHeight = MediaQuery.sizeOf(dialogContext).height;
        return Dialog(
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 420,
              maxHeight: screenHeight * 0.85,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Flexible(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: _buildNetworkImage(
                      dialogContext,
                      item,
                      () {
                        viewModel.markBrokenImage(item.id);
                        if (Navigator.of(dialogContext).canPop()) {
                          Navigator.of(dialogContext).pop();
                        }
                      },
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.referenceName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Delete image',
                        onPressed: () async {
                          Navigator.of(dialogContext).pop();
                          await viewModel.deleteImage(item);
                        },
                        icon: const Icon(
                          Icons.delete_outline,
                          color: AppColors.removeRed,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ImageGridTile extends StatelessWidget {
  const _ImageGridTile({
    required this.item,
    required this.imageContent,
    required this.onTap,
  });

  final UploadedImage item;
  final Widget imageContent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: imageContent,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.referenceName,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
