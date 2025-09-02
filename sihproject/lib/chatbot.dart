import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatbotPage extends StatefulWidget {
  const ChatbotPage({super.key});

  @override
  State<ChatbotPage> createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage> {
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, String>> _messages = [];
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  final String _apiKey = 'AIzaSyD-gQAh3KURONK37LZN6bO_Qi816f6Eudc';

  late GenerativeModel _model;

  @override
  void initState() {
    super.initState();
    _model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: _apiKey);
    _addBotMessage(
      'Hello! I\'m here to help you with mental health support. How are you feeling today?',
    );
  }

  void _addBotMessage(String message) {
    setState(() {
      _messages.add({'sender': 'bot', 'message': message});
    });
    _scrollToBottom();
  }

  void _addUserMessage(String message) {
    setState(() {
      _messages.add({'sender': 'user', 'message': message});
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    _addUserMessage(message);
    _messageController.clear();

    setState(() {
      _isLoading = true;
    });

    try {
      // Check for crisis keywords
      if (_containsCrisisKeywords(message)) {
        _showCrisisAlert();
        return;
      }

      // Generate response using Vertex AI
      final prompt =
          '''
You are a friendly mental health counselor chatbot for students, like a supportive friend. Analyze the user's message and respond in 4-5 lines with personalized counseling advice. Use a warm, conversational tone, include relevant emojis, and offer practical solutions or encouragement. Keep it empathetic, supportive, and varied—avoid paragraphs or lists. If the user shows signs of crisis, direct them to professional help immediately.
User message: $message

Provide a friendly counseling response in 4-5 lines:
''';

      final response = await _model.generateContent([Content.text(prompt)]);
      final botResponse =
          response.text ?? 'I\'m here to listen. Can you tell me more?';

      _addBotMessage(botResponse);

      // Store conversation in Firestore
      await _storeConversation(message, botResponse);
    } catch (e) {
      print('Chatbot Error: $e'); // For debugging
      String errorMessage = 'Sorry, I\'m having trouble connecting. Please try again later.';
      if (e.toString().contains('API_KEY')) {
        errorMessage = 'API key issue. Please check your configuration.';
      } else if (e.toString().contains('quota')) {
        errorMessage = 'API quota exceeded. Please try again later.';
      } else if (e.toString().contains('network')) {
        errorMessage = 'Network connection issue. Please check your internet.';
      }
      _addBotMessage(errorMessage);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  bool _containsCrisisKeywords(String message) {
    final crisisWords = [
      'suicide',
      'kill myself',
      'end it all',
      'not worth living',
      'harm myself',
      'die',
      'death',
      'overdose',
      'cut myself',
    ];
    return crisisWords.any((word) => message.toLowerCase().contains(word));
  }

  void _showCrisisAlert() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Crisis Detected'),
        content: const Text(
          'I\'m concerned about what you\'ve shared. Please contact emergency services immediately:\n\n'
          'National Suicide Prevention Lifeline: 988\n'
          'Or text HOME to 741741 for Crisis Text Line\n\n'
          'You are not alone, and help is available 24/7.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _storeConversation(
    String userMessage,
    String botResponse,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('conversations').add({
        'userId': user.uid,
        'userMessage': userMessage,
        'botResponse': botResponse,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Chatbot Support')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isUser = message['sender'] == 'user';
                return Align(
                  alignment: isUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.blue : Colors.grey[300],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      message['message']!,
                      style: TextStyle(
                        color: isUser ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type your message...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
