import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'student_list.dart';

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
  bool _isLoading = true;
  String? _errorMessage;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _countController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _countAnimation;

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

    _countController = AnimationController(
      duration: const Duration(milliseconds: 1500),
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

    _countAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _countController,
      curve: Curves.elasticOut,
    ));

    // Start entrance animations
    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      _slideController.forward();
    });

    // Load mentor data
    _loadMentorData();
  }

  Future<void> _loadMentorData() async {
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

      setState(() {
        _studentCount = studentsQuery.docs.length;
        if (_studentCount == 0) {
          _errorMessage = 'No students found from your college.';
        } else {
          _errorMessage = null;
        }
        _isLoading = false;
      });

      // Start count animation
      Future.delayed(const Duration(milliseconds: 500), () {
        _countController.forward();
      });

    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load data: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _countController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mentor Dashboard'),
        backgroundColor: Colors.orange,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _isLoading = true;
                _errorMessage = null;
              });
              _loadMentorData();
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
                    colors: [Colors.orange, Colors.deepOrange],
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
                                'Loading your dashboard...',
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
                                        _loadMentorData();
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: Colors.orange,
                                      ),
                                      child: const Text('Retry'),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Welcome Section
                                  TweenAnimationBuilder(
                                    tween: Tween<double>(begin: 0, end: 1),
                                    duration: const Duration(milliseconds: 800),
                                    curve: Curves.easeOutCubic,
                                    builder: (context, double value, child) {
                                      return Transform.translate(
                                        offset: Offset(0, 30 * (1 - value)),
                                        child: Opacity(
                                          opacity: value,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Welcome back,',
                                                style: TextStyle(
                                                  color: Colors.white.withOpacity(0.8),
                                                  fontSize: 18,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                _mentorName ?? 'Mentor',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 28,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                _mentorCollege ?? '',
                                                style: TextStyle(
                                                  color: Colors.white.withOpacity(0.7),
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),

                                  const SizedBox(height: 40),

                                  // Student Count Card
                                  TweenAnimationBuilder(
                                    tween: Tween<double>(begin: 0, end: 1),
                                    duration: const Duration(milliseconds: 1000),
                                    curve: Curves.elasticOut,
                                    builder: (context, double value, child) {
                                      return Transform.scale(
                                        scale: value,
                                        child: Card(
                                          elevation: 8,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.all(24),
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(
                                                colors: [Colors.white, Color(0xFFF5F5F5)],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Column(
                                              children: [
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    const Icon(
                                                      Icons.school,
                                                      size: 32,
                                                      color: Colors.orange,
                                                    ),
                                                    const SizedBox(width: 12),
                                                    const Text(
                                                      'Students in Your College',
                                                      style: TextStyle(
                                                        fontSize: 18,
                                                        fontWeight: FontWeight.w600,
                                                        color: Colors.black87,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 20),
                                                AnimatedBuilder(
                                                  animation: _countAnimation,
                                                  builder: (context, child) {
                                                    return Text(
                                                      '${(_studentCount * _countAnimation.value).toInt()}',
                                                      style: TextStyle(
                                                        fontSize: 48,
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.orange.shade700,
                                                      ),
                                                    );
                                                  },
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  'Total students under your mentorship',
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                    fontSize: 14,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),

                                  const SizedBox(height: 32),

                                  // Quick Actions
                                  TweenAnimationBuilder(
                                    tween: Tween<double>(begin: 0, end: 1),
                                    duration: const Duration(milliseconds: 1200),
                                    curve: Curves.easeOutCubic,
                                    builder: (context, double value, child) {
                                      return Transform.translate(
                                        offset: Offset(0, 30 * (1 - value)),
                                        child: Opacity(
                                          opacity: value,
                                          child: const Text(
                                            'Quick Actions',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 20,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),

                                  const SizedBox(height: 16),

                                  // Action Buttons
                                  TweenAnimationBuilder(
                                    tween: Tween<double>(begin: 0, end: 1),
                                    duration: const Duration(milliseconds: 1400),
                                    curve: Curves.easeOutCubic,
                                    builder: (context, double value, child) {
                                      return Transform.translate(
                                        offset: Offset(0, 30 * (1 - value)),
                                        child: Opacity(
                                          opacity: value,
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: _buildActionButton(
                                                  icon: Icons.people,
                                                  label: 'View Students',
                                                  color: Colors.blue,
                                                  onPressed: () {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (context) => const StudentListPage(),
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                              const SizedBox(width: 16),
                                              Expanded(
                                                child: _buildActionButton(
                                                  icon: Icons.calendar_today,
                                                  label: 'Schedule',
                                                  color: Colors.green,
                                                  onPressed: () {
                                                    // TODO: Navigate to scheduling page
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(
                                                        content: Text('Scheduling feature coming soon!'),
                                                        backgroundColor: Colors.green,
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),

                                  const SizedBox(height: 16),

                                  TweenAnimationBuilder(
                                    tween: Tween<double>(begin: 0, end: 1),
                                    duration: const Duration(milliseconds: 1600),
                                    curve: Curves.easeOutCubic,
                                    builder: (context, double value, child) {
                                      return Transform.translate(
                                        offset: Offset(0, 30 * (1 - value)),
                                        child: Opacity(
                                          opacity: value,
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: _buildActionButton(
                                                  icon: Icons.chat,
                                                  label: 'Messages',
                                                  color: Colors.purple,
                                                  onPressed: () {
                                                    // TODO: Navigate to messages page
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(
                                                        content: Text('Messages feature coming soon!'),
                                                        backgroundColor: Colors.purple,
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                              const SizedBox(width: 16),
                                              Expanded(
                                                child: _buildActionButton(
                                                  icon: Icons.library_books,
                                                  label: 'Resources',
                                                  color: Colors.teal,
                                                  onPressed: () {
                                                    // TODO: Navigate to resources page
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(
                                                        content: Text('Resources feature coming soon!'),
                                                        backgroundColor: Colors.teal,
                                                      ),
                                                    );
                                                  },
                                                ),
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
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: color,
        elevation: 4,
        shadowColor: color.withOpacity(0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
