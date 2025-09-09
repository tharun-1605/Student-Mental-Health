import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MentorChatPage extends StatefulWidget {
  final String chatId;
  final String studentName;

  const MentorChatPage({super.key, required this.chatId, required this.studentName});

  @override
  _MentorChatPageState createState() => _MentorChatPageState();
}

class _MentorChatPageState extends State<MentorChatPage>
    with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;
  bool _isTyping = false;
  String? _mentorId;
  String? _mentorName;

  List<Map<String, dynamic>> _messages = [];
  StreamSubscription? _messagesSubscription;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _sendController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _sendAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controllers
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _sendController = AnimationController(
      duration: const Duration(milliseconds: 400),
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
      begin: const Offset(0, 1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _sendAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _sendController,
      curve: Curves.easeInOut,
    ));

    _mentorId = FirebaseAuth.instance.currentUser?.uid;
    _loadMentorData();
    _loadMessages();
    
    // Setup text controller listener for typing indicator
    _messageController.addListener(() {
      if (_messageController.text.isNotEmpty && !_isTyping) {
        setState(() {
          _isTyping = true;
        });
      } else if (_messageController.text.isEmpty && _isTyping) {
        setState(() {
          _isTyping = false;
        });
      }
    });

    // Start entrance animations
    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      _slideController.forward();
    });
  }

  Future<void> _loadMentorData() async {
    try {
      if (_mentorId != null) {
        final mentorDoc = await FirebaseFirestore.instance
            .collection('mentors')
            .doc(_mentorId)
            .get();
        
        if (mentorDoc.exists) {
          setState(() {
            _mentorName = mentorDoc.data()!['name'] ?? 'Mentor';
          });
        }
      }
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _loadMessages() async {
    _messagesSubscription?.cancel();
    _messagesSubscription = FirebaseFirestore.instance
        .collection('anonymous_chats')
        .doc(widget.chatId)
        .collection('messages')
        .orderBy('timestamp')
        .snapshots()
        .listen((snapshot) {
      setState(() {
        _messages = snapshot.docs
            .map((doc) => {
                  'message': doc.data()['message'],
                  'senderId': doc.data()['senderId'],
                  'timestamp': (doc.data()['timestamp'] as Timestamp?)?.toDate(),
                  'id': doc.id,
                })
            .toList();
      });
      _scrollToBottom();
    });
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _mentorId == null) {
      return;
    }

    setState(() {
      _isSending = true;
    });

    _sendController.forward();

    try {
      final chatDocRef = FirebaseFirestore.instance
          .collection('anonymous_chats')
          .doc(widget.chatId);

      await chatDocRef.collection('messages').add({
        'message': message,
        'senderId': _mentorId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await chatDocRef.update({
        'lastMessage': message,
        'timestamp': FieldValue.serverTimestamp(),
        'hasUnreadMentorMessages': false,
      });

      _messageController.clear();
      setState(() {
        _isTyping = false;
      });
      _scrollToBottom();

      // Reset send animation
      Future.delayed(const Duration(milliseconds: 1000), () {
        _sendController.reverse();
      });

    } catch (e) {
      _showSnackBar('Failed to send message: $e', Colors.red);
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              color == Colors.green ? Icons.check_circle : Icons.error,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  String _formatMessageTime(DateTime? timestamp) {
    if (timestamp == null) return '';
    
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays == 0) {
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else {
      return '${timestamp.day}/${timestamp.month} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, int index) {
    final isMe = message['senderId'] == _mentorId;
    final timestamp = message['timestamp'] as DateTime?;

    return TweenAnimationBuilder(
      key: ValueKey(message['id']),
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + (index * 50)),
      curve: Curves.easeOutBack,
      builder: (context, double value, child) {
        final clampedValue = value.clamp(0.0, 1.0);
        return Transform.scale(
          scale: clampedValue,
          child: Opacity(
            opacity: clampedValue,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                    children: [
                      if (!isMe) ...[
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Colors.blue, Colors.blueAccent],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(
                              widget.studentName.substring(0, 1).toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      
                      Flexible(
                        child: Container(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 16,
                          ),
                          decoration: BoxDecoration(
                            gradient: isMe
                                ? LinearGradient(
                                    colors: [Colors.teal[400]!, Colors.teal[600]!],
                                  )
                                : const LinearGradient(
                                    colors: [Colors.white, Colors.white],
                                  ),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(20),
                              topRight: const Radius.circular(20),
                              bottomLeft: Radius.circular(isMe ? 20 : 4),
                              bottomRight: Radius.circular(isMe ? 4 : 20),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isMe 
                                    ? Colors.teal.withOpacity(0.3)
                                    : Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                            border: !isMe 
                                ? Border.all(color: Colors.grey[200]!) 
                                : null,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!isMe)
                                Text(
                                  widget.studentName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              if (!isMe) const SizedBox(height: 4),
                              Text(
                                message['message'],
                                style: TextStyle(
                                  fontSize: 16,
                                  color: isMe ? Colors.white : Colors.black87,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      if (isMe) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.teal[400]!, Colors.teal[600]!],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(
                              _mentorName?.substring(0, 1).toUpperCase() ?? 'M',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  
                  const SizedBox(height: 4),
                  
                  Padding(
                    padding: EdgeInsets.only(
                      left: isMe ? 40 : 40,
                      right: isMe ? 0 : 40,
                    ),
                    child: Text(
                      _formatMessageTime(timestamp),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessageInput() {
    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return SlideTransition(
          position: _slideAnimation,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: _focusNode.hasFocus ? Colors.teal[400]! : Colors.grey[300]!,
                        width: 2,
                      ),
                    ),
                    child: TextField(
                      controller: _messageController,
                      focusNode: _focusNode,
                      maxLines: null,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(color: Colors.grey[500]),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      style: const TextStyle(fontSize: 16),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                
                const SizedBox(width: 12),
                
                AnimatedBuilder(
                  animation: _sendAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _sendAnimation.value > 0 ? _sendAnimation.value : 1.0,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _messageController.text.trim().isNotEmpty
                                ? [Colors.teal[400]!, Colors.teal[600]!]
                                : [Colors.grey[300]!, Colors.grey[400]!],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: _messageController.text.trim().isNotEmpty
                              ? [
                                  BoxShadow(
                                    color: Colors.teal.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : [],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(24),
                            onTap: _messageController.text.trim().isNotEmpty && !_isSending
                                ? _sendMessage
                                : null,
                            child: Center(
                              child: _isSending
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white.withOpacity(0.8),
                                        ),
                                      ),
                                    )
                                  : Icon(
                                      Icons.send,
                                      color: _messageController.text.trim().isNotEmpty
                                          ? Colors.white
                                          : Colors.grey[600],
                                      size: 20,
                                    ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildChatHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.9),
            Colors.teal[50]?.withOpacity(0.8) ?? Colors.teal.withOpacity(0.1),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.blue, Colors.blueAccent],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                widget.studentName.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.studentName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal[700],
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Anonymous Chat',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.teal[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock,
                  size: 12,
                  color: Colors.teal[600],
                ),
                const SizedBox(width: 4),
                Text(
                  'Private',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.teal[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _messagesSubscription?.cancel();
    _fadeController.dispose();
    _slideController.dispose();
    _sendController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          widget.studentName,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.teal[700],
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.teal[700]),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: Colors.teal[600]),
            onSelected: (value) {
              if (value == 'clear') {
                // Add clear chat functionality if needed
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'info',
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16),
                    SizedBox(width: 8),
                    Text('Chat Info'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFF8FFFE), // Very light mint (almost white)
                    Color(0xFFEBF8F5), // Light mint green
                    Color(0xFFE0F4F0), // Soft seafoam
                  ],
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    // Chat Header
                    _buildChatHeader(),
                    
                    // Messages
                    Expanded(
                      child: _messages.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: Colors.teal[100]?.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(40),
                                    ),
                                    child: Icon(
                                      Icons.chat_bubble_outline,
                                      color: Colors.teal[400],
                                      size: 40,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Start the conversation',
                                    style: TextStyle(
                                      color: Colors.teal[600],
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Send a supportive message to ${widget.studentName}',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: _messages.length,
                              itemBuilder: (context, index) {
                                return _buildMessageBubble(_messages[index], index);
                              },
                            ),
                    ),
                    
                    // Message Input
                    _buildMessageInput(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
