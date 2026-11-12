import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../images/views/images_view.dart';
import '../../upload/views/upload_view.dart';
import '../view_models/home_view_model.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({
    super.key,
    this.imageBuilder,
  });

  final CloudImageWidgetBuilder? imageBuilder;

  @override
  Widget build(BuildContext context) {
    final homeViewModel = context.watch<HomeViewModel>();
    final currentIndex = homeViewModel.currentIndex;

    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: [
          UploadView(onImageSubmitted: homeViewModel.showImagesTab),
          ImagesView(imageBuilder: imageBuilder),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) {
          if (currentIndex != index) {
            FocusScope.of(context).unfocus();
            homeViewModel.selectTab(index);
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Upload',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle_outlined),
            label: 'Images',
          ),
        ],
      ),
    );
  }
}
