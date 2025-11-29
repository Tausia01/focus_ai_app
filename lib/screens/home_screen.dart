import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../auth_service.dart';
import '../services/task_service.dart';
import '../services/cache_service.dart';
import '../models/task.dart';
import '../widgets/custom_app_bar.dart';
import '../services/focus_session_service.dart';
import '../models/focus_session_summary.dart';

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

  // ---------------------------
  // NEW COMBINED PRODUCTIVITY CARD
  // ---------------------------
  Widget _buildCombinedProductivityCard() {
    final focusSessionService = FocusSessionService();

    return StreamBuilder<List<Task>>(
      initialData: CacheService().getTasksFromCache(),
      stream: CacheService().getTasksStream(),
      builder: (context, snapshot) {
        final tasks = snapshot.data ?? CacheService().getTasksFromCache();
        final completedCount = tasks.where((t) => t.completed).length;
        final totalCount = tasks.length;

        return StreamBuilder<FocusSessionSummary>(
          stream: focusSessionService.focusSessionSummaryStream(),
          initialData: const FocusSessionSummary.empty(),
          builder: (context, fsSnapshot) {
            final summary = fsSnapshot.data ?? const FocusSessionSummary.empty();
            final avgDistract = summary.averageDistractionsPerSession;

            return Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 3,
              margin: const EdgeInsets.only(top: 10),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text("Productivity Report",
                        style: Theme.of(context).textTheme.titleLarge),

                    const SizedBox(height: 16),

                    /// COMPACT PIE CHART
                    SizedBox(
                      height: 140,
                      width: 140,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 0,
                          centerSpaceRadius: 38,
                          startDegreeOffset: -90,
                          sections: [
                            PieChartSectionData(
                              color: Colors.purple.shade300,
                              value: completedCount.toDouble(),
                              title: '',
                              radius: 32,
                            ),
                            PieChartSectionData(
                              color: Colors.purple.shade100,
                              value: (totalCount - completedCount).toDouble(),
                              title: '',
                              radius: 32,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      totalCount == 0
                          ? 'No tasks yet.'
                          : '$completedCount of $totalCount tasks completed',
                      style: const TextStyle(fontSize: 15),
                    ),

                    const SizedBox(height: 20),

                    Divider(color: Colors.grey.shade300, thickness: 1),
                    const SizedBox(height: 12),

                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Focus Session Summary",
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),

                    const SizedBox(height: 10),

                    if (summary.totalSessions == 0)
                      const Text(
                        'No focus sessions logged yet.',
                        style: TextStyle(fontSize: 15, color: Colors.grey),
                      )
                    else
                      Column(
                        children: [
                          _buildMiniRow("Total Sessions", summary.totalSessions.toString()),
                          _buildMiniRow("Completed", summary.completedSessions.toString()),
                          _buildMiniRow("Failed", summary.failedSessions.toString()),
                          _buildMiniRow("Completion Rate",
                              "${(summary.completionRate * 100).toStringAsFixed(0)}%"),
                          _buildMiniRow("Total Distractions", summary.totalDistractions.toString()),
                          _buildMiniRow("Avg Distractions",
                              avgDistract.toStringAsFixed(1)),
                        ],
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ---------------------------
  // UI HELPER FOR METRIC ROWS
  // ---------------------------
  Widget _buildMiniRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 15, color: Colors.grey)),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.deepPurple,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final taskService = TaskService();
    final message = getRandomMessage();

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
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 32),
                padding:
                    const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
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

              // NEW COMPACT PRODUCTIVITY CARD
              _buildCombinedProductivityCard(),
            ],
          ),
        ),
      ),
    );
  }
}
