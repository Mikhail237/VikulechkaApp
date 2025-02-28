import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uni_links/uni_links.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'onboarding_screen.dart';
import 'home_screen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Инициализируем Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Обрабатываем deep links только для не-веб платформ
  if (!kIsWeb) {
    _handleIncomingLinks();
  }

  runApp(MyApp(
    analytics: FirebaseAnalytics.instance,
  ));
}

class ErrorApp extends StatelessWidget {
  final String error;

  const ErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text(error, style: const TextStyle(fontFamily: 'NotoSans')),
        ),
      ),
    );
  }
}

void _handleIncomingLinks() {
  uriLinkStream.listen((Uri? uri) {
    if (uri != null && uri.queryParameters.containsKey('recipe')) {
      final recipeName = uri.queryParameters['recipe'];
      if (recipeName != null) {
        runApp(MyApp(
          initialRecipe: recipeName,
          analytics: FirebaseAnalytics.instance,
        ));
      }
    }
  }, onError: (err) {
    print('Ошибка обработки deep link: $err');
  });
}

class MyApp extends StatefulWidget {
  final String? initialRecipe;
  final FirebaseAnalytics analytics;

  const MyApp({
    super.key,
    this.initialRecipe,
    required this.analytics,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _darkMode = false;
  bool _hasCompletedOnboarding = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _darkMode = prefs.getBool('darkMode') ?? false;
      _hasCompletedOnboarding = prefs.getBool('hasCompletedOnboarding') ?? false;
    });
  }

  Future<void> _checkNotificationPermissions() async {
    final permissionsGranted = await _requestNotificationPermissions();
    if (!permissionsGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Разрешения для уведомлений не предоставлены',
            style: TextStyle(fontFamily: 'NotoSans'),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<bool> _requestNotificationPermissions() async {
    // Реализация запроса разрешений для конкретной платформы
    return true;
  }

  void _toggleTheme() {
    setState(() {
      _darkMode = !_darkMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    final vikulechkaColors = ColorScheme(
      brightness: _darkMode ? Brightness.dark : Brightness.light,
      background: _darkMode ? const Color(0xFF4A2D7A) : const Color(0xFFE6C7FF),
      primary: const Color(0xFFD1B2FF),
      secondary: const Color(0xFF9C27B0),
      surface: _darkMode ? const Color(0xFF5A3A8A) : Colors.white,
      onSurface: _darkMode ? Colors.white : Colors.black87,
      error: Colors.red,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onError: Colors.white,
      onBackground: Colors.black87,
    );

    final mikhailColors = ColorScheme(
      brightness: _darkMode ? Brightness.dark : Brightness.light,
      background: _darkMode ? const Color(0xFF1E1433) : const Color(0xFF2D1E3F),
      primary: const Color(0xFF7B5AA2),
      secondary: const Color(0xFFD3C4E9),
      surface: _darkMode ? const Color(0xFF3D2C5F) : const Color(0xFF5A3A8A),
      onSurface: Colors.white,
      error: Colors.red,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onError: Colors.white,
      onBackground: Colors.white,
    );

    final baseTheme = ThemeData(
      fontFamily: 'Roboto',
      textTheme: const TextTheme(
        bodyMedium: TextStyle(
          fontFamily: 'NotoSans',
          fontSize: 16,
        ),
        titleLarge: TextStyle(
          fontFamily: 'NotoSans',
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        labelLarge: TextStyle(
          fontFamily: 'NotoSans',
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      cardTheme: CardTheme(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.fuchsia: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
      splashFactory: InkRipple.splashFactory,
      useMaterial3: true,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ru', ''),
        Locale('en', ''),
      ],
      locale: const Locale('ru'),
      theme: baseTheme.copyWith(
        colorScheme: (widget.initialRecipe != null ? vikulechkaColors : mikhailColors),
      ),
      darkTheme: baseTheme.copyWith(
        colorScheme: (widget.initialRecipe != null ? vikulechkaColors : mikhailColors),
        brightness: Brightness.dark,
      ),
      themeMode: _darkMode ? ThemeMode.dark : ThemeMode.light,
      home: _buildHomeScreen(),
      onGenerateRoute: (settings) {
        if (settings.name == '/recipe') {
          final recipeName = settings.arguments as String?;
          return MaterialPageRoute(
            builder: (context) => HomeScreen(initialRecipe: recipeName),
          );
        }
        return null;
      },
    );
  }

  Widget _buildHomeScreen() {
    if (!_hasCompletedOnboarding) {
      return OnboardingScreen(
        onComplete: () async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('hasCompletedOnboarding', true);
          setState(() {
            _hasCompletedOnboarding = true;
          });
        },
      );
    }

    return HomeScreen(
      initialRecipe: widget.initialRecipe,
    );
  }
}