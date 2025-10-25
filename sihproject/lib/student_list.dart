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
  List<Map<String, dynamic>> _filteredStudents = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _headerController;
  late AnimationController _searchAnimationController;
  late AnimationController _refreshController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _headerAnimation;
  late Animation<double> _searchAnimation;
  late Animation<double> _refreshAnimation;

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

    _headerController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _searchAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _refreshController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    // Initialize animations
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    _headerAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _headerController, curve: Curves.elasticOut),
    );

    _searchAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _searchAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _refreshAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _refreshController, curve: Curves.easeInOut),
    );

    // Load students
    _loadStudents();
  }

  Future<void> _loadStudents() async {
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

        // Get screening status for this student
        final screeningQuery = await FirebaseFirestore.instance
            .collection('screenings')
            .where('studentId', isEqualTo: doc.id)
            .orderBy('timestamp', descending: true)
            .limit(1)
            .get();

        if (screeningQuery.docs.isNotEmpty) {
          final screeningData = screeningQuery.docs.first.data();
          studentData['screeningStatus'] = screeningData['status'] ?? 'pending';
          studentData['screeningScore'] = screeningData['totalScore'] ?? 0;
          studentData['lastScreeningDate'] = screeningData['timestamp'];
        } else {
          studentData['screeningStatus'] = 'not_started';
          studentData['screeningScore'] = 0;
          studentData['lastScreeningDate'] = null;
        }

        students.add(studentData);
      }

      // Sort students by conversation count (descending)
      students.sort(
        (a, b) => (b['conversationCount'] ?? 0).compareTo(
          a['conversationCount'] ?? 0,
        ),
      );

      setState(() {
        _students = students;
        _filteredStudents = students;
        _isLoading = false;
      });

      // Start header animation after loading
      Future.delayed(const Duration(milliseconds: 500), () {
        _headerController.forward();
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load students: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _filterStudents(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredStudents = _students;
      } else {
        _filteredStudents = _students.where((student) {
          final name = (student['name'] ?? '').toString().toLowerCase();
          final email = (student['email'] ?? '').toString().toLowerCase();
          final department = (student['department'] ?? '')
              .toString()
              .toLowerCase();
          final searchQuery = query.toLowerCase();

          return name.contains(searchQuery) ||
              email.contains(searchQuery) ||
              department.contains(searchQuery);
        }).toList();
      }
    });
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
    });

    if (_isSearching) {
      _searchAnimationController.forward();
    } else {
      _searchAnimationController.reverse();
      _searchController.text = '';
      _filterStudents('');
    }
  }

  Future<void> _refreshData() async {
    _refreshController.forward();
    await _loadStudents();
    _refreshController.reverse();
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
                  scale: value.clamp(0.0, 1.0),
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
                      Icons.supervisor_account,
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
                        'Loading Your Students...',
                        style: TextStyle(
                          color: Colors.teal[700],
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Connecting you with your mentees',
                        style: TextStyle(
                          color: Colors.teal[600]?.withOpacity(0.8),
                          fontSize: 14,
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
                        Icons.school,
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
                            _mentorCollege ?? 'Your College',
                            style: TextStyle(
                              color: Colors.teal[700],
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${_filteredStudents.length} student${_filteredStudents.length == 1 ? '' : 's'} found',
                            style: TextStyle(
                              color: Colors.teal[600]?.withOpacity(0.8),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedBuilder(
                      animation: _refreshAnimation,
                      builder: (context, child) {
                        return Transform.rotate(
                          angle: _refreshAnimation.value * 2 * 3.14159,
                          child: IconButton(
                            onPressed: _refreshData,
                            icon: Icon(
                              Icons.refresh,
                              color: Colors.teal[600],
                              size: 24,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Connect with your students and track their mental health journey.',
                  style: TextStyle(
                    color: Colors.teal[600],
                    fontSize: 16,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return AnimatedBuilder(
      animation: _searchAnimation,
      builder: (context, child) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          height: _isSearching ? 60 : 0,
          margin: EdgeInsets.symmetric(
            horizontal: 20,
            vertical: _isSearching ? 10 : 0,
          ),
          child: Opacity(
            opacity: _searchAnimation.value,
            child: TextField(
              controller: _searchController,
              onChanged: _filterStudents,
              style: TextStyle(color: Colors.teal[700]),
              decoration: InputDecoration(
                hintText: 'Search students by name, email, or department...',
                hintStyle: TextStyle(color: Colors.teal[500]?.withOpacity(0.7)),
                prefixIcon: Icon(Icons.search, color: Colors.teal[600]),
                filled: true,
                fillColor: Colors.white.withOpacity(0.9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(color: Colors.teal[200]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(color: Colors.teal[400]!, width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(color: Colors.teal[200]!),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student, int index) {
    final colors = [
      [Colors.blue.shade400, Colors.blue.shade600],
      [Colors.green.shade400, Colors.green.shade600],
      [Colors.purple.shade400, Colors.purple.shade600],
      [Colors.teal.shade400, Colors.teal.shade600],
      [Colors.pink.shade400, Colors.pink.shade600],
    ];

    final colorPair = colors[index % colors.length];
    final conversationCount = student['conversationCount'] ?? 0;

    return TweenAnimationBuilder(
      key: ValueKey(student['id']),
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 600 + (index * 100)),
      curve: Curves.easeOutBack,
      builder: (context, double value, child) {
        return Transform.translate(
          offset: Offset(50 * (1 - value), 0),
          child: Transform.scale(
            scale: value.clamp(0.0, 1.0),
            child: Opacity(
              opacity: value.clamp(0.0, 1.0),
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder:
                              (context, animation, secondaryAnimation) =>
                                  StudentConversationsPage(
                                    studentId: student['id'],
                                    studentName: student['name'],
                                    studentEmail: student['email'],
                                  ),
                          transitionsBuilder:
                              (context, animation, secondaryAnimation, child) {
                                return SlideTransition(
                                  position:
                                      Tween<Offset>(
                                        begin: const Offset(1.0, 0.0),
                                        end: Offset.zero,
                                      ).animate(
                                        CurvedAnimation(
                                          parent: animation,
                                          curve: Curves.easeInOut,
                                        ),
                                      ),
                                  child: FadeTransition(
                                    opacity: animation,
                                    child: child,
                                  ),
                                );
                              },
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: colorPair[0].withOpacity(0.1),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colorPair[0].withOpacity(0.15),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Enhanced Avatar
                          Hero(
                            tag: 'avatar_${student['id']}',
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: colorPair,
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: [
                                  BoxShadow(
                                    color: colorPair[1].withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Stack(
                                children: [
                                  Center(
                                    child: Text(
                                      (student['name'] as String)
                                          .substring(0, 1)
                                          .toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  if (conversationCount > 0)
                                    Positioned(
                                      top: 0,
                                      right: 0,
                                      child: Container(
                                        width: 20,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          color: Colors.green,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 2,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.chat,
                                          color: Colors.white,
                                          size: 10,
                                        ),
                                      ),
                                    ),
                                ],
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
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.email_outlined,
                                      size: 14,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        student['email'] ?? '',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.business_outlined,
                                      size: 14,
                                      color: Colors.grey[500],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      student['department'] ?? 'N/A',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[500],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                if (student['rollNumber'] != null) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.badge_outlined,
                                        size: 14,
                                        color: Colors.grey[500],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        student['rollNumber'],
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[500],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),

                          // Stats Column
                          SizedBox(
                            width: 100,
                            child: Column(
                              children: [
                                // Conversation Stats
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: conversationCount > 0
                                          ? [
                                              Colors.green.shade400,
                                              Colors.green.shade600,
                                            ]
                                          : [
                                              Colors.grey.shade300,
                                              Colors.grey.shade400,
                                            ],
                                    ),
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.chat_bubble_outline,
                                        size: 12,
                                        color: conversationCount > 0
                                            ? Colors.white
                                            : Colors.grey[600],
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        '$conversationCount',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: conversationCount > 0
                                              ? Colors.white
                                              : Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                // Screening Status
                                _buildScreeningStatusBadge(student),
                                const SizedBox(height: 6),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  color: Colors.grey[400],
                                  size: 16,
                                ),
                              ],
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

  Widget _buildScreeningStatusBadge(Map<String, dynamic> student) {
    final status = student['screeningStatus'] ?? 'not_started';
    final score = student['screeningScore'] ?? 0;

    IconData icon;
    List<Color> colors;
    String text;

    switch (status) {
      case 'completed':
        if (score >= 20) {
          // High risk
          icon = Icons.warning;
          colors = [Colors.red.shade400, Colors.red.shade600];
          text = 'High Risk';
        } else if (score >= 10) {
          // Moderate risk
          icon = Icons.warning_amber;
          colors = [Colors.orange.shade400, Colors.orange.shade600];
          text = 'Moderate';
        } else {
          // Low risk
          icon = Icons.check_circle;
          colors = [Colors.green.shade400, Colors.green.shade600];
          text = 'Low Risk';
        }
        break;
      case 'in_progress':
        icon = Icons.hourglass_top;
        colors = [Colors.blue.shade400, Colors.blue.shade600];
        text = 'In Progress';
        break;
      case 'pending':
        icon = Icons.schedule;
        colors = [Colors.grey.shade400, Colors.grey.shade600];
        text = 'Pending';
        break;
      default:
        // not_started
        icon = Icons.assignment;
        colors = [Colors.grey.shade300, Colors.grey.shade400];
        text = 'Not Started';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: Colors.white,
          ),
          const SizedBox(width: 2),
          Text(
            text,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
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
            opacity: value.clamp(0.0, 1.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Transform.scale(
                  scale: value.clamp(0.0, 1.0),
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
                  'No Students Found',
                  style: TextStyle(
                    color: Colors.teal[700],
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _isSearching && _searchController.text.isNotEmpty
                      ? 'No students match your search criteria'
                      : 'No students from ${_mentorCollege ?? 'your college'} have registered yet.',
                  style: TextStyle(
                    color: Colors.teal[600]?.withOpacity(0.8),
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () {
                    if (_isSearching) {
                      _searchController.text = '';
                      _filterStudents('');
                    } else {
                      _refreshData();
                    }
                  },
                  icon: Icon(_isSearching ? Icons.clear : Icons.refresh),
                  label: Text(_isSearching ? 'Clear Search' : 'Refresh'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal[400],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
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
    _fadeController.dispose();
    _slideController.dispose();
    _headerController.dispose();
    _searchAnimationController.dispose();
    _refreshController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'My Students',
          style: TextStyle(
            fontWeight: FontWeight.bold, 
            color: Colors.teal[700],
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.teal[700]),
        actions: [
          IconButton(
            icon: Icon(
              _isSearching ? Icons.close : Icons.search,
              color: Colors.teal[600],
            ),
            onPressed: _toggleSearch,
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
                      Color(0xFFF8FFFE), // Very light mint (almost white)
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
                                  onPressed: _refreshData,
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
                      : Column(
                          children: [
                            // Header
                            _buildHeader(),

                            // Search Bar
                            _buildSearchBar(),

                            // Students List or Empty State
                            Expanded(
                              child: _filteredStudents.isEmpty
                                  ? _buildEmptyState()
                                  : ListView.builder(
                                      padding: const EdgeInsets.all(20),
                                      itemCount: _filteredStudents.length,
                                      itemBuilder: (context, index) {
                                        return _buildStudentCard(
                                          _filteredStudents[index],
                                          index,
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
