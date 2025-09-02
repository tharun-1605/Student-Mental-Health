import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'student_conversations.dart';

class StudentListPage extends StatefulWidget {
  const StudentListPage({super.key});

  @override
  State<StudentListPage> createState() => _StudentListPageState();
}

class _StudentListPageState extends State<StudentListPage>
    with TickerProviderStateMixin {
  String? _mentorCollege;
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _students = [];

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

    // Load students
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _errorMessage = 'User not authenticated';
          _isLoading = false;
        });
        return;
      }

      // Get mentor's college
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
        _mentorCollege = college;
      });

      // Get all students from the same college
      final studentsQuery = await FirebaseFirestore.instance
          .collection('students')
          .where('college', isEqualTo: college)
          .get();

      List<Map<String, dynamic>> students = [];
      for (var doc in studentsQuery.docs) {
        final studentData = doc.data();
        studentData['id'] = doc.id;

        // Get conversation count for this student
        final conversationCount = await FirebaseFirestore.instance
            .collection('conversations')
            .where('userId', isEqualTo: doc.id)
            .get();

        studentData['conversationCount'] = conversationCount.docs.length;
        students.add(studentData);
      }

      setState(() {
        _students = students;
        _isLoading = false;
      });

    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load students: ${e.toString()}';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Students'),
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
              _loadStudents();
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
                                'Loading students...',
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
                                        _loadStudents();
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
                          : _students.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24.0),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.school_outlined,
                                          color: Colors.white,
                                          size: 64,
                                        ),
                                        const SizedBox(height: 16),
                                        const Text(
                                          'No students found',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 20,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'No students from ${_mentorCollege ?? 'your college'} have registered yet.',
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
                                      // Header
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
                                                    'Students from ${_mentorCollege ?? 'your college'}',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 20,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    '${_students.length} student${_students.length == 1 ? '' : 's'} under your mentorship',
                                                    style: TextStyle(
                                                      color: Colors.white.withOpacity(0.7),
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),

                                      const SizedBox(height: 24),

                                      // Students List
                                      Expanded(
                                        child: ListView.builder(
                                          itemCount: _students.length,
                                          itemBuilder: (context, index) {
                                            final student = _students[index];
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
                                                      elevation: 4,
                                                      margin: const EdgeInsets.only(bottom: 12),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(16),
                                                      ),
                                                      child: InkWell(
                                                        onTap: () {
                                                          Navigator.push(
                                                            context,
                                                            MaterialPageRoute(
                                                              builder: (context) => StudentConversationsPage(
                                                                studentId: student['id'],
                                                                studentName: student['name'],
                                                                studentEmail: student['email'],
                                                              ),
                                                            ),
                                                          );
                                                        },
                                                        borderRadius: BorderRadius.circular(16),
                                                        child: Padding(
                                                          padding: const EdgeInsets.all(16),
                                                          child: Row(
                                                            children: [
                                                              // Student Avatar
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
                                                                    (student['name'] as String).substring(0, 1).toUpperCase(),
                                                                    style: const TextStyle(
                                                                      color: Colors.white,
                                                                      fontSize: 20,
                                                                      fontWeight: FontWeight.bold,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),

                                                              const SizedBox(width: 16),

                                                              // Student Info
                                                              Expanded(
                                                                child: Column(
                                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                                  children: [
                                                                    Text(
                                                                      student['name'] ?? 'Unknown',
                                                                      style: const TextStyle(
                                                                        fontSize: 18,
                                                                        fontWeight: FontWeight.w600,
                                                                        color: Colors.black87,
                                                                      ),
                                                                    ),
                                                                    const SizedBox(height: 4),
                                                                    Text(
                                                                      student['email'] ?? '',
                                                                      style: TextStyle(
                                                                        fontSize: 14,
                                                                        color: Colors.grey[600],
                                                                      ),
                                                                    ),
                                                                    const SizedBox(height: 4),
                                                                    Text(
                                                                      'Department: ${student['department'] ?? 'N/A'}',
                                                                      style: TextStyle(
                                                                        fontSize: 12,
                                                                        color: Colors.grey[500],
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),

                                                              // Conversation Count
                                                              Container(
                                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                                decoration: BoxDecoration(
                                                                  color: Colors.orange.shade100,
                                                                  borderRadius: BorderRadius.circular(20),
                                                                ),
                                                                child: Row(
                                                                  children: [
                                                                    Icon(
                                                                      Icons.chat_bubble_outline,
                                                                      size: 16,
                                                                      color: Colors.orange.shade700,
                                                                    ),
                                                                    const SizedBox(width: 4),
                                                                    Text(
                                                                      '${student['conversationCount'] ?? 0}',
                                                                      style: TextStyle(
                                                                        fontSize: 14,
                                                                        fontWeight: FontWeight.w600,
                                                                        color: Colors.orange.shade700,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),

                                                              const SizedBox(width: 8),

                                                              // Arrow Icon
                                                              Icon(
                                                                Icons.arrow_forward_ios,
                                                                color: Colors.grey[400],
                                                                size: 16,
                                                              ),
                                                            ],
                                                          ),
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
