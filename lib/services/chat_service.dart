import '../models/task.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_message.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Simulate an API call to a chatbot
  Future<String> getResponse(String message, List<Task> tasks) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));

    // Simple logic to generate a motivational response
    if (tasks.isEmpty) {
      return "You don't have any tasks yet. Let's add some to get you started!";
    }

    if (message.toLowerCase().contains('hello') || message.toLowerCase().contains('hi')) {
        return 'Hello! You have ${tasks.length} tasks to do. You can do it!';
    }

    final highPriorityTasks = tasks.where((t) => t.priority == TaskPriority.high).toList();
    if (highPriorityTasks.isNotEmpty) {
      return 'You have ${highPriorityTasks.length} high priority tasks. Let\'s focus on "${highPriorityTasks.first.name}" first. You can do it!';
    }

    final approachingDeadlines = tasks.where((t) => t.deadline.isBefore(DateTime.now().add(const Duration(days: 3)))).toList();
    if (approachingDeadlines.isNotEmpty) {
      return 'Remember, the deadline for "${approachingDeadlines.first.name}" is approaching. A little progress each day adds up to big results!';
    }

    return 'You are doing great! Keep up the good work on your tasks. What will you tackle next?';
  }

  Stream<List<ChatMessage>> getChatMessages() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);
    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('chats')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatMessage.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<void> addChatMessage(ChatMessage message) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('chats')
        .add(message.toMap());
  }

  Future<void> clearChat() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final batch = _firestore.batch();
    final chatCollection = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('chats');
    final snapshots = await chatCollection.get();
    for (var doc in snapshots.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
} 