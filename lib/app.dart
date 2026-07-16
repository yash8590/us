import 'package:flutter/material.dart';

import 'screens/splash/splash_screen.dart';
import 'services/auth_service.dart';
import 'utils/colors.dart';

class UsApp extends StatefulWidget {
  const UsApp({super.key});

  static UsAppState of(BuildContext context) =>
      context.findAncestorStateOfType<UsAppState>()!;

  @override
  State<UsApp> createState() => UsAppState();
}

class UsAppState extends State<UsApp> with WidgetsBindingObserver {
  final AuthService _authService = AuthService();
  ThemeMode _themeMode = ThemeMode.system;

  void changeTheme(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Set user presence online when app opens
    _authService.updatePresence(true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Dynamically update Firestore user presence
    if (state == AppLifecycleState.resumed) {
      _authService.updatePresence(true);
    } else {
      _authService.updatePresence(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "UsChat",

      // Light Theme configuration
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: WAColors.primary,
        scaffoldBackgroundColor: WAColors.backgroundLight,
        colorScheme: ColorScheme.fromSeed(
          seedColor: WAColors.primary,
          brightness: Brightness.light,
          primary: WAColors.primary,
          secondary: WAColors.accent,
          background: WAColors.backgroundLight,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: WAColors.backgroundLight,
          foregroundColor: WAColors.textPrimaryLight,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: WAColors.textPrimaryLight,
          ),
        ),
        useMaterial3: true,
      ),

      // Dark Theme configuration
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: WAColors.primary,
        scaffoldBackgroundColor: WAColors.backgroundDark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: WAColors.primary,
          brightness: Brightness.dark,
          primary: WAColors.primary,
          secondary: WAColors.accentDark,
          surface: WAColors.appBarDark,
          background: WAColors.backgroundDark,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: WAColors.backgroundDark,
          foregroundColor: WAColors.textPrimaryDark,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: WAColors.textPrimaryDark,
          ),
        ),
        useMaterial3: true,
      ),

      themeMode: _themeMode,

      home: const SplashScreen(),
    );
  }
}