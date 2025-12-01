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
  final Map<String, bool> _blockedApps = {
    'com.facebook.katana': false,
    'com.instagram.android': false,
    'com.zhiliaoapp.musically': false,
    'com.twitter.android': false,
    'com.google.android.youtube': false,
    'com.snapchat.android': false,
    'com.reddit.frontpage': false,
  };

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

  List<String> get _selectedBlockedApps => _blockedApps.entries
      .where((entry) => entry.value)
      .map((entry) => entry.key)
      .toList();

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
    setState(() => _permissionsGranted = hasUsage && hasOverlay);
  }

  Future<void> _checkAndRequestPermissions() async {
    await _appDetectionService.initialize();

    bool hasUsage = await _appDetectionService.hasUsageStatsPermission();
    bool hasOverlay = await _appDetectionService.hasOverlayPermission();

    if (!hasUsage) {
      await _showPermissionDialog(
        title: 'Usage Access Required',
        message: 'To monitor blocked apps, please grant Usage Access permission.',
        onConfirm: () async => _appDetectionService.requestUsageStatsPermission(),
      );
    }

    if (!hasOverlay) {
      await _showPermissionDialog(
        title: 'Appear on Top Required',
        message: 'To show overlays, please grant Appear on Top permission.',
        onConfirm: () async => _appDetectionService.requestOverlayPermission(),
      );
    }

    hasUsage = await _appDetectionService.hasUsageStatsPermission();
    hasOverlay = await _appDetectionService.hasOverlayPermission();

    setState(() => _permissionsGranted = hasUsage && hasOverlay);
  }

  Future<void> _showPermissionDialog({
    required String title,
    required String message,
    required VoidCallback onConfirm,
  }) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
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

  void _startFocusSession() {
    if (!_permissionsGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please grant all permissions.'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_selectedBlockedApps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one app.'), backgroundColor: Colors.red),
      );
      return;
    }

    final session = FocusSession.create(
      blockedApps: _selectedBlockedApps,
      duration: _selectedDuration,
    );

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => FocusTimerScreen(session: session)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'Focus AI'),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // 🔹 Apps section (condensed)
            Expanded(
              child: Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Select Apps', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Expanded(
                        child: GridView.count(
                          crossAxisCount: 1,
                          childAspectRatio: 6.9,
                          children: _blockedApps.keys.map((app) {
                            return SwitchListTile(
                              title: Text(_appDisplayNames[app] ?? app, style: const TextStyle(fontSize: 13)),
                              value: _blockedApps[app]!,
                              onChanged: (v) => setState(() => _blockedApps[app] = v),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 2),

            // 🔹 Duration section (compact)
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Focus Duration', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _durationOptions.map((duration) {
                        return ChoiceChip(
                          label: Text('${duration.inMinutes} min'),
                          selected: duration == _selectedDuration,
                          onSelected: (selected) {
                            if (selected) setState(() => _selectedDuration = duration);
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // 🔹 Start Button — neutral color
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _startFocusSession,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFBFC5D2), // Neutral grey-blue
                  foregroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Start Focus Session', style: TextStyle(fontSize: 16)),
              ),
            )
          ],
        ),
      ),
    );
  }
}
