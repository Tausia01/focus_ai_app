import 'package:flutter/material.dart';
import '../services/task_service.dart';
import '../services/chat_service.dart';
import '../auth_service.dart';
import '../models/chat_message.dart';
import '../widgets/custom_app_bar.dart';

class FocusAssistantScreen extends StatefulWidget {
  const FocusAssistantScreen({super.key});

  @override
  State<FocusAssistantScreen> createState() => _FocusAssistantScreenState();
}

class _FocusAssistantScreenState extends State<FocusAssistantScreen> {
  final _messageController = TextEditingController();
  final _chatService = ChatService();
  final _taskService = TaskService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // No need to add a greeting here; it will be loaded from Firestore if present
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) {
      return;
    }

    setState(() {
      _isLoading = true;
    });
    _messageController.clear();

    // Save user message
    await _chatService.addChatMessage(ChatMessage(
      id: '',
      text: messageText,
      isUser: true,
      timestamp: DateTime.now(),
    ));

    try {
      final tasks = await _taskService.getTasks().first;
      final response = await _chatService.getResponse(messageText, tasks);
      // Save bot response
      await _chatService.addChatMessage(ChatMessage(
        id: '',
        text: response,
        isUser: false,
        timestamp: DateTime.now(),
      ));
    } catch (e) {
      await _chatService.addChatMessage(ChatMessage(
        id: '',
        text: 'Sorry, I am having trouble connecting. Please try again later.',
        isUser: false,
        timestamp: DateTime.now(),
      ));
    }
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
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
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _chatService.getChatMessages(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = snapshot.data ?? [];
                if (messages.isEmpty) {
                  return const Center(child: Text('No conversation yet. Say hello!'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    return ChatBubble(message: message);
                  },
                );
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
          _buildMessageComposer(),
        ],
      ),
    );
  }

  Widget _buildMessageComposer() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                hintText: 'Send a message...',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }
}

class ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              decoration: BoxDecoration(
                color: message.isUser ? Colors.deepPurple[100] : Colors.grey[200],
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: Text(
                message.text,
                softWrap: true,
                overflow: TextOverflow.visible,
              ),
            ),
          ),
        ],
      ),
    );
  }
} 