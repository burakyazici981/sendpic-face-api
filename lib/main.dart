import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'core/utils/app_router.dart';
import 'data/services/database_helper.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/camera_provider.dart';
import 'presentation/providers/content_provider.dart';
import 'core/services/dynamic_config_service.dart';
import 'core/services/update_service.dart';
import 'core/services/notification_service.dart';
import 'presentation/widgets/notification_widget.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize SQLite database only on mobile platforms
  if (!kIsWeb) {
    await DatabaseHelper().database;
  }
  
  // Initialize dynamic configuration service
  await DynamicConfigService().initialize();
  
  // Initialize notification service
  await NotificationService().initialize();
  
  runApp(const SendPicApp());
}

class SendPicApp extends StatefulWidget {
  const SendPicApp({super.key});

  @override
  State<SendPicApp> createState() => _SendPicAppState();
}

class _SendPicAppState extends State<SendPicApp> {
  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    // Fetch remote configuration
    await DynamicConfigService().fetchRemoteConfig();
    
    // Auto-switch URLs if needed
    await DynamicConfigService().autoSwitchUrls();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CameraProvider()),
        ChangeNotifierProvider(create: (_) => ContentProvider()),
      ],
      child: NotificationOverlay(
        child: MaterialApp.router(
          title: 'SendPic',
          theme: AppTheme.lightTheme,
          debugShowCheckedModeBanner: false,
          routerConfig: AppRouter.router,
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Clean up services
    UpdateService().dispose();
    NotificationService().dispose();
    super.dispose();
  }
}
