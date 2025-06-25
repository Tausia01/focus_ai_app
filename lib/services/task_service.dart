import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/task.dart';

class TaskService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get user's tasks stream
  Stream<List<Task>> getTasks() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('tasks')
        .orderBy('priority', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return Task.fromMap(data, doc.id);
      }).toList();
    });
  }

  // Add a new task
  Future<void> addTask(Task task) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('tasks')
        .add(task.toMap());
  }

  // Delete a task
  Future<void> deleteTask(String taskId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('tasks')
        .doc(taskId)
        .delete();
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

  Future<void> updateTaskCompleted(String taskId, bool completed) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('tasks')
        .doc(taskId)
        .update({'completed': completed});
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