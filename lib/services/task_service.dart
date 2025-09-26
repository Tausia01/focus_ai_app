import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/task.dart';
import 'cache_service.dart';

class TaskService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CacheService _cacheService = CacheService();

  // Get user's tasks stream (now from cache for instant updates)
  Stream<List<Task>> getTasks() {
    return _cacheService.getTasksStream();
  }

  // Add a new task (optimistic update)
  Future<void> addTask(Task task) async {
    await _cacheService.addTaskOptimistic(task);
  }

  // Delete a task (optimistic update)
  Future<void> deleteTask(String taskId) async {
    await _cacheService.deleteTaskOptimistic(taskId);
  }

  // Update task sorting
  Future<void> updateTasksOrder(List<Task> tasks) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final batch = _firestore.batch();
    for (var task in tasks) {
      final taskRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('tasks')
          .doc(task.id);
      batch.update(taskRef, {
        'priority': task.priority.index,
        'deadline': Timestamp.fromDate(task.deadline),
      });
    }
    await batch.commit();
  }

  // Update task completed status (optimistic update)
  Future<void> updateTaskCompleted(String taskId, bool completed) async {
    await _cacheService.updateTaskCompletedOptimistic(taskId, completed);
  }

  Future<void> migrateTasksAddCompleted() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final tasksRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('tasks');
    final snapshot = await tasksRef.get();
    final batch = _firestore.batch();
    for (var doc in snapshot.docs) {
      if (!(doc.data().containsKey('completed'))) {
        batch.update(doc.reference, {'completed': false});
      }
    }
    await batch.commit();
  }
} 