class FocusSessionSummary {
  final int totalSessions;
  final int totalDistractions;

  const FocusSessionSummary({
    required this.totalSessions,
    required this.totalDistractions,
  });

  const FocusSessionSummary.empty()
      : totalSessions = 0,
        totalDistractions = 0;

  double get averageDistractionsPerSession {
    if (totalSessions == 0) return 0;
    return totalDistractions / totalSessions;
  }
}


