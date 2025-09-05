import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'core/utils/app_router.dart';
import 'data/services/database_helper.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/camera_provider.dart';
import 'presentation/providers/content_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize SQLite database only on mobile platforms
  if (!kIsWeb) {
    await DatabaseHelper().database;
  }
  
  runApp(const SendPicApp());
}

class SendPicApp extends StatelessWidget {
  const SendPicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CameraProvider()),
        ChangeNotifierProvider(create: (_) => ContentProvider()),
      ],
      child: MaterialApp.router(
        title: 'SendPic',
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        routerConfig: AppRouter.router,
      ),
    );
  }
}
