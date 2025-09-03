import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'student_list.dart';
import 'mentor_message_page.dart';
import 'profile_page.dart';
import 'mentor_booking_management.dart';
import 'mentor_screening_monitor.dart';

class MentorHomePage extends StatefulWidget {
  const MentorHomePage({super.key});

  @override
  State<MentorHomePage> createState() => _MentorHomePageState();
}

class _MentorHomePageState extends State<MentorHomePage>
    with TickerProviderStateMixin {
  String? _mentorName;
  String? _mentorCollege;
  int _studentCount = 0;
  int _activeConversations = 0;
  int _pendingBookings = 0;
  bool _isLoading = true;
  String? _errorMessage;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _statsController;
  late AnimationController _cardController;
  late AnimationController _pulseController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _statsAnimation;
  late Animation<double> _cardAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _statsController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _cardController = AnimationController(
      duration: const Duration(milliseconds: 800),
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

    _statsAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _statsController,
      curve: Curves.elasticOut,
    ));

    _cardAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _cardController,
      curve: Curves.easeOutBack,
    ));

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // Start pulse animation (loops)
    _pulseController.repeat(reverse: true);

    // Load mentor data
    _loadMentorData();
  }

  Future<void> _loadMentorData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Start entrance animations
    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      _slideController.forward();
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _errorMessage = 'User not authenticated';
          _isLoading = false;
        });
        return;
      }

      // Get mentor data
      final mentorDoc = await FirebaseFirestore.instance
          .collection('mentors')
          .doc(user.uid)
          .get();

      if (!mentorDoc.exists) {
        setState(() {
          _errorMessage = 'Mentor data not found';
          _isLoading = false;
        });
        return;
      }

      final mentorData = mentorDoc.data()!;
      final college = mentorData['college'] as String;

      setState(() {
        _mentorName = mentorData['name'] as String;
        _mentorCollege = college;
      });

      // Count students from the same college
      final studentsQuery = await FirebaseFirestore.instance
          .collection('students')
          .where('college', isEqualTo: college)
          .get();

      // Count active conversations
      final conversationsQuery = await FirebaseFirestore.instance
          .collection('conversations')
          .get();

      int activeConversations = 0;
      for (var doc in conversationsQuery.docs) {
        final data = doc.data();
        if (data['messages'] != null && (data['messages'] as List).isNotEmpty) {
          activeConversations++;
        }
      }

      // Count pending bookings (mock data for now)
      final pendingBookings = (studentsQuery.docs.length * 0.3).round();

      setState(() {
        _studentCount = studentsQuery.docs.length;
        _activeConversations = activeConversations;
        _pendingBookings = pendingBookings;
        _isLoading = false;
      });

      // Start stats animation
      Future.delayed(const Duration(milliseconds: 600), () {
        _statsController.forward();
      });

      // Start card animation
      Future.delayed(const Duration(milliseconds: 900), () {
        _cardController.forward();
      });

    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load data: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Widget _buildLoadingScreen() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF8FFFE),
            Color(0xFFE8F5F3),
            Color(0xFFD6F0EB),
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
                  scale: value.clamp(0.0, 1.0),
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.teal[100]?.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(60),
                      border: Border.all(
                        color: Colors.teal[200]?.withOpacity(0.5) ?? Colors.teal,
                        width: 3,
                      ),
                    ),
                    child: Icon(
                      Icons.supervisor_account,
                      size: 60,
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
            TweenAnimationBuilder(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(milliseconds: 1000),
              curve: Curves.easeOut,
              builder: (context, double value, child) {
                return Opacity(
                  opacity: value.clamp(0.0, 1.0),
                  child: Column(
                    children: [
                      Text(
                        'Welcome Back, Mentor!',
                        style: TextStyle(
                          color: Colors.teal[700],
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Loading your dashboard...',
                        style: TextStyle(
                          color: Colors.teal[600]?.withOpacity(0.8),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
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
                  // Mentor Avatar
                  Hero(
                    tag: 'mentor_avatar',
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.teal[300] ?? Colors.teal,
                            Colors.teal[400] ?? Colors.teal,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(35),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.teal.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          _mentorName?.substring(0, 1).toUpperCase() ?? 'M',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Welcome Text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome back,',
                          style: TextStyle(
                            color: Colors.teal[600]?.withOpacity(0.8),
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _mentorName ?? 'Mentor',
                          style: TextStyle(
                            color: Colors.teal[700],
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_mentorCollege != null) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.teal[100]?.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _mentorCollege!,
                              style: TextStyle(
                                color: Colors.teal[700],
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Status Indicator
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.green[400],
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.green.withOpacity(0.5),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatsGrid() {
    return AnimatedBuilder(
      animation: _statsAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _statsAnimation.value.clamp(0.0, 1.0),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    title: 'Students',
                    value: _studentCount.toString(),
                    icon: Icons.school,
                    color: Colors.blue[400] ?? Colors.blue,
                    delay: 0,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    title: 'Active Chats',
                    value: _activeConversations.toString(),
                    icon: Icons.chat_bubble,
                    color: Colors.green[400] ?? Colors.green,
                    delay: 100,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    title: 'Bookings',
                    value: _pendingBookings.toString(),
                    icon: Icons.calendar_today,
                    color: Colors.purple[400] ?? Colors.purple,
                    delay: 200,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    int delay = 0,
  }) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 600 + delay),
      curve: Curves.easeOutBack,
      builder: (context, double animValue, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - animValue)),
          child: Opacity(
            opacity: animValue.clamp(0.0, 1.0),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
                border: Border.all(
                  color: color.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
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

  Widget _buildActionButtons() {
    final actions = [
      {
        'icon': Icons.people,
        'label': 'View Students',
        'color': Colors.blue[400],
        'onPressed': () => Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const StudentListPage(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(1.0, 0.0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              );
            },
          ),
        ),
      },
      {
        'icon': Icons.calendar_today,
        'label': 'Manage Bookings',
        'color': Colors.green[400],
        'onPressed': () => Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const MentorBookingManagementPage(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(1.0, 0.0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              );
            },
          ),
        ),
      },
      {
        'icon': Icons.assessment,
        'label': 'Screening Monitor',
        'color': Colors.indigo[400],
        'onPressed': () => Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const MentorScreeningMonitorPage(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(1.0, 0.0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              );
            },
          ),
        ),
      },
      {
        'icon': Icons.campaign,
        'label': 'Send Message',
        'color': Colors.purple[400],
        'onPressed': () => Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const MentorMessagePage(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(1.0, 0.0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              );
            },
          ),
        ),
      },
      {
        'icon': Icons.library_books,
        'label': 'Resources',
        'color': Colors.teal[400],
        'onPressed': () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.info, color: Colors.white),
                  const SizedBox(width: 12),
                  const Text('Resources feature coming soon!'),
                ],
              ),
              backgroundColor: Colors.teal[400],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        },
      },
    ];

    return AnimatedBuilder(
      animation: _cardAnimation,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Opacity(
                opacity: _cardAnimation.value.clamp(0.0, 1.0),
                child: Text(
                  'Quick Actions',
                  style: TextStyle(
                    color: Colors.teal[700],
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.2,
                ),
                itemCount: actions.length,
                itemBuilder: (context, index) {
                  final action = actions[index];
                  return TweenAnimationBuilder(
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: Duration(milliseconds: 600 + (index * 100)),
                    curve: Curves.easeOutBack,
                    builder: (context, double value, child) {
                      return Transform.scale(
                        scale: value.clamp(0.0, 1.0),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: action['onPressed'] as VoidCallback,
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: (action['color'] as Color).withOpacity(0.15),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                                border: Border.all(
                                  color: (action['color'] as Color).withOpacity(0.1),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: (action['color'] as Color).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(25),
                                    ),
                                    child: Icon(
                                      action['icon'] as IconData,
                                      color: action['color'] as Color,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    action['label'] as String,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                    textAlign: TextAlign.center,
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
            ],
          ),
        );
      },
    );
  }

  Widget _buildMotivationalQuote() {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOut,
      builder: (context, double value, child) {
        return Opacity(
          opacity: value,
          child: Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.8),
                  Colors.teal[50]?.withOpacity(0.6) ?? Colors.teal.withOpacity(0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.teal[100]?.withOpacity(0.5) ?? Colors.teal.withOpacity(0.2),
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
              children: [
                Icon(
                  Icons.format_quote,
                  color: Colors.teal[400],
                  size: 32,
                ),
                const SizedBox(height: 12),
                Text(
                  '"A mentor is someone who allows you to see the hope inside yourself."',
                  style: TextStyle(
                    color: Colors.teal[700],
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '- Oprah Winfrey',
                  style: TextStyle(
                    color: Colors.teal[600]?.withOpacity(0.8),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _statsController.dispose();
    _cardController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Mentor Dashboard',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.teal[700],
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.person_outline, color: Colors.teal[600]),
            onPressed: () {
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) => const ProfilePage(),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(1.0, 0.0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    );
                  },
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.teal[600]),
            onPressed: _loadMentorData,
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
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFF8FFFE), // Very light mint
                      Color(0xFFEBF8F5), // Light mint green
                      Color(0xFFE0F4F0), // Soft seafoam
                    ],
                  ),
                ),
                child: SafeArea(
                  child: _isLoading
                      ? _buildLoadingScreen()
                      : _errorMessage != null
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
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
                                      _errorMessage!,
                                      style: TextStyle(
                                        color: Colors.teal[700],
                                        fontSize: 16,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 24),
                                    ElevatedButton(
                                      onPressed: _loadMentorData,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.teal[400],
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: const Text('Try Again'),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : SingleChildScrollView(
                              child: Column(
                                children: [
                                  // Header with mentor info
                                  _buildHeader(),

                                  const SizedBox(height: 20),

                                  // Stats Grid
                                  _buildStatsGrid(),

                                  const SizedBox(height: 32),

                                  // Action Buttons
                                  _buildActionButtons(),

                                  // Motivational Quote
                                  _buildMotivationalQuote(),

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
