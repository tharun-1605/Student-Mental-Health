import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'questionnaire_data.dart';

class ScreeningService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Save screening result to Firestore
  Future<void> saveScreeningResult({
    required QuestionnaireType type,
    required List<int> scores,
    required ScoringResult result,
    required String mentorId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final screeningData = {
      'studentId': user.uid,
      'mentorId': mentorId,
      'questionnaireType': type.toString().split('.').last,
      'scores': scores.asMap().map((key, value) => MapEntry('q${key + 1}', value)),
      'totalScore': result.totalScore,
      'severity': result.severity.toString().split('.').last,
      'severityDescription': result.severityDescription,
      'recommendation': result.recommendation,
      'timestamp': FieldValue.serverTimestamp(),
      'completedAt': FieldValue.serverTimestamp(),
    };

    // Save to screenings collection
    await _firestore.collection('screenings').add(screeningData);

    // Update student's last screening info
    await _firestore.collection('students').doc(user.uid).update({
      'lastScreeningDate': FieldValue.serverTimestamp(),
      'screeningStatus': 'completed',
    });
  }

  // Get screening history for current student
  Future<List<Map<String, dynamic>>> getScreeningHistory() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final querySnapshot = await _firestore
        .collection('screenings')
        .where('studentId', isEqualTo: user.uid)
        .orderBy('timestamp', descending: true)
        .get();

    return querySnapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  // Get screening history for a specific student (for mentors)
  Future<List<Map<String, dynamic>>> getStudentScreeningHistory(String studentId) async {
    final querySnapshot = await _firestore
        .collection('screenings')
        .where('studentId', isEqualTo: studentId)
        .orderBy('timestamp', descending: true)
        .get();

    return querySnapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  // Get latest screening for a student
  Future<Map<String, dynamic>?> getLatestScreening(String studentId) async {
    final querySnapshot = await _firestore
        .collection('screenings')
        .where('studentId', isEqualTo: studentId)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) return null;

    final data = querySnapshot.docs.first.data();
    data['id'] = querySnapshot.docs.first.id;
    return data;
  }

  // Get screening statistics for a student
  Future<Map<String, dynamic>> getScreeningStats(String studentId) async {
    final history = await getStudentScreeningHistory(studentId);

    if (history.isEmpty) {
      return {
        'totalScreenings': 0,
        'averageScore': 0,
        'lastScreeningDate': null,
        'severityTrend': [],
      };
    }

    // Calculate average score
    double totalScore = 0;
    List<String> severities = [];

    for (var screening in history) {
      totalScore += (screening['totalScore'] ?? 0).toDouble();
      severities.add(screening['severity'] ?? 'unknown');
    }

    return {
      'totalScreenings': history.length,
      'averageScore': totalScore / history.length,
      'lastScreeningDate': history.first['timestamp'],
      'severityTrend': severities,
    };
  }

  // Get mentor ID for current student
  Future<String?> getMentorIdForStudent() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final studentDoc = await _firestore.collection('students').doc(user.uid).get();
    if (!studentDoc.exists) return null;

    final studentData = studentDoc.data();
    final college = studentData?['college'];

    if (college == null) return null;

    // Find mentor for this college
    final mentorQuery = await _firestore
        .collection('mentors')
        .where('college', isEqualTo: college)
        .limit(1)
        .get();

    if (mentorQuery.docs.isEmpty) return null;

    return mentorQuery.docs.first.id;
  }

  // Check if student needs screening reminder
  Future<bool> shouldRemindForScreening() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final studentDoc = await _firestore.collection('students').doc(user.uid).get();
    if (!studentDoc.exists) return true;

    final data = studentDoc.data();
    final lastScreeningDate = data?['lastScreeningDate'] as Timestamp?;

    if (lastScreeningDate == null) return true;

    // Remind if more than 30 days have passed
    final daysSinceLastScreening = DateTime.now().difference(lastScreeningDate.toDate()).inDays;
    return daysSinceLastScreening > 30;
  }

  // Get students who need screening reminders (for mentors)
  Future<List<Map<String, dynamic>>> getStudentsNeedingReminders(String mentorId) async {
    // Get mentor's college
    final mentorDoc = await _firestore.collection('mentors').doc(mentorId).get();
    if (!mentorDoc.exists) return [];

    final college = mentorDoc.data()?['college'];
    if (college == null) return [];

    // Get all students from the college
    final studentsQuery = await _firestore
        .collection('students')
        .where('college', isEqualTo: college)
        .get();

    List<Map<String, dynamic>> studentsNeedingReminders = [];

    for (var studentDoc in studentsQuery.docs) {
      final studentData = studentDoc.data();
      final lastScreeningDate = studentData['lastScreeningDate'] as Timestamp?;

      bool needsReminder = false;
      if (lastScreeningDate == null) {
        needsReminder = true;
      } else {
        final daysSinceLastScreening = DateTime.now().difference(lastScreeningDate.toDate()).inDays;
        needsReminder = daysSinceLastScreening > 30;
      }

      if (needsReminder) {
        studentData['id'] = studentDoc.id;
        studentsNeedingReminders.add(studentData);
      }
    }

    return studentsNeedingReminders;
  }

  // Get screening summary for mentor dashboard
  Future<Map<String, dynamic>> getMentorScreeningSummary(String mentorId) async {
    // Get mentor's college
    final mentorDoc = await _firestore.collection('mentors').doc(mentorId).get();
    if (!mentorDoc.exists) {
      return {
        'totalStudents': 0,
        'screenedStudents': 0,
        'pendingScreenings': 0,
        'highRiskStudents': 0,
      };
    }

    final college = mentorDoc.data()?['college'];
    if (college == null) {
      return {
        'totalStudents': 0,
        'screenedStudents': 0,
        'pendingScreenings': 0,
        'highRiskStudents': 0,
      };
    }

    // Get all students from the college
    final studentsQuery = await _firestore
        .collection('students')
        .where('college', isEqualTo: college)
        .get();

    int totalStudents = studentsQuery.docs.length;
    int screenedStudents = 0;
    int pendingScreenings = 0;
    int highRiskStudents = 0;

    for (var studentDoc in studentsQuery.docs) {
      final studentData = studentDoc.data();
      final lastScreeningDate = studentData['lastScreeningDate'] as Timestamp?;

      if (lastScreeningDate != null) {
        screenedStudents++;
        final daysSinceLastScreening = DateTime.now().difference(lastScreeningDate.toDate()).inDays;
        if (daysSinceLastScreening > 30) {
          pendingScreenings++;
        }
      } else {
        pendingScreenings++;
      }

      // Check for high-risk screenings
      final latestScreening = await getLatestScreening(studentDoc.id);
      if (latestScreening != null) {
        final severity = latestScreening['severity'];
        if (severity == 'severe' || severity == 'moderatelySevere') {
          highRiskStudents++;
        }
      }
    }

    return {
      'totalStudents': totalStudents,
      'screenedStudents': screenedStudents,
      'pendingScreenings': pendingScreenings,
      'highRiskStudents': highRiskStudents,
    };
  }
}
