// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/firebase/firebase_initializer.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'services/notifications/firebase_messaging_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (Spark tier safe initialization)
  await FirebaseInitializer.initialize();

  // Lock orientation to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: AppColors.backgroundLight,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  // Initialize flutter_local_notifications
  try {
    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {},
    );

    const channel = AndroidNotificationChannel(
      'paw_aid_rescue_alerts',
      'Rescue Alerts',
      description: 'Critical notifications for PAW-AID rescue operations.',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    );
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Initialize Firebase Cloud Messaging & token registration
    FirebaseMessagingService().initialize().catchError((e) {
      debugPrint('[FCM] Startup registration deferred: $e');
    });
  } catch (e) {
    debugPrint('Local notifications bypassed: $e');
  }

  runApp(const ProviderScope(child: PawAidApp()));
}

class PawAidApp extends ConsumerWidget {
  const PawAidApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'PAW-AID',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
