import 'dart:async';
import 'package:flutter/material.dart';
import '../models/focus_session.dart';
import '../services/app_detection_service.dart';
import '../widgets/custom_app_bar.dart';
import '../services/notification_service.dart';
import '../services/gamification_service.dart';
import '../services/focus_session_service.dart';

class FocusTimerScreen extends StatefulWidget {
  final FocusSession session;

  const FocusTimerScreen({super.key, required this.session});

  @override
  State<FocusTimerScreen> createState() => _FocusTimerScreenState();
}

class _FocusTimerScreenState extends State<FocusTimerScreen> {
  final AppDetectionService _appDetectionService = AppDetectionService();
  final GamificationService _gamification = GamificationService();
  final FocusSessionService _focusSessionService = FocusSessionService();
  Timer? _timer;
  int _distractionCount = 0;
  bool _pointsAwarded = false;
  bool _sessionCompleted = false;
  bool _sessionSaved = false;
  bool _isEnding = false;

  // Map for user-friendly app names
  final Map<String, String> _appDisplayNames = {
    'com.facebook.katana': 'Facebook',
    'com.instagram.android': 'Instagram',
    'com.zhiliaoapp.musically': 'TikTok',
    'com.twitter.android': 'Twitter',
    'com.google.android.youtube': 'YouTube',
    'com.snapchat.android': 'Snapchat',
    'com.reddit.frontpage': 'Reddit',
  };

  StreamSubscription<String>? _appDetectionSub;
  StreamSubscription<void>? _overlayClosedSub;

  @override
  void initState() {
    super.initState();
    _startSession();
    // Listen for overlay close event
    _overlayClosedSub = _appDetectionService.overlayClosedStream.listen((_) {
      _endSession();
    });
  }

  Future<void> _startSession() async {
    // Initialize app detection
    await _appDetectionService.initialize();
    // Initialize notifications
    await NotificationService().initialize();
    // Show session start notification
    await NotificationService().showSessionStartNotification(
      widget.session.duration,
      context,
    );
    // Set blocked apps and start monitoring
    _appDetectionService.setBlockedApps(widget.session.blockedApps);
    await _appDetectionService.startMonitoring();
    // Listen for app detection
    _appDetectionSub = _appDetectionService.appDetectionStream.listen((appPackage) {
      _onBlockedAppDetected(appPackage);
    });
    // Start timer
    _startTimer();
  }

  void _onBlockedAppDetected(String appPackage) {
    setState(() {
      _distractionCount++;
    });
    // Use friendly name if available
    final appName = _appDisplayNames[appPackage] ?? appPackage;
    NotificationService().showDistractionNotification(appName, context);
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (widget.session.isExpired) {
        if (!_sessionCompleted) {
          _sessionCompleted = true;
          NotificationService().showSessionCompleteNotification(context);
        }
        _endSession();
      } else {
        setState(() {
          // Update UI
        });
      }
    });
  }

  Future<void> _saveCompletedSessionIfNeeded() async {
    if (!_sessionCompleted || _sessionSaved) return;
    try {
      await _focusSessionService.saveCompletedSession(
        session: widget.session,
        distractionCount: _distractionCount,
      );
      _sessionSaved = true;
    } catch (e) {
      debugPrint('Error saving focus session: $e');
    }
  }

  void _endSession() async {
    if (_isEnding) return;
    _isEnding = true;
    await _appDetectionService.stopMonitoring();
    _timer?.cancel();
    await _saveCompletedSessionIfNeeded();

    final userId = _gamification.currentUserId;
    if (userId != null) {
      final currentPoints = await _gamification.getVariable(userId, 'totalPoints');
      final currentDailyPoints = await _gamification.getVariable(userId, 'dailyPoints');

      if (!_pointsAwarded && _distractionCount == 0) {
        await _gamification.saveVariable(userId, 'totalPoints', currentPoints + 10);
        await _gamification.saveVariable(userId, 'dailyPoints', currentDailyPoints + 10); // Also update daily points
        _pointsAwarded = true;
      } else {
        // Deduct 2 points for each distraction
        final deductedPoints = currentPoints - (_distractionCount * 2);
        final deductedDailyPoints = currentDailyPoints - (_distractionCount * 2);
        await _gamification.saveVariable(
          userId,
          'totalPoints',
          deductedPoints < 0 ? 0 : deductedPoints,
        );
        await _gamification.saveVariable(
          userId,
          'dailyPoints',
          deductedDailyPoints < 0 ? 0 : deductedDailyPoints, // Daily points can't go below 0
        );
      }
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _appDetectionSub?.cancel();
    _overlayClosedSub?.cancel();
    _appDetectionService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remainingTime = widget.session.remainingTime;
    final totalSeconds = widget.session.duration.inSeconds;
    final elapsedSeconds = totalSeconds - remainingTime.inSeconds;
    final progress = elapsedSeconds / totalSeconds;

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Focus Session',
        actions: [
          IconButton(
            icon: const Icon(Icons.stop),
            tooltip: 'Stop Session',
            onPressed: _endSession,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 200,
                    height: 200,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 8,
                      backgroundColor: Colors.grey.shade300,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.green,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    '${remainingTime.inMinutes}:${(remainingTime.inSeconds % 60).toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'remaining',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 40), // More space below timer
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Session Info Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            'Monitoring: ${widget.session.blockedApps.map((pkg) => _appDisplayNames[pkg] ?? pkg).join(', ')}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Distractions:'),
                        Text(
                          '$_distractionCount times',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Stop Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _endSession,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text(
                  'Stop Session',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
