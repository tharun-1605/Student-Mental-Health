import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'services/stress_monitoring_service.dart';
import 'services/wearable_service.dart';

import 'services/health_data_service.dart';
import '../models/wearable_device.dart';
import '../models/health_data.dart';

class StressMonitoringDashboard extends StatefulWidget {
  const StressMonitoringDashboard({super.key});

  @override
  _StressMonitoringDashboardState createState() =>
      _StressMonitoringDashboardState();
}

class _StressMonitoringDashboardState extends State<StressMonitoringDashboard> {
  final StressMonitoringService _stressService = StressMonitoringService();
  final WearableService _wearableService = WearableService();
  final HealthDataService _healthService = HealthDataService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isMonitoring = false;
  StressLevel _currentStressLevel = StressLevel.low;
  final Map<String, dynamic> _stressSummary = {};
  List<StressAlert> _recentAlerts = [];

  ConnectionStatus _connectionStatus = ConnectionStatus.disconnected;
  List<WearableDeviceInfo> _discoveredDevices = [];
  StreamSubscription? _connectionStatusSubscription;
  StreamSubscription? _discoveredDevicesSubscription;

  // Health data
  List<HealthDataPoint> _heartRateData = [];
  List<HealthDataPoint> _stepData = [];
  List<HealthDataPoint> _sleepData = [];
  bool _isLoadingHealthData = false;
  Map<String, dynamic> _healthSummary = {};
  int _currentHeartRate = 0;
  StreamSubscription? _heartRateSubscription;
  StreamSubscription? _oxygenSubscription;
  StreamSubscription? _stressSubscription;
  StreamSubscription? _stepsSubscription;

  int _currentOxygen = 0;
  int _currentStress = 0;
  int _currentSteps = 0;

  @override
  void initState() {
    super.initState();
    _checkConnectionStatus();
    _listenToConnectionStatus();
    _listenToDiscoveredDevices();
    _listenToHeartRate();
    _listenToOxygen();
    _listenToStress();
    _listenToSteps();
  }

  @override
  void dispose() {
    _stressService.dispose();
    _connectionStatusSubscription?.cancel();
    _discoveredDevicesSubscription?.cancel();
    _heartRateSubscription?.cancel();
    _oxygenSubscription?.cancel();
    _stressSubscription?.cancel();
    _stepsSubscription?.cancel();
    super.dispose();
  }

  void _checkConnectionStatus() async {
    // Check if Health Connect permissions are granted
    final healthAuthorized = await _healthService.isAuthorized();
    if (healthAuthorized) {
      setState(() {
        _connectionStatus = ConnectionStatus.connected;
      });
      _loadStressData();
      _loadHealthData();
      _listenToStressUpdates();
      _wearableService.startHeartRateMonitoring();
      _wearableService.startOxygenMonitoring();
      _wearableService.startStressMonitoring();
      _wearableService.startStepsMonitoring();
    } else {
      setState(() {
        _connectionStatus = ConnectionStatus.disconnected;
      });
    }
  }

  void _listenToConnectionStatus() {
    _connectionStatusSubscription = _wearableService.connectionStatus.listen((status) {
      setState(() {
        _connectionStatus = status;
      });
      if (status == ConnectionStatus.connected) {
        _loadStressData();
        _loadHealthData();
        _listenToStressUpdates();
        _wearableService.startHeartRateMonitoring();
        _wearableService.startOxygenMonitoring();
        _wearableService.startStressMonitoring();
        _wearableService.startStepsMonitoring();
      }
    });
  }

  void _listenToDiscoveredDevices() {
    _discoveredDevicesSubscription = _wearableService.discoveredDevices.listen((devices) {
      print('Dashboard: Received discovered devices: ${devices.length}');
      for (var device in devices) {
        print('Dashboard: Device: ${device.name} (${device.id})');
      }
      setState(() {
        _discoveredDevices = devices;
      });
    });
  }

  void _listenToStressUpdates() {
    _stressService.currentStressLevel.listen((stressLevel) {
      setState(() {
        _currentStressLevel = stressLevel;
      });
    });

    _stressService.stressAlerts.listen((alert) {
      setState(() {
        _recentAlerts.insert(0, alert);
        if (_recentAlerts.length > 10) {
          _recentAlerts = _recentAlerts.sublist(0, 10);
        }
      });
    });
  }

  void _listenToHeartRate() {
    _heartRateSubscription?.cancel();
    _heartRateSubscription = _wearableService.heartRate.listen((hr) async {
      setState(() {
        _currentHeartRate = hr;
        _healthSummary['heartRate'] = hr;
      });
      // Store heart rate data in Firebase
      await _storeHeartRateData(hr);
    });
  }

  void _listenToOxygen() {
    _oxygenSubscription?.cancel();
    _oxygenSubscription = _wearableService.oxygen.listen((oxygen) async {
      setState(() {
        _currentOxygen = oxygen;
        _healthSummary['oxygen'] = oxygen;
      });
    });
  }

  void _listenToStress() {
    _stressSubscription?.cancel();
    _stressSubscription = _wearableService.stress.listen((stress) async {
      setState(() {
        _currentStress = stress;
        _healthSummary['stress'] = stress;
      });
    });
  }

  void _listenToSteps() {
    _stepsSubscription?.cancel();
    _stepsSubscription = _wearableService.steps.listen((steps) async {
      setState(() {
        _currentSteps = steps;
        _healthSummary['steps'] = steps;
      });
    });
  }

  Future<void> _storeHeartRateData(int hr) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('heart_rate').add({
          'heartRate': hr,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error storing heart rate data: $e');
    }
  }

  Future<void> _loadStressData() async {
    // final summary = await _stressService.getStressSummary();
    // final alerts = await _stressService.getStressAlerts(
    //   startDate: DateTime.now().subtract(const Duration(days: 1)),
    // );

    // setState(() {
    //   _stressSummary = summary;
    //   _recentAlerts = alerts;
    // });
  }

  Future<void> _loadHealthData() async {
    setState(() {
      _isLoadingHealthData = true;
    });

    try {
      final heartRateData = await _healthService.getHeartRateData();
      final stepData = await _healthService.getStepData();
      final sleepData = await _healthService.getSleepData();
      final summary = await _healthService.getHealthSummary();

      setState(() {
        _heartRateData = heartRateData;
        _stepData = stepData;
        _sleepData = sleepData;
        _healthSummary = summary;
        _isLoadingHealthData = false;
      });
    } catch (e) {
      print('Error loading health data: $e');
      setState(() {
        _isLoadingHealthData = false;
      });
    }
  }

  Future<void> _toggleMonitoring() async {
    setState(() {
      _isMonitoring = !_isMonitoring;
    });

    if (_isMonitoring) {
      await _stressService.startMonitoring();
    } else {
      await _stressService.stopMonitoring();
    }
  }

  Future<void> _refreshHeartRateMonitoring() async {
    try {
      await _wearableService.startHeartRateMonitoring();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Heart rate monitoring refreshed')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to refresh heart rate monitoring: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stress Monitoring'),
        backgroundColor: Theme.of(context).primaryColor,
        actions: [
          if (_connectionStatus == ConnectionStatus.connected) ...[
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refreshHeartRateMonitoring,
              tooltip: 'Refresh Heart Rate Monitoring',
            ),
            IconButton(
              icon: Icon(_isMonitoring ? Icons.stop : Icons.play_arrow),
              onPressed: _toggleMonitoring,
              tooltip: _isMonitoring ? 'Stop Monitoring' : 'Start Monitoring',
            ),
          ],
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (_connectionStatus) {
      case ConnectionStatus.connected:
        return _buildDashboard();
      case ConnectionStatus.connecting:
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Connecting to device...'),
            ],
          ),
        );
      case ConnectionStatus.disconnected:
      case ConnectionStatus.error:
        return _buildDeviceDiscovery();
    }
  }

  Widget _buildDeviceDiscovery() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          const Text(
            'No wearable device connected.',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'This app scans for Bluetooth Low Energy (BLE) devices only. Ensure your wearable device supports BLE and is in pairing mode.',
            style: TextStyle(fontSize: 14, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'If your wearable is connected to another app (like Boat Crest), please disconnect it first in that app\'s settings.',
            style: TextStyle(fontSize: 14, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () async {
              try {
                await _wearableService.startScan();
              } catch (e) {
                print('Dashboard: Error during scan: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Scan failed: $e')),
                );
              }
            },
            child: const Text('Scan for Devices'),
          ),
          const SizedBox(height: 16),
          if (_discoveredDevices.isEmpty)
            const Center(
              child: Text(
                'No devices found. Tap "Scan for Devices" to search.',
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _discoveredDevices.length,
                itemBuilder: (context, index) {
                  final device = _discoveredDevices[index];
                  return ListTile(
                    title: Text(device.name),
                    subtitle: Text(device.id),
                    onTap: () => _wearableService.connectToDevice(device),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Connection Status Card
          Card(
            elevation: 4,
            color: Colors.green[50],
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(
                    Icons.bluetooth_connected,
                    color: Colors.green,
                    size: 32,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Device Connected',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[800],
                          ),
                        ),
                        const Text(
                          'Wearable device is successfully connected and monitoring.',
                          style: TextStyle(color: Colors.green),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Current Stress Level Card
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        _getStressLevelIcon(_currentStressLevel),
                        size: 48,
                        color: _getStressLevelColor(_currentStressLevel),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Current Stress Level',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              _getStressLevelText(_currentStressLevel),
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: _getStressLevelColor(_currentStressLevel),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: _getStressLevelProgress(_currentStressLevel),
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _getStressLevelColor(_currentStressLevel),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Health Data Card
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _isLoadingHealthData
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Health Data Summary',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 16),
                        Text('Heart Rate: ${_healthSummary['heartRate'] ?? 'N/A'} bpm'),
                        Text('Oxygen: ${_healthSummary['oxygen'] ?? 'N/A'} %'),
                        Text('Stress: ${_healthSummary['stress'] ?? 'N/A'}'),
                        Text('Steps: ${_healthSummary['steps'] ?? 'N/A'}'),
                        Text('Sleep: ${_healthSummary['sleep'] ?? 'N/A'} hours'),
                      ],
                    ),
            ),
          ),

          const SizedBox(height: 24),

          // Recent Alerts
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.notifications_active),
                      const SizedBox(width: 8),
                      Text(
                        'Recent Alerts',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_recentAlerts.isEmpty)
                    const Center(
                      child: Text('No recent alerts'),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _recentAlerts.length > 5 ? 5 : _recentAlerts.length,
                      itemBuilder: (context, index) {
                        final alert = _recentAlerts[index];
                        return ListTile(
                          leading: Icon(
                            alert.requiresImmediateAttention
                                ? Icons.warning
                                : Icons.info_outline,
                            color: _getStressLevelColor(alert.level),
                          ),
                          title: Text(
                            alert.message,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            DateFormat('MMM dd, HH:mm').format(alert.timestamp),
                            style: TextStyle(
                              color: _getStressLevelColor(alert.level),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          trailing: Chip(
                            label: Text(_getStressLevelText(alert.level)),
                            backgroundColor: _getStressLevelColor(alert.level).withOpacity(0.2),
                            labelStyle: TextStyle(
                              color: _getStressLevelColor(alert.level),
                              fontSize: 12,
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStressLevelColor(StressLevel level) {
    switch (level) {
      case StressLevel.low:
        return Colors.green;
      case StressLevel.moderate:
        return Colors.yellow;
      case StressLevel.high:
        return Colors.orange;
      case StressLevel.critical:
        return Colors.red;
    }
    // Default color if none matched
    return Colors.grey;
  }

  String _getStressLevelText(StressLevel level) {
    switch (level) {
      case StressLevel.low:
        return 'Low';
      case StressLevel.moderate:
        return 'Moderate';
      case StressLevel.high:
        return 'High';
      case StressLevel.critical:
        return 'Critical';
    }
    // Default text if none matched
    return 'Unknown';
  }

  IconData _getStressLevelIcon(StressLevel level) {
    switch (level) {
      case StressLevel.low:
        return Icons.sentiment_satisfied;
      case StressLevel.moderate:
        return Icons.sentiment_neutral;
      case StressLevel.high:
        return Icons.sentiment_dissatisfied;
      case StressLevel.critical:
        return Icons.sentiment_very_dissatisfied;
    }
    // Default icon if none matched
    return Icons.sentiment_neutral;
  }

  double _getStressLevelProgress(StressLevel level) {
    switch (level) {
      case StressLevel.low:
        return 0.25;
      case StressLevel.moderate:
        return 0.5;
      case StressLevel.high:
        return 0.75;
      case StressLevel.critical:
        return 1.0;
    }
    // Default progress if none matched
    return 0.0;
  }
}