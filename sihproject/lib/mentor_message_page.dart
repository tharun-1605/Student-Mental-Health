import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MentorMessagePage extends StatefulWidget {
  const MentorMessagePage({super.key});

  @override
  State<MentorMessagePage> createState() => _MentorMessagePageState();
}

class _MentorMessagePageState extends State<MentorMessagePage>
    with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isSending = false;
  String _mentorName = '';
  String _collegeName = '';
  int _characterCount = 0;
  static const int _maxLength = 500;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _sendController;
  late AnimationController _successController;
  late AnimationController _pulseController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _sendAnimation;
  late Animation<double> _successAnimation;
  late Animation<double> _pulseAnimation;

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

    _sendController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _successController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
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

    _sendAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _sendController,
      curve: Curves.easeInOut,
    ));

    _successAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _successController,
      curve: Curves.elasticOut,
    ));

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // Setup text controller listener
    _messageController.addListener(() {
      setState(() {
        _characterCount = _messageController.text.length;
      });
    });

    _loadMentorData();
    
    // Start entrance animations
    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      _slideController.forward();
    });
  }

  Future<void> _loadMentorData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final mentorDoc = await FirebaseFirestore.instance
            .collection('mentors')
            .doc(user.uid)
            .get();
        
        if (mentorDoc.exists) {
          setState(() {
            _mentorName = mentorDoc.data()!['name'] ?? 'Mentor';
            _collegeName = mentorDoc.data()!['college'] ?? '';
          });
        }
      }
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      _showSnackBar('Please enter a message', Colors.amber);
      return;
    }

    if (message.length > _maxLength) {
      _showSnackBar('Message exceeds maximum length', Colors.red);
      return;
    }

    setState(() {
      _isSending = true;
    });

    _sendController.forward();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showSnackBar('User not authenticated', Colors.red);
        setState(() {
          _isSending = false;
        });
        return;
      }

      // Get mentor data to get college
      final mentorDoc = await FirebaseFirestore.instance
          .collection('mentors')
          .doc(user.uid)
          .get();
      if (!mentorDoc.exists) {
        _showSnackBar('Mentor data not found', Colors.red);
        setState(() {
          _isSending = false;
        });
        return;
      }
      final mentorData = mentorDoc.data()!;
      final college = mentorData['college'] as String;
      final mentorName = mentorData['name'] as String;

      // Store message in 'mentor_messages' collection
      await FirebaseFirestore.instance.collection('mentormessages').add({
        'mentorId': user.uid,
        'mentorName': mentorName,
        'college': college,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
      });

      _messageController.clear();
      _successController.forward();

      _showSnackBar('Message sent to all students successfully!', Colors.green);

      // Reset animations after success
      Future.delayed(const Duration(milliseconds: 2000), () {
        _successController.reverse();
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
              color == Colors.green ? Icons.check_circle : 
              color == Colors.amber ? Icons.warning : Icons.error,
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

  Widget _buildHeader() {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeOut,
      builder: (context, double value, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Container(
              padding: const EdgeInsets.all(24),
              margin: const EdgeInsets.all(20),
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
                    color: Colors.teal.withOpacity(0.15),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.teal[100]?.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Icon(
                          Icons.campaign,
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
                              'Broadcast Message',
                              style: TextStyle(
                                color: Colors.teal[700],
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Send to all students',
                              style: TextStyle(
                                color: Colors.teal[600]?.withOpacity(0.8),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_collegeName.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.teal[100]?.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.school,
                            color: Colors.teal[700],
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _collegeName,
                            style: TextStyle(
                              color: Colors.teal[700],
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessageInput() {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutBack,
      builder: (context, double value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.teal[100]?.withOpacity(0.5) ?? Colors.teal.withOpacity(0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.teal.withOpacity(0.08),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
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
                      child: Center(
                        child: Text(
                          _mentorName.isNotEmpty ? _mentorName.substring(0, 1).toUpperCase() : 'M',
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
                            _mentorName.isNotEmpty ? _mentorName : 'Mentor',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const Text(
                            'Composing message...',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Message Input
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _focusNode.hasFocus ? Colors.teal[400]! : Colors.grey[300]!,
                      width: 2,
                    ),
                  ),
                  child: TextField(
                    controller: _messageController,
                    focusNode: _focusNode,
                    maxLines: 8,
                    maxLength: _maxLength,
                    decoration: const InputDecoration(
                      hintText: 'Write your message to all students...\n\nShare important updates, motivational messages, or helpful resources.',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(16),
                      counterText: '',
                    ),
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Character Counter and Tips
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '💡 Tip: Be encouraging and supportive in your messages',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _characterCount > _maxLength * 0.8 
                            ? Colors.red[100] 
                            : Colors.teal[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$_characterCount/$_maxLength',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _characterCount > _maxLength * 0.8 
                              ? Colors.red[700] 
                              : Colors.teal[600],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSendButton() {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutBack,
      builder: (context, double value, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Container(
              margin: const EdgeInsets.all(20),
              child: AnimatedBuilder(
                animation: _sendAnimation,
                builder: (context, child) {
                  return AnimatedBuilder(
                    animation: _successAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _successAnimation.value > 0 ? _successAnimation.value : 1.0,
                        child: SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton.icon(
                            onPressed: _isSending ? null : _sendMessage,
                            icon: _isSending
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
                                : _successAnimation.value > 0
                                    ? const Icon(Icons.check_circle, size: 24)
                                    : const Icon(Icons.send, size: 24),
                            label: Text(
                              _isSending 
                                  ? 'Sending Message...' 
                                  : _successAnimation.value > 0
                                      ? 'Message Sent!'
                                      : 'Send to All Students',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _successAnimation.value > 0
                                  ? Colors.green
                                  : Colors.teal[500],
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: _isSending ? 0 : 4,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickTips() {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOut,
      builder: (context, double value, child) {
        return Opacity(
          opacity: value,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.teal[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.teal[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb_outline, color: Colors.teal[600]),
                    const SizedBox(width: 8),
                    Text(
                      'Message Guidelines',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildTip('✨ Be encouraging and supportive'),
                _buildTip('📚 Share helpful resources or tips'),
                _buildTip('🎯 Keep messages clear and actionable'),
                _buildTip('💙 Show empathy and understanding'),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTip(String tip) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        tip,
        style: TextStyle(
          fontSize: 14,
          color: Colors.teal[600],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _focusNode.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _sendController.dispose();
    _successController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Broadcast Message',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.teal[700],
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.teal[700]),
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
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // Header Section
                        _buildHeader(),
                        
                        const SizedBox(height: 10),
                        
                        // Message Input Section
                        _buildMessageInput(),
                        
                        const SizedBox(height: 20),
                        
                        // Send Button
                        _buildSendButton(),
                        
                        // Quick Tips
                        _buildQuickTips(),
                        
                        const SizedBox(height: 20),
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
