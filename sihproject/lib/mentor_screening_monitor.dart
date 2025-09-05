import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screening_service.dart';

class MentorScreeningMonitorPage extends StatefulWidget {
  const MentorScreeningMonitorPage({super.key});

  @override
  State<MentorScreeningMonitorPage> createState() => _MentorScreeningMonitorPageState();
}

class _MentorScreeningMonitorPageState extends State<MentorScreeningMonitorPage>
    with TickerProviderStateMixin {
  final ScreeningService _screeningService = ScreeningService();
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  String _mentorCollege = '';
  bool _isLoading = true;
  Map<String, dynamic> _summaryStats = {};

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _loadMentorData();
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
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
            _mentorCollege = mentorDoc.data()!['college'] ?? '';
          });
          await _loadSummaryStats();
        }
      }
    } catch (e) {
      print('Error loading mentor data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSummaryStats() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final stats = await _screeningService.getMentorScreeningSummary(user.uid);
        setState(() {
          _summaryStats = stats;
        });
      }
    } catch (e) {
      print('Error loading summary stats: $e');
    }
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      shadowColor: color.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
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
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentScreeningCard(Map<String, dynamic> studentData) {
    final lastScreeningDate = studentData['lastScreeningDate'] as Timestamp?;
    final screeningStatus = studentData['screeningStatus'] ?? 'pending';

    String statusText = 'No screening yet';
    Color statusColor = Colors.grey;
    IconData statusIcon = Icons.schedule;

    if (lastScreeningDate != null) {
      final daysSince = DateTime.now().difference(lastScreeningDate.toDate()).inDays;
      if (daysSince > 30) {
        statusText = 'Overdue ($daysSince days)';
        statusColor = Colors.red;
        statusIcon = Icons.warning;
      } else {
        statusText = 'Completed ($daysSince days ago)';
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
      }
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.1),
          child: Icon(statusIcon, color: statusColor, size: 24),
        ),
        title: Text(
          studentData['name'] ?? 'Unknown Student',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ID: ${studentData['id']?.substring(0, 8) ?? 'N/A'}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              statusText,
              style: TextStyle(
                fontSize: 14,
                color: statusColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.arrow_forward_ios, size: 20),
          onPressed: () => _navigateToStudentDetails(studentData),
        ),
      ),
    );
  }

  void _navigateToStudentDetails(Map<String, dynamic> studentData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StudentScreeningDetailsPage(
          studentData: studentData,
          mentorCollege: _mentorCollege,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Screening Monitor'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _isLoading = true;
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
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Text(
                          'College: $_mentorCollege',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Monitor student mental health screenings',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Summary Stats
                        if (_summaryStats.isNotEmpty) ...[
                          Text(
                            'Summary Statistics',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildSummaryCard(
                                  'Total Students',
                                  _summaryStats['totalStudents']?.toString() ?? '0',
                                  Icons.people,
                                  Colors.blue,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildSummaryCard(
                                  'Screened',
                                  _summaryStats['screenedStudents']?.toString() ?? '0',
                                  Icons.check_circle,
                                  Colors.green,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildSummaryCard(
                                  'Pending',
                                  _summaryStats['pendingScreenings']?.toString() ?? '0',
                                  Icons.schedule,
                                  Colors.orange,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildSummaryCard(
                                  'High Risk',
                                  _summaryStats['highRiskStudents']?.toString() ?? '0',
                                  Icons.warning,
                                  Colors.red,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                        ],

                        // Students List
                        Text(
                          'Student Screening Status',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 16),

                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('students')
                              .where('college', isEqualTo: _mentorCollege)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }

                            if (snapshot.hasError) {
                              return Center(
                                child: Text('Error loading students: ${snapshot.error}'),
                              );
                            }

                            final students = snapshot.data?.docs ?? [];

                            if (students.isEmpty) {
                              return const Center(
                                child: Text('No students found in your college.'),
                              );
                            }

                            return Column(
                              children: students.map((doc) {
                                final studentData = doc.data() as Map<String, dynamic>;
                                studentData['id'] = doc.id;
                                return _buildStudentScreeningCard(studentData);
                              }).toList(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
          );
        },
      ),
    );
  }
}

// Student Screening Details Page
class StudentScreeningDetailsPage extends StatefulWidget {
  final Map<String, dynamic> studentData;
  final String mentorCollege;

  const StudentScreeningDetailsPage({
    super.key,
    required this.studentData,
    required this.mentorCollege,
  });

  @override
  State<StudentScreeningDetailsPage> createState() => _StudentScreeningDetailsPageState();
}

class _StudentScreeningDetailsPageState extends State<StudentScreeningDetailsPage> {
  final ScreeningService _screeningService = ScreeningService();
  late Future<List<Map<String, dynamic>>> _screeningHistory;

  @override
  void initState() {
    super.initState();
    _screeningHistory = _screeningService.getStudentScreeningHistory(widget.studentData['id']);
  }

  Widget _buildScreeningHistoryCard(Map<String, dynamic> screening) {
    final timestamp = screening['timestamp'] as Timestamp?;
    final date = timestamp?.toDate();
    final formattedDate = date != null ? DateFormat.yMMMd().format(date) : 'Unknown date';

    final severity = screening['severity'] ?? 'unknown';
    final totalScore = screening['totalScore'] ?? 0;
    final questionnaireType = screening['questionnaireType'] ?? 'Unknown';

    Color severityColor;
    switch (severity.toLowerCase()) {
      case 'minimal':
      case 'mild':
        severityColor = Colors.green;
        break;
      case 'moderate':
      case 'moderatelysevere':
        severityColor = Colors.orange;
        break;
      case 'severe':
        severityColor = Colors.red;
        break;
      default:
        severityColor = Colors.grey;
    }

    return Card(
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$questionnaireType Assessment',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  formattedDate,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Score: $totalScore',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: severityColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    severity,
                    style: TextStyle(
                      fontSize: 12,
                      color: severityColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (screening['recommendation'] != null) ...[
              const SizedBox(height: 8),
              Text(
                screening['recommendation'],
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.studentData['name'] ?? 'Student'} Details'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Student Info
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.studentData['name'] ?? 'Unknown Student',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'College: ${widget.studentData['college'] ?? 'N/A'}',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Email: ${widget.studentData['email'] ?? 'N/A'}',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Screening History
            Text(
              'Screening History',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),

            FutureBuilder<List<Map<String, dynamic>>>(
              future: _screeningHistory,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error loading screening history: ${snapshot.error}'),
                  );
                }

                final history = snapshot.data ?? [];

                if (history.isEmpty) {
                  return const Center(
                    child: Text('No screening history available.'),
                  );
                }

                return Column(
                  children: history.map(_buildScreeningHistoryCard).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
