import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app/bindings/app_dependencies.dart';
import 'app/routes/app_pages.dart';
import 'app/theme/app_theme.dart';
import 'core/constants/app_constants.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // cryptography_flutter registers itself automatically, routing
  // `cryptography` algorithms to native Android implementations.
  await AppDependencies.init();
  runApp(const UChatApp());
}

class UChatApp extends StatelessWidget {
  const UChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      initialRoute: AppPages.initial,
      getPages: AppPages.pages,
    );
  }
}
