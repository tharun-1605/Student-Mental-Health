import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';

class AnonymousStudentToMentorChatPage extends StatefulWidget {
  const AnonymousStudentToMentorChatPage({super.key});

  @override
  _AnonymousStudentToMentorChatPageState createState() =>
      _AnonymousStudentToMentorChatPageState();
}

class _AnonymousStudentToMentorChatPageState
    extends State<AnonymousStudentToMentorChatPage> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _headerController;
  late AnimationController _sendController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _headerAnimation;
  late Animation<double> _sendAnimation;

  List<Map<String, dynamic>> _mentors = [];
  String? _selectedMentorId;
  String? _selectedMentorName;
  String? _studentCollege;
  bool _isLoadingMentors = true;
  bool _isSending = false;
  final int _maxLength = 500;

  List<Map<String, dynamic>> _messages = [];
  StreamSubscription? _messagesSubscription;
  bool _showChatView = false;
  String? _anonymousId;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadUserDataAndMentors();
    
    // Setup text controller listener
    _messageController.addListener(() {
      setState(() {}); // Refresh for character counter
    });
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _headerController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _sendController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

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

    _headerAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _headerController,
      curve: Curves.elasticOut,
    ));

    _sendAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _sendController,
      curve: Curves.easeInOut,
    ));

    _fadeController.forward();
    _slideController.forward();
  }

  Future<void> _loadUserDataAndMentors() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showSnackBar('User not authenticated. Please log in.', Colors.red);
        return;
      }

      final studentDoc = await FirebaseFirestore.instance
          .collection('students')
          .doc(user.uid)
          .get();
      
      if (!studentDoc.exists) {
        _showSnackBar('Student profile not found.', Colors.red);
        return;
      }

      final data = studentDoc.data();
      if (data == null) {
        _showSnackBar('Student data is empty.', Colors.red);
        return;
      }

      setState(() {
        _studentCollege = data['college'] as String?;
        _anonymousId = data['anonymousId'] as String?;
      });

      if (_anonymousId == null) {
        await _generateAndSaveAnonymousId(user.uid);
      }
      
      await _loadMentors();
    } catch (e) {
      _showSnackBar('Failed to load user data: $e', Colors.red);
      setState(() {
        _isLoadingMentors = false;
      });
    }
  }

  Future<void> _generateAndSaveAnonymousId(String uid) async {
    try {
      const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
      Random rnd = Random();
      final newAnonymousId = String.fromCharCodes(Iterable.generate(
          8, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
      
      await FirebaseFirestore.instance
          .collection('students')
          .doc(uid)
          .update({'anonymousId': newAnonymousId});
      
      setState(() {
        _anonymousId = newAnonymousId;
      });
    } catch (e) {
      _showSnackBar('Failed to generate anonymous ID: $e', Colors.red);
    }
  }

  Future<void> _loadMentors() async {
    if (_studentCollege == null) {
      _showSnackBar('Student college information not found.', Colors.orange);
      setState(() {
        _isLoadingMentors = false;
      });
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('mentors')
          .where('college', isEqualTo: _studentCollege)
          .get();
      
      setState(() {
        _mentors = snapshot.docs
            .map((doc) => {
                  'id': doc.id,
                  'name': doc.data()['name'] as String? ?? 'Unknown Mentor',
                  'department': doc.data()['department'] as String? ?? 'General',
                })
            .toList();
        _isLoadingMentors = false;
      });

      // Start header animation after loading
      Future.delayed(const Duration(milliseconds: 500), () {
        _headerController.forward();
      });
    } catch (e) {
      _showSnackBar('Failed to load mentors: $e', Colors.red);
      setState(() {
        _isLoadingMentors = false;
      });
    }
  }

  void _openChat(String mentorId, String mentorName) {
    setState(() {
      _selectedMentorId = mentorId;
      _selectedMentorName = mentorName;
      _showChatView = true;
      _messages = [];
    });
    _loadMessages();
  }

  void _closeChat() {
    setState(() {
      _showChatView = false;
      _selectedMentorId = null;
      _selectedMentorName = null;
    });
    _messagesSubscription?.cancel();
  }

  Future<void> _loadMessages() async {
    if (_selectedMentorId == null || _anonymousId == null) return;

    _messagesSubscription?.cancel();
    _messagesSubscription = FirebaseFirestore.instance
        .collection('anonymous_chats')
        .doc('${_anonymousId}_$_selectedMentorId')
        .collection('messages')
        .orderBy('timestamp')
        .snapshots()
        .listen((snapshot) {
      setState(() {
        _messages = snapshot.docs
            .map((doc) {
              final data = doc.data();
              return {
                'message': data['message'] as String? ?? '',
                'senderId': data['senderId'] as String? ?? '',
                'timestamp': (data['timestamp'] as Timestamp?)?.toDate(),
                'id': doc.id,
              };
            })
            .toList();
      });
      _scrollToBottom();
    }, onError: (error) {
      _showSnackBar('Failed to load messages: $error', Colors.red);
    });
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _selectedMentorId == null || _anonymousId == null) {
      return;
    }

    if (message.length > _maxLength) {
      _showSnackBar('Message too long. Maximum $_maxLength characters.', Colors.orange);
      return;
    }

    setState(() {
      _isSending = true;
    });

    _sendController.forward();

    try {
      final chatDocRef = FirebaseFirestore.instance
          .collection('anonymous_chats')
          .doc('${_anonymousId}_$_selectedMentorId');

      await chatDocRef.collection('messages').add({
        'message': message,
        'senderId': _anonymousId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await chatDocRef.set({
        'studentId': _anonymousId,
        'mentorId': _selectedMentorId,
        'lastMessage': message,
        'timestamp': FieldValue.serverTimestamp(),
        'studentName': 'Anonymous',
        'mentorName': _selectedMentorName,
        'hasUnreadMentorMessages': true,
      }, SetOptions(merge: true));

      _messageController.clear();
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

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                color == Colors.green ? Icons.check_circle : 
                color == Colors.orange ? Icons.warning : Icons.error,
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
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  Widget _buildHeader({required String title, required String subtitle, required IconData icon}) {
    return AnimatedBuilder(
      animation: _headerAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _headerAnimation.value,
          child: Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.9),
                  Colors.teal[50]?.withOpacity(0.8) ?? Colors.teal.withOpacity(0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.teal[100]?.withOpacity(0.5) ?? Colors.teal.withOpacity(0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.teal.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.teal[100]?.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.teal[600],
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: Colors.teal[700],
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.teal[600]?.withOpacity(0.8),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_anonymousId != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.teal[100]?.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lock,
                          color: Colors.teal[700],
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'ID: $_anonymousId',
                          style: TextStyle(
                            color: Colors.teal[700],
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMentorCard(Map<String, dynamic> mentor, int index) {
    final mentorName = mentor['name'] as String? ?? 'Unknown Mentor';
    final department = mentor['department'] as String? ?? 'General';
    
    // Generate consistent color for each mentor
    final colors = [
      [Colors.blue[400]!, Colors.blue[600]!],
      [Colors.green[400]!, Colors.green[600]!],
      [Colors.purple[400]!, Colors.purple[600]!],
      [Colors.teal[400]!, Colors.teal[600]!],
      [Colors.orange[400]!, Colors.orange[600]!],
    ];
    final colorPair = colors[index % colors.length];

    return TweenAnimationBuilder(
      key: ValueKey(mentor['id']),
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 600 + (index * 100)),
      curve: Curves.easeOutBack,
      builder: (context, double value, child) {
        return Transform.translate(
          offset: Offset(50 * (1 - value), 0),
          child: Transform.scale(
            scale: value,
            child: Opacity(
              opacity: value,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _openChat(mentor['id'] as String, mentorName),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: colorPair[0].withOpacity(0.1),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colorPair[0].withOpacity(0.15),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 55,
                            height: 55,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: colorPair,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(27.5),
                              boxShadow: [
                                BoxShadow(
                                  color: colorPair[1].withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                mentorName.isNotEmpty ? mentorName[0].toUpperCase() : 'M',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
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
                                  mentorName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  department,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.teal[50],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Tap to start anonymous chat',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.teal[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: colorPair[0].withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: colorPair[0],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, int index) {
    final isMe = message['senderId'] == _anonymousId;
    final timestamp = message['timestamp'] as DateTime?;

    return TweenAnimationBuilder(
      key: ValueKey(message['id']),
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + (index * 50)),
      curve: Curves.easeOutBack,
      builder: (context, double value, child) {
        return Transform.scale(
          scale: value,
          child: Opacity(
            opacity: value,
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
                            gradient: LinearGradient(
                              colors: [Colors.teal[400]!, Colors.teal[600]!],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 18,
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
                                    colors: [Colors.blue[400]!, Colors.blue[600]!],
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
                                    ? Colors.blue.withOpacity(0.3)
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
                                  _selectedMentorName ?? 'Mentor',
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
                              colors: [Colors.blue[400]!, Colors.blue[600]!],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Center(
                            child: Text(
                              'A',
                              style: TextStyle(
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
                      timestamp != null ? _formatTimestamp(timestamp) : '',
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
    return Container(
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
      child: Column(
        children: [
          Row(
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
                    maxLength: _maxLength,
                    decoration: InputDecoration(
                      hintText: 'Type your anonymous message...',
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      counterText: '',
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
                              ? [Colors.blue[400]!, Colors.blue[600]!]
                              : [Colors.grey[300]!, Colors.grey[400]!],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: _messageController.text.trim().isNotEmpty
                            ? [
                                BoxShadow(
                                  color: Colors.blue.withOpacity(0.3),
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
          
          const SizedBox(height: 8),
          
          Row(
            children: [
              Expanded(
                child: Text(
                  '💡 Your identity is completely anonymous',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _messageController.text.length > _maxLength * 0.8 
                      ? Colors.red[100] 
                      : Colors.teal[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_messageController.text.length}/$_maxLength',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _messageController.text.length > _maxLength * 0.8 
                        ? Colors.red[700] 
                        : Colors.teal[600],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Container(
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
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(milliseconds: 1500),
              curve: Curves.elasticOut,
              builder: (context, double value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.teal[100]?.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(
                        color: Colors.teal[200]?.withOpacity(0.5) ?? Colors.teal,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.chat_bubble_outline,
                      size: 50,
                      color: Colors.teal[600],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
            CircularProgressIndicator(
              color: Colors.teal[400],
              strokeWidth: 3,
            ),
            const SizedBox(height: 24),
            Text(
              'Loading Mentors...',
              style: TextStyle(
                color: Colors.teal[700],
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: TweenAnimationBuilder(
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 1000),
        curve: Curves.easeOut,
        builder: (context, double value, child) {
          return Opacity(
            opacity: value,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Transform.scale(
                  scale: value,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.teal[100]?.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(60),
                      border: Border.all(
                        color: Colors.teal[200]?.withOpacity(0.5) ?? Colors.teal,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.school_outlined,
                      color: Colors.teal[400],
                      size: 64,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'No Mentors Available',
                  style: TextStyle(
                    color: Colors.teal[700],
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'No mentors are available in your college at the moment.\nPlease check back later.',
                  style: TextStyle(
                    color: Colors.teal[600]?.withOpacity(0.8),
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
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
    _headerController.dispose();
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
          _showChatView
              ? _selectedMentorName ?? 'Chat'
              : 'Anonymous Mentor Chat',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.teal[700],
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.teal[700]),
        leading: _showChatView
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _closeChat,
              )
            : null,
      ),
      body: Container(
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
          child: _showChatView ? _buildChatView() : _buildMentorListView(),
        ),
      ),
    );
  }

  Widget _buildMentorListView() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Column(
          children: [
            _buildHeader(
              title: 'Anonymous Chat',
              subtitle: 'Choose a mentor to chat with privately',
              icon: Icons.chat_bubble_outline,
            ),
            
            const SizedBox(height: 10),
            
            Expanded(
              child: _isLoadingMentors
                  ? _buildLoadingScreen()
                  : _mentors.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 20),
                          itemCount: _mentors.length,
                          itemBuilder: (context, index) {
                            return _buildMentorCard(_mentors[index], index);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatView() {
    return Column(
      children: [
        // Chat Header
        Container(
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
                  gradient: LinearGradient(
                    colors: [Colors.teal[400]!, Colors.teal[600]!],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Center(
                  child: Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              
              const SizedBox(width: 12),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedMentorName ?? 'Mentor',
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
        ),
        
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
                        'Your messages are completely anonymous',
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
    );
  }
}
