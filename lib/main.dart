import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'auth_screen.dart'; 
import 'screens/main_screen.dart';
import 'services/cache_service.dart';
import 'dart:io';
import 'widgets/custom_app_bar.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    print('=== FIREBASE INITIALIZATION DEBUG ===');
    print('Checking network connectivity...');
    
    // Test basic internet connectivity
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        print('✓ Internet connectivity: OK');
      }
    } catch (e) {
      print('✗ Internet connectivity: FAILED - $e');
    }
    
    print('Initializing Firebase...');
    print('Current platform: ${DefaultFirebaseOptions.currentPlatform}');
    print('Android options: ${DefaultFirebaseOptions.android}');
    
    // Test Firebase configuration
    print('Testing Firebase configuration...');
    final androidOptions = DefaultFirebaseOptions.android;
    print('Project ID: ${androidOptions.projectId}');
    print('App ID: ${androidOptions.appId}');
    print('API Key: ${androidOptions.apiKey?.substring(0, 10)}...');
    
    // Test if we can access the Firebase project
    print('Testing Firebase project accessibility...');
    try {
      final response = await HttpClient().getUrl(
        Uri.parse('https://${androidOptions.projectId}.firebaseio.com/.json')
      );
      final httpResponse = await response.close();
      print('✓ Firebase project is accessible (HTTP ${httpResponse.statusCode})');
    } catch (e) {
      print('✗ Firebase project accessibility test failed: $e');
    }
    
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✓ Firebase initialized successfully');
    
    // Configure Firebase Auth persistence for web
    print('Checking platform for auth persistence...');
    if (kIsWeb) {
      print('Configuring Firebase Auth persistence for web...');
      // For web, Firebase Auth automatically handles persistence
      // No need to explicitly set persistence
      print('✓ Firebase Auth persistence automatically configured for web');
      
      // Add a small delay to ensure Firebase is fully initialized
      await Future.delayed(const Duration(milliseconds: 100));
      
      print('Enabling Firestore offline persistence for web...');
      await FirebaseFirestore.instance.enablePersistence();
      print('✓ Firestore offline persistence enabled for web');
    } else {
      print('Skipping persistence configuration for mobile platform (handled by default)');
      // For mobile, persistence is enabled by default
      print('✓ Mobile persistence is enabled by default');
    }
    
    // Test Firestore connection
    print('Testing Firestore connection...');
    try {
      await FirebaseFirestore.instance.collection('test').limit(1).get();
      print('✓ Firestore connection: OK');
    } catch (e) {
      print('✗ Firestore connection: FAILED - $e');
    }
    
    // Initialize cache service for optimistic updates
    print('Initializing cache service...');
    await CacheService().initialize();
    print('✓ Cache service initialized');
    print('Initializing notification service...');
    await NotificationService().initialize();
    print('✓ Notification service initialized');
    // If a study time is stored, reschedule the daily reminder on app start
    final stored = await NotificationService().loadStudyTime();
    if (stored != null) {
      // We need remaining tasks to craft the message; use cache snapshot
      final tasks = CacheService().getTasksFromCache();
      final remaining = tasks.where((t) => !t.completed).length;
      await NotificationService().scheduleDailyStudyReminder(stored, remainingTasks: remaining);
      print('✓ Daily study reminder scheduled from stored time');
    }
    
    runApp(const MyApp());
  } catch (e, stackTrace) {
    print('=== FIREBASE INITIALIZATION ERROR ===');
    print('Error type: ${e.runtimeType}');
    print('Error message: $e');
    print('Stack trace: $stackTrace');
    
    // For now, let's try to run without Firebase to test if the app works
    print('Attempting to run app without Firebase...');
    runApp(OfflineApp(error: e.toString(), stackTrace: stackTrace.toString()));
  }
}

class ErrorApp extends StatelessWidget {
  const ErrorApp({super.key, required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Focus AI - Error',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        useMaterial3: true,
      ),
      home: Scaffold(
        appBar: const CustomAppBar(
          title: 'Focus AI',
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Failed to initialize the app',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please check your internet connection and try again.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Error Details:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      error,
                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  // Restart the app
                  main();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OfflineApp extends StatefulWidget {
  const OfflineApp({super.key, required this.error, required this.stackTrace});

  final String error;
  final String stackTrace;

  @override
  State<OfflineApp> createState() => _OfflineAppState();
}

class _OfflineAppState extends State<OfflineApp> {
  bool _isRetrying = false;

  Future<void> _retryFirebase() async {
    setState(() {
      _isRetrying = true;
    });

    try {
      print('=== RETRYING FIREBASE INITIALIZATION ===');
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      print('✓ Firebase retry successful!');
      
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MyApp()),
        );
      }
    } catch (e) {
      print('✗ Firebase retry failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Retry failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRetrying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Focus AI - Offline Mode',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
        useMaterial3: true,
      ),
      home: Scaffold(
        appBar: const CustomAppBar(
          title: 'Focus AI',
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off, size: 64, color: Colors.orange),
              const SizedBox(height: 16),
              const Text(
                'Offline Mode',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Firebase could not be initialized. The app is running in offline mode.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Error Details:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.error,
                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Stack Trace:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.stackTrace,
                      style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Troubleshooting:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                '• Check your internet connection\n'
                '• Make sure you have a stable network\n'
                '• Try switching between WiFi and mobile data\n'
                '• Restart the app\n'
                '• Check if Firebase project is active',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isRetrying ? null : _retryFirebase,
                child: _isRetrying 
                  ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('Retrying...'),
                      ],
                    )
                  : const Text('Retry with Firebase'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Focus AI',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show loading indicator while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        // If user is logged in, show main screen
        if (snapshot.hasData && snapshot.data != null) {
          return const MainScreen();
        }
        
        // If user is not logged in, show auth screen
        return const AuthScreen();
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
