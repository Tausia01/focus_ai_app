import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/gamification_service.dart';
import '../services/cache_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with WidgetsBindingObserver {
  int _dailyPoints = 0;
  int _streakCount = 0;
  int _streakFreezeCount = 0;
  int _totalPoints = 0;

  final int _dailyThreshold = 15;
  final int _streakFreezeCost = 100;

  final _gamification = GamificationService();
  final _cacheService = CacheService();
  final _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadDataFromCache();
    _loadData(); // Load fresh data in background
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadData();
    }
  }

  // Load data from cache instantly (no await)
  void _loadDataFromCache() {
    final gamificationData = _cacheService.getGamificationFromCache();
    
    _totalPoints = gamificationData['totalPoints'] is int ? gamificationData['totalPoints'] as int : 0;
    _dailyPoints = gamificationData['dailyPoints'] is int ? gamificationData['dailyPoints'] as int : 0;
    _streakCount = gamificationData['streakCount'] is int ? gamificationData['streakCount'] as int : 0;
    _streakFreezeCount = gamificationData['streakFreezeCount'] is int ? gamificationData['streakFreezeCount'] as int : 0;
    
    if (mounted) setState(() {});
  }

  // Load fresh data from Firestore in background
  Future<void> _loadData() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final today = DateTime.now();
    final lastActiveDate = await _gamification.getDateTime(userId, 'lastActiveDate') ?? today.subtract(const Duration(days: 1));

    _totalPoints = await _gamification.getVariable(userId, 'totalPoints');
    _dailyPoints = await _gamification.getVariable(userId, 'dailyPoints');
    _streakCount = await _gamification.getVariable(userId, 'streakCount');
    _streakFreezeCount = await _gamification.getVariable(userId, 'streakFreezeCount');

    if (!_isSameDay(today, lastActiveDate)) {
      await _checkAndUpdateStreak();
      _dailyPoints = 0;
      await _gamification.saveDateTime(userId, 'lastActiveDate', today);
    }

    await _gamification.saveVariable(userId, 'dailyPoints', _dailyPoints);

    if (mounted) setState(() {});
  }

  Future<void> _checkAndUpdateStreak() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final previousDailyPoints = await _gamification.getVariable(userId, 'dailyPoints');

    if (previousDailyPoints >= _dailyThreshold) {
      setState(() {
        _streakCount++;
      });
      await _gamification.saveVariable(userId, 'streakCount', _streakCount);
    } else {
      if (_streakFreezeCount > 0) {
        setState(() {
          _streakFreezeCount--;
        });
        await _gamification.saveVariable(userId, 'streakFreezeCount', _streakFreezeCount);
      } else {
        setState(() {
          _streakCount = 0;
        });
        await _gamification.saveVariable(userId, 'streakCount', _streakCount);
      }
    }
  }

  Future<void> _checkCurrentStreakStatus() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final currentDailyPoints = await _gamification.getVariable(userId, 'dailyPoints');

    String message;
    if (currentDailyPoints >= _dailyThreshold) {
      message = 'Great! You\'ve met today\'s goal of $_dailyThreshold points. Your streak will increase tomorrow!';
    } else {
      final remainingPoints = _dailyThreshold - currentDailyPoints;
      if (_streakFreezeCount > 0) {
        message = 'You need $remainingPoints more points today to maintain your streak, or use a streak freeze.';
      } else {
        message = 'You need $remainingPoints more points today to maintain your streak!';
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  static Future<void> checkDailyPointsThreshold() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    final gamification = GamificationService();
    final dailyPoints = await gamification.getVariable(userId, 'dailyPoints');
    final dailyThreshold = 15;
    if (dailyPoints >= dailyThreshold) {
      // Hook for future notifications
    }
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  Future<void> _buyStreakFreeze() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    if (_totalPoints >= _streakFreezeCost) {
      // Optimistic UI update - happens instantly
      setState(() {
        _totalPoints -= _streakFreezeCost;
        _streakFreezeCount++;
      });
      
      // Save to cache/Firestore in background
      await _gamification.saveVariable(userId, 'totalPoints', _totalPoints);
      await _gamification.saveVariable(userId, 'streakFreezeCount', _streakFreezeCount);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not enough points to buy a streak freeze!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Container(
            height: MediaQuery.of(context).size.height - AppBar().preferredSize.height - MediaQuery.of(context).padding.top,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Total Points: $_totalPoints', style: const TextStyle(fontSize: 20)),
                  Text('Daily Points: $_dailyPoints', style: const TextStyle(fontSize: 20)),
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      children: [
                        Text(
                          'Daily Goal: $_dailyThreshold points',
                          style: const TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: _dailyPoints / _dailyThreshold,
                          backgroundColor: Colors.grey.shade300,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _dailyPoints >= _dailyThreshold ? Colors.green : Colors.blue,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_dailyPoints >= _dailyThreshold ? "Goal Met! 🎉" : "${_dailyThreshold - _dailyPoints} more points needed"}',
                          style: TextStyle(
                            fontSize: 14,
                            color: _dailyPoints >= _dailyThreshold ? Colors.green : Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text('Streak Count: $_streakCount', style: const TextStyle(fontSize: 20)),
                  Text('Streak Freezes: $_streakFreezeCount', style: const TextStyle(fontSize: 20)),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _buyStreakFreeze,
                    child: Text('Buy Streak Freeze (Cost: $_streakFreezeCost points)'),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _checkCurrentStreakStatus,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                    ),
                    child: const Text('Check Streak Status'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
