import '../models/task.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_message.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/groq.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Call Groq LLM chat completions API to get a response
  Future<String> getResponse(String message, List<Task> tasks) async {
    try {
      // Build task summary for system prompt
      final taskSummary = _buildTaskSummary(tasks);

      final systemPrompt = '''
You are a warm relational agent that helps the user focus on their most meaningful work.

Here is a summary of the user's current tasks:
$taskSummary

Be supportive, encouraging, and concise. Give concrete, actionable suggestions that fit into short focus sessions. Keep responses focused on helping the user take the next small step.
Do not repeat the full task list unless asked; reference only the most important task.
''';

      final uri = Uri.parse('https://api.groq.com/openai/v1/chat/completions');

      final body = jsonEncode({
        'model': 'llama-3.1-8b-instant',
        'messages': [
          {
            'role': 'system',
            'content': systemPrompt,
          },
          {
            'role': 'user',
            'content': message,
          },
        ],
      });

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${GroqConfig.apiKey}',
        },
        body: body,
      );

      if (response.statusCode != 200) {
        return 'I had trouble reaching the focus assistant right now. Let\'s take a breath and pick one small task you can work on next.';
      }

      final data = jsonDecode(utf8.decode(response.bodyBytes));

      final choices = data['choices'];
      if (choices is List && choices.isNotEmpty) {
        final first = choices[0];
        final messageMap = first['message'];
        final content = messageMap?['content'];
        if (content != null && content is String && content.isNotEmpty) {
          return content;
        }
      }

      return 'I\'m here with you, but something went wrong reading the assistant\'s reply. Let\'s choose one priority task and commit to a short focus session.';
    } catch (e) {
      return 'I couldn\'t connect to the focus assistant just now. Let\'s still choose one small step you can take on an important task.';
    }
  }

  String _buildTaskSummary(List<Task> tasks) {
    if (tasks.isEmpty) {
      return 'The user has no tasks yet. Gently encourage them to create 1–3 specific tasks they care about.';
    }

    final buffer = StringBuffer();
    buffer.writeln('Total tasks: ${tasks.length}.');

    // Sort by priority (high -> low), then nearest deadline
    final sorted = [...tasks]
      ..sort((a, b) {
        // Higher priority should come first
        final priorityCompare = b.priority.index.compareTo(a.priority.index);
        if (priorityCompare != 0) return priorityCompare;
        return a.deadline.compareTo(b.deadline);
      });

    // Take up to top 5 tasks for context
    final topTasks = sorted.take(5);
    for (final t in topTasks) {
      buffer.writeln(
          '- Task: ${t.name} | Priority: ${t.priority.displayName} | Deadline: ${t.deadline.toIso8601String()}');
    }

    buffer.writeln(
        'Use this task list only as lightweight context. Do not repeat all details back verbatim; instead, reference the most important task and guide the user toward one clear next action.');

    return buffer.toString();
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
