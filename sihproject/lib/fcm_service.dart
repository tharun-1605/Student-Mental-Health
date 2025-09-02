import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  Future<void> initialize() async {
    // Request permission for push notifications
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      print('User granted provisional permission');
    } else {
      print('User declined or has not accepted permission');
    }

    // Get and store FCM token
    await _getAndStoreToken();

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      print('Message data: ${message.data}');

      if (message.notification != null) {
        print('Message also contained a notification: ${message.notification}');
      }
    });

    // Handle notification tap when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Message clicked!');
      _handleNotificationTap(message);
    });
  }

  Future<void> _getAndStoreToken() async {
    try {
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        await _storeToken(token);
      }

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        _storeToken(newToken);
      });
    } catch (e) {
      print('Error getting FCM token: $e');
    }
  }

  Future<void> _storeToken(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Check if user is student
      final studentDoc = await FirebaseFirestore.instance
          .collection('students')
          .doc(user.uid)
          .get();

      if (studentDoc.exists) {
        await FirebaseFirestore.instance
            .collection('students')
            .doc(user.uid)
            .update({'fcmToken': token});
        print('FCM token stored for student');
      } else {
        // Check if user is mentor
        final mentorDoc = await FirebaseFirestore.instance
            .collection('mentors')
            .doc(user.uid)
            .get();

        if (mentorDoc.exists) {
          await FirebaseFirestore.instance
              .collection('mentors')
              .doc(user.uid)
              .update({'fcmToken': token});
          print('FCM token stored for mentor');
        }
      }
    } catch (e) {
      print('Error storing FCM token: $e');
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    // Handle navigation based on notification type
    final data = message.data;
    if (data.containsKey('type')) {
      switch (data['type']) {
        case 'login':
          // Navigate to home page
          break;
        case 'booking_request':
          // Navigate to booking management page
          break;
        case 'booking_approved':
          // Navigate to bookings page
          break;
        case 'mentor_message':
          // Navigate to notifications page
          break;
      }
    }
  }

  Future<void> sendLoginNotification() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Get user data
      final studentDoc = await FirebaseFirestore.instance
          .collection('students')
          .doc(user.uid)
          .get();

      String userName;
      String userType;
      String college;

      if (studentDoc.exists) {
        final data = studentDoc.data()!;
        userName = data['name'] ?? 'Student';
        userType = 'Student';
        college = data['college'] ?? '';
      } else {
        final mentorDoc = await FirebaseFirestore.instance
            .collection('mentors')
            .doc(user.uid)
            .get();

        if (mentorDoc.exists) {
          final data = mentorDoc.data()!;
          userName = data['name'] ?? 'Mentor';
          userType = 'Mentor';
          college = data['college'] ?? '';
        } else {
          return;
        }
      }

      // Store login event in Firestore to trigger Cloud Function
      await FirebaseFirestore.instance.collection('login_events').add({
        'userId': user.uid,
        'userName': userName,
        'userType': userType,
        'college': college,
        'timestamp': FieldValue.serverTimestamp(),
        'deviceInfo': 'Mobile App',
      });

      print('Login notification event created');
    } catch (e) {
      print('Error sending login notification: $e');
    }
  }

  Future<void> sendBookingRequestNotification(String mentorName, String studentName, String bookingId) async {
    try {
      // Store booking request event in Firestore to trigger Cloud Function
      await FirebaseFirestore.instance.collection('booking_request_events').add({
        'mentorName': mentorName,
        'studentName': studentName,
        'bookingId': bookingId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      print('Booking request notification event created');
    } catch (e) {
      print('Error sending booking request notification: $e');
    }
  }

  Future<void> sendBookingApprovalNotification(String studentId, String mentorName, String bookingId) async {
    try {
      // Store booking approval event in Firestore to trigger Cloud Function
      await FirebaseFirestore.instance.collection('booking_approval_events').add({
        'studentId': studentId,
        'mentorName': mentorName,
        'bookingId': bookingId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      print('Booking approval notification event created');
    } catch (e) {
      print('Error sending booking approval notification: $e');
    }
  }
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Handling a background message: ${message.messageId}');
}
