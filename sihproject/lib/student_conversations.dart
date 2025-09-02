import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StudentConversationsPage extends StatefulWidget {
  final String studentId;
  final String studentName;
  final String studentEmail;

  const StudentConversationsPage({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
  });

  @override
  State<StudentConversationsPage> createState() => _StudentConversationsPageState();
}

class _StudentConversationsPageState extends State<StudentConversationsPage>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _conversations = [];

  late AnimationController _fadeController;
  late AnimationController _slideController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Initialize animations
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    // Start entrance animations
    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      _slideController.forward();
    });

    // Load conversations
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    try {
      final conversationsQuery = await FirebaseFirestore.instance
          .collection('conversations')
          .where('userId', isEqualTo: widget.studentId)
          .orderBy('timestamp', descending: true)
          .get();

      List<Map<String, dynamic>> conversations = [];
      for (var doc in conversationsQuery.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        conversations.add(data);
      }

      setState(() {
        _conversations = conversations;
        _isLoading = false;
      });

    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load conversations: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown time';
    final dateTime = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return 'Today ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return '${weekdays[dateTime.weekday - 1]} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Conversations'),
        backgroundColor: Colors.blue,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _isLoading = true;
                _errorMessage = null;
              });
              _loadConversations();
            },
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value,
            child: SlideTransition(
              position: _slideAnimation,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.blue, Colors.blueAccent],
                  ),
                ),
                child: SafeArea(
                  child: _isLoading
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Loading conversations...',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      : _errorMessage != null
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.error_outline,
                                      color: Colors.white,
                                      size: 64,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _errorMessage!,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 24),
                                    ElevatedButton(
                                      onPressed: () {
                                        setState(() {
                                          _isLoading = true;
                                          _errorMessage = null;
                                        });
                                        _loadConversations();
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: Colors.blue,
                                      ),
                                      child: const Text('Retry'),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : _conversations.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24.0),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.chat_bubble_outline,
                                          color: Colors.white,
                                          size: 64,
                                        ),
                                        const SizedBox(height: 16),
                                        const Text(
                                          'No conversations yet',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 20,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          '${widget.studentName} hasn\'t chatted with the AI assistant yet.',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.7),
                                            fontSize: 16,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Student Info Header
                                      TweenAnimationBuilder(
                                        tween: Tween<double>(begin: 0, end: 1),
                                        duration: const Duration(milliseconds: 800),
                                        curve: Curves.easeOutCubic,
                                        builder: (context, double value, child) {
                                          return Transform.translate(
                                            offset: Offset(0, 30 * (1 - value)),
                                            child: Opacity(
                                              opacity: value,
                                              child: Card(
                                                elevation: 4,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(16),
                                                ),
                                                child: Padding(
                                                  padding: const EdgeInsets.all(16),
                                                  child: Row(
                                                    children: [
                                                      Container(
                                                        width: 50,
                                                        height: 50,
                                                        decoration: BoxDecoration(
                                                          gradient: LinearGradient(
                                                            colors: [Colors.blue.shade400, Colors.blue.shade600],
                                                            begin: Alignment.topLeft,
                                                            end: Alignment.bottomRight,
                                                          ),
                                                          borderRadius: BorderRadius.circular(25),
                                                        ),
                                                        child: Center(
                                                          child: Text(
                                                            widget.studentName.substring(0, 1).toUpperCase(),
                                                            style: const TextStyle(
                                                              color: Colors.white,
                                                              fontSize: 20,
                                                              fontWeight: FontWeight.bold,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 16),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Text(
                                                              widget.studentName,
                                                              style: const TextStyle(
                                                                fontSize: 18,
                                                                fontWeight: FontWeight.w600,
                                                                color: Colors.black87,
                                                              ),
                                                            ),
                                                            const SizedBox(height: 4),
                                                            Text(
                                                              widget.studentEmail,
                                                              style: TextStyle(
                                                                fontSize: 14,
                                                                color: Colors.grey[600],
                                                              ),
                                                            ),
                                                            const SizedBox(height: 4),
                                                            Text(
                                                              '${_conversations.length} conversation${_conversations.length == 1 ? '' : 's'}',
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                                color: Colors.grey[500],
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),

                                      const SizedBox(height: 24),

                                      // Conversations List
                                      Expanded(
                                        child: ListView.builder(
                                          itemCount: _conversations.length,
                                          itemBuilder: (context, index) {
                                            final conversation = _conversations[index];
                                            return TweenAnimationBuilder(
                                              tween: Tween<double>(begin: 0, end: 1),
                                              duration: Duration(milliseconds: 600 + (index * 100)),
                                              curve: Curves.easeOutCubic,
                                              builder: (context, double value, child) {
                                                return Transform.translate(
                                                  offset: Offset(0, 50 * (1 - value)),
                                                  child: Opacity(
                                                    opacity: value,
                                                    child: Card(
                                                      elevation: 2,
                                                      margin: const EdgeInsets.only(bottom: 12),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(12),
                                                      ),
                                                      child: Padding(
                                                        padding: const EdgeInsets.all(16),
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            // Timestamp
                                                            Row(
                                                              children: [
                                                                Icon(
                                                                  Icons.access_time,
                                                                  size: 16,
                                                                  color: Colors.grey[500],
                                                                ),
                                                                const SizedBox(width: 4),
                                                                Text(
                                                                  _formatTimestamp(conversation['timestamp'] as Timestamp?),
                                                                  style: TextStyle(
                                                                    fontSize: 12,
                                                                    color: Colors.grey[500],
                                                                  ),
                                                                ),
                                                              ],
                                                            ),

                                                            const SizedBox(height: 12),

                                                            // User Message
                                                            Container(
                                                              width: double.infinity,
                                                              padding: const EdgeInsets.all(12),
                                                              decoration: BoxDecoration(
                                                                color: Colors.blue.shade50,
                                                                borderRadius: BorderRadius.circular(8),
                                                                border: Border.all(color: Colors.blue.shade200),
                                                              ),
                                                              child: Column(
                                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                                children: [
                                                                  Row(
                                                                    children: [
                                                                      Icon(
                                                                        Icons.person,
                                                                        size: 16,
                                                                        color: Colors.blue.shade700,
                                                                      ),
                                                                      const SizedBox(width: 4),
                                                                      Text(
                                                                        'Student\'s Message',
                                                                        style: TextStyle(
                                                                          fontSize: 12,
                                                                          fontWeight: FontWeight.w600,
                                                                          color: Colors.blue.shade700,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                  const SizedBox(height: 8),
                                                                  Text(
                                                                    conversation['userMessage'] ?? 'No message',
                                                                    style: const TextStyle(
                                                                      fontSize: 14,
                                                                      color: Colors.black87,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),

                                                            const SizedBox(height: 12),

                                                            // Bot Response
                                                            Container(
                                                              width: double.infinity,
                                                              padding: const EdgeInsets.all(12),
                                                              decoration: BoxDecoration(
                                                                color: Colors.green.shade50,
                                                                borderRadius: BorderRadius.circular(8),
                                                                border: Border.all(color: Colors.green.shade200),
                                                              ),
                                                              child: Column(
                                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                                children: [
                                                                  Row(
                                                                    children: [
                                                                      Icon(
                                                                        Icons.smart_toy,
                                                                        size: 16,
                                                                        color: Colors.green.shade700,
                                                                      ),
                                                                      const SizedBox(width: 4),
                                                                      Text(
                                                                        'AI Assistant Response',
                                                                        style: TextStyle(
                                                                          fontSize: 12,
                                                                          fontWeight: FontWeight.w600,
                                                                          color: Colors.green.shade700,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                  const SizedBox(height: 8),
                                                                  Text(
                                                                    conversation['botResponse'] ?? 'No response',
                                                                    style: const TextStyle(
                                                                      fontSize: 14,
                                                                      color: Colors.black87,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
