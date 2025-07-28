import 'package:cloud_firestore/cloud_firestore.dart';

class Task {
  final String id;
  final String name;
  final TaskPriority priority;
  final DateTime deadline;
  final bool completed;

  Task({
    required this.id,
    required this.name,
    required this.priority,
    required this.deadline,
    required this.completed,
  });

  factory Task.fromMap(Map<String, dynamic> map, String id) {
    return Task(
      id: id,
      name: map['name'] as String,
      priority: TaskPriority.values[map['priority'] as int],
      deadline: (map['deadline'] as Timestamp).toDate(),
      completed: map['completed'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'priority': priority.index,
      'deadline': Timestamp.fromDate(deadline),
      'completed': completed,
    };
  }
}

enum TaskPriority {
  high,
  medium,
  low;

  String get displayName => name[0].toUpperCase() + name.substring(1);
} 