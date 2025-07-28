class FocusSession {
  final List<String> blockedApps;
  final Duration duration;
  final bool isActive;
  final DateTime? startTime;

  FocusSession({
    required this.blockedApps,
    required this.duration,
    this.isActive = false,
    this.startTime,
  });

  // Create a new focus session
  factory FocusSession.create({
    required List<String> blockedApps,
    required Duration duration,
  }) {
    return FocusSession(
      blockedApps: blockedApps,
      duration: duration,
      isActive: true,
      startTime: DateTime.now(),
    );
  }

  // Get remaining time
  Duration get remainingTime {
    if (startTime == null || !isActive) return Duration.zero;
    
    final elapsed = DateTime.now().difference(startTime!);
    if (elapsed >= duration) return Duration.zero;
    
    return duration - elapsed;
  }

  // Check if session is expired
  bool get isExpired {
    if (startTime == null) return false;
    return DateTime.now().difference(startTime!) >= duration;
  }

  // Stop the session
  FocusSession stop() {
    return copyWith(isActive: false);
  }

  // Copy with new values
  FocusSession copyWith({
    List<String>? blockedApps,
    Duration? duration,
    bool? isActive,
    DateTime? startTime,
  }) {
    return FocusSession(
      blockedApps: blockedApps ?? this.blockedApps,
      duration: duration ?? this.duration,
      isActive: isActive ?? this.isActive,
      startTime: startTime ?? this.startTime,
    );
  }
}
