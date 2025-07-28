import 'package:flutter/material.dart';
import '../auth_service.dart';
import '../widgets/custom_app_bar.dart';
import '../models/focus_session.dart';
import '../services/app_detection_service.dart';
import 'focus_timer_screen.dart';

class ZenModeScreen extends StatefulWidget {
  const ZenModeScreen({super.key});

  @override
  State<ZenModeScreen> createState() => _ZenModeScreenState();
}

class _ZenModeScreenState extends State<ZenModeScreen> with WidgetsBindingObserver {
  // App selection
  final Map<String, bool> _blockedApps = {
    'com.facebook.katana': false,        // Facebook
    'com.instagram.android': false,      // Instagram
    'com.zhiliaoapp.musically': false,   // TikTok
    'com.twitter.android': false,        // Twitter
    'com.google.android.youtube': false, // YouTube
    'com.snapchat.android': false,       // Snapchat
    'com.reddit.frontpage': false,       // Reddit
  };

  // Timer selection
  Duration _selectedDuration = const Duration(minutes: 30);
  final List<Duration> _durationOptions = [
    const Duration(minutes: 15),
    const Duration(minutes: 30),
    const Duration(minutes: 45),
    const Duration(hours: 1),
    const Duration(hours: 2),
  ];

  final Map<String, String> _appDisplayNames = {
    'com.facebook.katana': 'Facebook',
    'com.instagram.android': 'Instagram',
    'com.zhiliaoapp.musically': 'TikTok',
    'com.twitter.android': 'Twitter',
    'com.google.android.youtube': 'YouTube',
    'com.snapchat.android': 'Snapchat',
    'com.reddit.frontpage': 'Reddit',
  };

  List<String> get _selectedBlockedApps {
    return _blockedApps.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();
  }

  final AppDetectionService _appDetectionService = AppDetectionService();
  bool _permissionsGranted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAndRequestPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _recheckPermissionsOnResume();
    }
  }

  Future<void> _recheckPermissionsOnResume() async {
    bool hasUsage = await _appDetectionService.hasUsageStatsPermission();
    bool hasOverlay = await _appDetectionService.hasOverlayPermission();
    setState(() {
      _permissionsGranted = hasUsage && hasOverlay;
    });
  }

  Future<void> _checkAndRequestPermissions() async {
    await _appDetectionService.initialize();
    bool hasUsage = await _appDetectionService.hasUsageStatsPermission();
    bool hasOverlay = await _appDetectionService.hasOverlayPermission();

    if (!hasUsage) {
      await _showPermissionDialog(
        title: 'Usage Access Required',
        message: 'To monitor blocked apps, please grant Usage Access permission.',
        onConfirm: () async {
          await _appDetectionService.requestUsageStatsPermission();
        },
      );
    }
    if (!hasOverlay) {
      await _showPermissionDialog(
        title: 'Appear on Top Required',
        message: 'To show overlays, please grant Appear on Top permission.',
        onConfirm: () async {
          await _appDetectionService.requestOverlayPermission();
        },
      );
    }
    // Re-check after requesting
    hasUsage = await _appDetectionService.hasUsageStatsPermission();
    hasOverlay = await _appDetectionService.hasOverlayPermission();
    setState(() {
      _permissionsGranted = hasUsage && hasOverlay;
    });
    if (!_permissionsGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please grant all required permissions to use Zen Mode.')),
        );
      }
    }
  }

  Future<void> _showPermissionDialog({required String title, required String message, required VoidCallback onConfirm}) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onConfirm();
            },
            child: const Text('Grant'),
          ),
        ],
      ),
    );
  }

  void _startFocusSession() async {
    if (!_permissionsGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please grant all required permissions before starting a focus session.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_selectedBlockedApps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one app to monitor'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Create focus session
    final session = FocusSession.create(
      blockedApps: _selectedBlockedApps,
      duration: _selectedDuration,
    );

    // Navigate to timer screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FocusTimerScreen(session: session),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Focus AI',
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await AuthService().signOut();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // App Selection
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select Apps to Monitor',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'You\'ll get notified when you open these apps during your focus session.',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  ..._blockedApps.keys.map((app) => SwitchListTile(
                    title: Text(_appDisplayNames[app] ?? app),
                    value: _blockedApps[app]!,
                    onChanged: (val) {
                      setState(() {
                        _blockedApps[app] = val;
                      });
                    },
                    secondary: const Icon(Icons.block),
                  )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Timer Selection
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Focus Duration',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: _durationOptions.map((duration) {
                      final isSelected = duration == _selectedDuration;
                      return ChoiceChip(
                        label: Text('${duration.inMinutes} min'),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _selectedDuration = duration;
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Start Session Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _startFocusSession,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
              child: const Text(
                'Start Focus Session',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }
} 