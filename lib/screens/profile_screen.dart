import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/gamification_service.dart';
import '../services/cache_service.dart';
import '../widgets/custom_app_bar.dart';

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
    _loadData(); 
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

  void _loadDataFromCache() {
    final gamificationData = _cacheService.getGamificationFromCache();
    
    _totalPoints = gamificationData['totalPoints'] is int ? gamificationData['totalPoints'] as int : 0;
    _dailyPoints = gamificationData['dailyPoints'] is int ? gamificationData['dailyPoints'] as int : 0;
    _streakCount = gamificationData['streakCount'] is int ? gamificationData['streakCount'] as int : 0;
    _streakFreezeCount = gamificationData['streakFreezeCount'] is int ? gamificationData['streakFreezeCount'] as int : 0;

    if (mounted) setState(() {});
  }

  Future<void> _loadData() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final today = DateTime.now();
    final lastActiveDate =
        await _gamification.getDateTime(userId, 'lastActiveDate') ??
            today.subtract(const Duration(days: 1));

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

    final previousDailyPoints =
        await _gamification.getVariable(userId, 'dailyPoints');

    if (previousDailyPoints >= _dailyThreshold) {
      setState(() => _streakCount++);
      await _gamification.saveVariable(userId, 'streakCount', _streakCount);
    } else {
      if (_streakFreezeCount > 0) {
        setState(() => _streakFreezeCount--);
        await _gamification.saveVariable(userId, 'streakFreezeCount', _streakFreezeCount);
      } else {
        setState(() => _streakCount = 0);
        await _gamification.saveVariable(userId, 'streakCount', _streakCount);
      }
    }
  }

  Future<void> _checkCurrentStreakStatus() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final currentDailyPoints =
        await _gamification.getVariable(userId, 'dailyPoints');

    String message;
    if (currentDailyPoints >= _dailyThreshold) {
      message =
          'Great! You\'ve met today\'s goal of $_dailyThreshold points. Your streak will increase tomorrow!';
    } else {
      final remainingPoints = _dailyThreshold - currentDailyPoints;
      if (_streakFreezeCount > 0) {
        message =
            'You need $remainingPoints more points today to maintain your streak, or use a streak freeze.';
      } else {
        message =
            'You need $remainingPoints more points today to maintain your streak!';
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  bool _isSameDay(DateTime d1, DateTime d2) =>
      d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;

  Future<void> _buyStreakFreeze() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    if (_totalPoints >= _streakFreezeCost) {
      setState(() {
        _totalPoints -= _streakFreezeCost;
        _streakFreezeCount++;
      });

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
      appBar: CustomAppBar(title: 'Focus AI'),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [

              _buildStatCard(
                label: "Total Points",
                value: _totalPoints.toString(),
                icon: Icons.star_rounded,
                color: Colors.blueGrey.shade50,
              ),

              const SizedBox(height: 16),

              _buildDailyProgressCard(),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      label: "Streak Count",
                      value: _streakCount.toString(),
                      icon: Icons.local_fire_department_rounded,
                      color: Colors.orange.shade50,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      label: "Streak Freezes",
                      value: _streakFreezeCount.toString(),
                      icon: Icons.ac_unit_rounded,
                      color: Colors.blue.shade50,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              _buildPrimaryButton(
                text: "Buy Streak Freeze (Cost: $_streakFreezeCost)",
                onPressed: _buyStreakFreeze,
                color: Colors.blueGrey.shade700,
              ),

              const SizedBox(height: 12),

              _buildPrimaryButton(
                text: "Check Streak Status",
                onPressed: _checkCurrentStreakStatus,
                color: Colors.indigo,
              ),

              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }

  // --------------------------
  // UI COMPONENTS BELOW
  // --------------------------

  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
    Color? color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color ?? Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      child: Row(
        children: [
          Icon(icon, size: 32, color: Colors.black87),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  )),
              const SizedBox(height: 4),
              Text(value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDailyProgressCard() {
    final progress = (_dailyPoints / _dailyThreshold).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Daily Progress",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            "$_dailyPoints / $_dailyThreshold points",
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 14),

          Center(
            child: SizedBox(
              width: 230,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 12,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progress >= 1 ? Colors.green : Colors.blueGrey,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          Center(
            child: Text(
              progress >= 1
                  ? "Goal Met! 🎉"
                  : "${_dailyThreshold - _dailyPoints} more to go",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color:
                    progress >= 1 ? Colors.green : Colors.orange,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String text,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 15, color: Colors.white),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
