  import 'package:flutter/material.dart';
  import 'package:cloud_firestore/cloud_firestore.dart';
  import 'package:firebase_auth/firebase_auth.dart';
  import 'mentor_chat_page.dart';

  class MentorAnonymousMessagesPage extends StatefulWidget {
    const MentorAnonymousMessagesPage({super.key});

    @override
    _MentorAnonymousMessagesPageState createState() =>
        _MentorAnonymousMessagesPageState();
  }

  class _MentorAnonymousMessagesPageState extends State<MentorAnonymousMessagesPage>
      with TickerProviderStateMixin {
    String? _mentorId;
    bool _isLoading = true;

    late AnimationController _fadeController;
    late AnimationController _slideController;
    late AnimationController _headerController;

    late Animation<double> _fadeAnimation;
    late Animation<Offset> _slideAnimation;
    late Animation<double> _headerAnimation;

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

      _headerController = AnimationController(
        duration: const Duration(milliseconds: 1200),
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

      _headerAnimation = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: _headerController,
        curve: Curves.elasticOut,
      ));

      _loadMentorId();
      
      // Start entrance animations
      _fadeController.forward();
      Future.delayed(const Duration(milliseconds: 300), () {
        _slideController.forward();
      });
    }

    Future<void> _loadMentorId() async {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        setState(() {
          _mentorId = user.uid;
          _isLoading = false;
        });
        
        // Start header animation after loading
        Future.delayed(const Duration(milliseconds: 500), () {
          _headerController.forward();
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    }

    void _openChat(String chatId, String studentName) {
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => 
              MentorChatPage(chatId: chatId, studentName: studentName),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1.0, 0.0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeInOut,
              )),
              child: FadeTransition(
                opacity: animation,
                child: child,
              ),
            );
          },
        ),
      );
    }

    String _formatTimestamp(Timestamp? timestamp) {
      if (timestamp == null) return 'Just now';
      
      final dateTime = timestamp.toDate();
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inHours < 1) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inDays < 1) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      }
    }

    Widget _buildHeader() {
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
                      Icons.chat_bubble_outline,
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
                          'Anonymous Chats',
                          style: TextStyle(
                            color: Colors.teal[700],
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Private conversations with students',
                          style: TextStyle(
                            color: Colors.teal[600]?.withOpacity(0.8),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
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
                          Icons.lock,
                          color: Colors.teal[700],
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Secure',
                          style: TextStyle(
                            color: Colors.teal[700],
                            fontSize: 12,
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

    Widget _buildChatCard(DocumentSnapshot chat, int index) {
      final studentName = chat['studentName'] ?? 'Anonymous';
      final lastMessage = chat['lastMessage'] ?? 'No messages yet';
      final timestamp = chat['timestamp'] as Timestamp?;
      final hasUnreadMessages = (chat.data() as Map<String, dynamic>).containsKey('hasUnreadMentorMessages') == true
          ? chat['hasUnreadMentorMessages'] ?? false
          : false;

      // Generate consistent color for each student based on their name
      final colors = [
        [Colors.blue[400]!, Colors.blue[600]!],
        [Colors.green[400]!, Colors.green[600]!],
        [Colors.purple[400]!, Colors.purple[600]!],
        [Colors.teal[400]!, Colors.teal[600]!],
        [Colors.orange[400]!, Colors.orange[600]!],
        [Colors.pink[400]!, Colors.pink[600]!],
      ];
      final colorPair = colors[studentName.hashCode.abs() % colors.length];

      return TweenAnimationBuilder(
        key: ValueKey(chat.id),
        tween: Tween<double>(begin: 0, end: 1),
        duration: Duration(milliseconds: 600 + (index * 100)),
        curve: Curves.easeOutBack,
        builder: (context, double value, child) {
          final clampedValue = value.clamp(0.0, 1.0);
          return Transform.translate(
            offset: Offset(50 * (1 - clampedValue), 0),
            child: Transform.scale(
              scale: clampedValue,
              child: Opacity(
                opacity: clampedValue,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _openChat(chat.id, studentName),
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
                            // Enhanced Avatar
                            Stack(
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
                                    child: studentName.isNotEmpty
                                        ? Text(
                                            studentName.substring(0, 1).toUpperCase(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.person,
                                            color: Colors.white,
                                            size: 24,
                                          ),
                                  ),
                                ),
                                // Online indicator
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(width: 16),

                            // Message Content
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          studentName,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                      if (hasUnreadMessages)
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    lastMessage,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                      height: 1.3,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.access_time,
                                        size: 14,
                                        color: Colors.grey[500],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _formatTimestamp(timestamp),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
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
                                ],
                              ),
                            ),

                            const SizedBox(width: 12),

                            // Arrow Icon
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

    Widget _buildEmptyState() {
      return Center(
        child: TweenAnimationBuilder(
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(milliseconds: 1000),
          curve: Curves.easeOut,
          builder: (context, double value, child) {
            final clampedValue = value.clamp(0.0, 1.0);
            return Opacity(
              opacity: clampedValue,
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
                        Icons.chat_bubble_outline,
                        color: Colors.teal[400],
                        size: 64,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'No Anonymous Chats Yet',
                    style: TextStyle(
                      color: Colors.teal[700],
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Students can start anonymous conversations\nwith you for private support.',
                    style: TextStyle(
                      color: Colors.teal[600]?.withOpacity(0.8),
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.teal[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.teal[200]!),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.info_outline, color: Colors.teal[600]),
                        const SizedBox(height: 8),
                        Text(
                          'Anonymous chats provide a safe space for students to seek help without revealing their identity.',
                          style: TextStyle(
                            color: Colors.teal[600],
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
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
                  final clampedValue = value.clamp(0.0, 1.0);
                  return Transform.scale(
                    scale: clampedValue,
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
                'Loading Chats...',
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

    @override
    void dispose() {
      _fadeController.dispose();
      _slideController.dispose();
      _headerController.dispose();
      super.dispose();
    }

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text(
            'Anonymous Chats',
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
                    child: _isLoading
                        ? _buildLoadingScreen()
                        : _mentorId == null
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      color: Colors.teal[400],
                                      size: 64,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Authentication Error',
                                      style: TextStyle(
                                        color: Colors.teal[700],
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Please log in again',
                                      style: TextStyle(
                                        color: Colors.teal[600],
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : Column(
                                children: [
                                  // Header
                                  _buildHeader(),

                                  // Chat List
                                  Expanded(
                                    child: StreamBuilder<QuerySnapshot>(
                                      stream: FirebaseFirestore.instance
                                          .collection('anonymous_chats')
                                          .where('mentorId', isEqualTo: _mentorId)
                                          .orderBy('timestamp', descending: true)
                                          .snapshots(),
                                      builder: (context, snapshot) {
                                        if (snapshot.connectionState == ConnectionState.waiting) {
                                          return Center(
                                            child: CircularProgressIndicator(
                                              color: Colors.teal[400],
                                            ),
                                          );
                                        }

                                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                                          return _buildEmptyState();
                                        }

                                        return ListView.builder(
                                          padding: const EdgeInsets.only(bottom: 20),
                                          itemCount: snapshot.data!.docs.length,
                                          itemBuilder: (context, index) {
                                            return _buildChatCard(
                                              snapshot.data!.docs[index],
                                              index,
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
            );
          },
        ),
    );
  }
}
