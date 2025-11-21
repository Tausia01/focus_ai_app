class FocusSessionSummary {
  final int totalSessions;
  final int completedSessions;
  final int failedSessions;
  final int totalDistractions;

  const FocusSessionSummary({
    required this.totalSessions,
    required this.completedSessions,
    required this.failedSessions,
    required this.totalDistractions,
  });

  const FocusSessionSummary.empty()
      : totalSessions = 0,
        completedSessions = 0,
        failedSessions = 0,
        totalDistractions = 0;

  double get averageDistractionsPerSession {
    if (totalSessions == 0) return 0;
    return totalDistractions / totalSessions;
  }

  double get completionRate {
    if (totalSessions == 0) return 0;
    return completedSessions / totalSessions;
  }
}


