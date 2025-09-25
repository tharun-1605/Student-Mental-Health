import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/wearable_device.dart';
import 'wearable_service.dart';
import '../models/health_data.dart';

class StressAlert {
  final String id;
  final DateTime timestamp;
  final StressLevel level;
  final String message;
  final Map<String, dynamic> data;
  final bool requiresImmediateAttention;

  StressAlert({
    required this.id,
    required this.timestamp,
    required this.level,
    required this.message,
    required this.data,
    this.requiresImmediateAttention = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'timestamp': Timestamp.fromDate(timestamp),
      'level': level.toString(),
      'message': message,
      'data': data,
      'requiresImmediateAttention': requiresImmediateAttention,
    };
  }
}

class StressMonitoringService {
  static final StressMonitoringService _instance =
      StressMonitoringService._internal();
  factory StressMonitoringService() => _instance;

  StressMonitoringService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final WearableService _wearableService = WearableService();

  StreamSubscription? _heartRateSubscription;
  Timer? _alertCheckTimer;

  final StreamController<StressAlert> _stressAlertsController =
      StreamController.broadcast();
  final StreamController<StressLevel> _currentStressLevelController =
      StreamController.broadcast();

  Stream<StressAlert> get stressAlerts => _stressAlertsController.stream;
  Stream<StressLevel> get currentStressLevel =>
      _currentStressLevelController.stream;

  // Stress monitoring parameters
  static const Duration _alertCheckInterval = Duration(minutes: 1);
  static const int _heartRateThreshold = 100; // BPM

  // Historical data for stress analysis
  final List<int> _recentHeartRateData = [];

  Future<void> startMonitoring() async {
    if (!await _wearableService.isDeviceConnected()) {
      throw Exception('No wearable device connected');
    }

    // Stop existing monitoring
    stopMonitoring();

    // Start listening to heart rate
    await _wearableService.startHeartRateMonitoring();
    _heartRateSubscription = _wearableService.heartRate.listen((heartRate) {
      _recentHeartRateData.add(heartRate);
      // Keep only the last 10 minutes of data
      if (_recentHeartRateData.length > 600) {
        _recentHeartRateData.removeAt(0);
      }
    });

    // Start alert checking
    _alertCheckTimer = Timer.periodic(_alertCheckInterval, (timer) async {
      await _checkForStressAlerts();
    });
  }

  Future<void> stopMonitoring() async {
    _alertCheckTimer?.cancel();
    _heartRateSubscription?.cancel();
  }

  Future<StressLevel> _calculateStressLevel() async {
    if (_recentHeartRateData.isEmpty) {
      return StressLevel.low;
    }

    final avgHeartRate =
        _recentHeartRateData.reduce((a, b) => a + b) / _recentHeartRateData.length;

    if (avgHeartRate > _heartRateThreshold) {
      return StressLevel.high;
    }

    return StressLevel.low;
  }

  Future<void> _checkForStressAlerts() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final currentStressLevel = await _calculateStressLevel();

      // Update current stress level
      _currentStressLevelController.add(currentStressLevel);

      // Check for critical stress conditions
      if (currentStressLevel == StressLevel.high) {
        await _generateStressAlert(
          StressLevel.high,
          'High stress level detected. Consider stress management techniques.',
          {
            'heartRate': _recentHeartRateData.isNotEmpty
                ? _recentHeartRateData.last
                : 0,
            'recommendations': [
              'Practice breathing exercises',
              'Take a break from work',
              'Engage in light physical activity',
            ],
          },
        );
      }
    } catch (e) {
      print('Error checking for stress alerts: $e');
    }
  }

  Future<void> _generateStressAlert(
    StressLevel level,
    String message,
    Map<String, dynamic> data, {
    bool requiresImmediateAttention = false,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final alert = StressAlert(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      level: level,
      message: message,
      data: data,
      requiresImmediateAttention: requiresImmediateAttention,
    );

    // Add to stream
    _stressAlertsController.add(alert);

    // Store in Firestore
    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('stress_alerts')
        .add(alert.toMap());
  }

  void dispose() {
    _alertCheckTimer?.cancel();
    _heartRateSubscription?.cancel();
    _stressAlertsController.close();
    _currentStressLevelController.close();
  }
}