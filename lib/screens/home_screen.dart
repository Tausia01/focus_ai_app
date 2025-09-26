import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../auth_service.dart';
import '../services/task_service.dart';
import '../services/cache_service.dart';
import '../models/task.dart';
import '../widgets/custom_app_bar.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static final List<String> _motivatingMessages = [
    'You are capable of amazing things!',
    'Stay focused and never give up!',
    'Every small step counts!',
    'Success is the sum of small efforts, repeated.',
    'You are closer to your goals than you think!',
    'Keep pushing, you are doing great!',
    'Discipline is the bridge between goals and accomplishment.',
    'Your future self will thank you for today!'
  ];

  String getRandomMessage() {
    final random = Random();
    return _motivatingMessages[random.nextInt(_motivatingMessages.length)];
  }

  // Get productivity report data from cache instantly
  Map<String, int> _getProductivityReportFromCache() {
    final tasks = CacheService().getTasksFromCache();
    final completedCount = tasks.where((t) => t.completed).length;
    final totalCount = tasks.length;
    
    return {
      'completed': completedCount,
      'total': totalCount,
    };
  }

  // Build productivity report with instant loading from cache
  Widget _buildProductivityReport() {
    // Get initial data from cache instantly
    final initialData = _getProductivityReportFromCache();
    
    return StreamBuilder<List<Task>>(
      // Use cached data as initial data for instant rendering
      initialData: CacheService().getTasksFromCache(),
      stream: CacheService().getTasksStream(),
      builder: (context, snapshot) {
        // Show cached data immediately, even if stream hasn't emitted yet
        final tasks = snapshot.data ?? CacheService().getTasksFromCache();
        final completedCount = tasks.where((t) => t.completed).length;
        final totalCount = tasks.length;
        
        return Column(
          children: [
            Text(
              'Productivity Report',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 180,
              width: 180,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 4,
                  centerSpaceRadius: 48,
                  startDegreeOffset: -90,
                  sections: [
                    PieChartSectionData(
                      color: Colors.deepPurple,
                      value: completedCount.toDouble(),
                      title: '',
                      radius: 40,
                    ),
                    PieChartSectionData(
                      color: Colors.deepPurple[100],
                      value: (totalCount - completedCount).toDouble(),
                      title: '',
                      radius: 40,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              totalCount == 0
                  ? 'No tasks yet. Start your productivity journey!'
                  : 'You have completed $completedCount out of $totalCount task${totalCount == 1 ? '' : 's'}!',
              style: const TextStyle(fontSize: 18),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final taskService = TaskService();
    final message = getRandomMessage();
    
    // Run migration in background without blocking UI
    taskService.migrateTasksAddCompleted();
    
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Focus AI',
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await AuthService().signOut();
              // Navigation is now handled automatically by AuthWrapper
              // No need to manually navigate here
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 32),
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.deepPurple[50],
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.deepPurple.withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Georgia',
                  color: Colors.deepPurple,
                  letterSpacing: 1.1,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            _buildProductivityReport(),
          ],
        ),
      ),
    );
  }
} 