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

// Represents the user's choice of connection method
enum ConnectionChoice { none, googleFit, directBle }

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

  // State management
  ConnectionChoice _connectionChoice = ConnectionChoice.none;
  ConnectionStatus _connectionStatus = ConnectionStatus.disconnected;
  bool _isLoading = false;

  // Direct BLE properties
  List<WearableDeviceInfo> _discoveredDevices = [];
  StreamSubscription? _connectionStatusSubscription;
  StreamSubscription? _discoveredDevicesSubscription;

  // Data properties
  StressLevel _currentStressLevel = StressLevel.low;
  List<StressAlert> _recentAlerts = [];
  Map<String, dynamic> _healthSummary = {};
  int _currentHeartRate = 0;
  StreamSubscription? _heartRateSubscription;

  @override
  void initState() {
    super.initState();
    // Subscriptions are now activated based on user choice
  }

  @override
  void dispose() {
    _stressService.dispose();
    _connectionStatusSubscription?.cancel();
    _discoveredDevicesSubscription?.cancel();
    _heartRateSubscription?.cancel();
    super.dispose();
  }

  // --- NEW: Logic for Google Fit/Health Connect Flow ---
  Future<void> _syncWithGoogleFit() async {
    setState(() {
      _isLoading = true;
      _connectionChoice = ConnectionChoice.googleFit;
    });

    try {
      final permissionsGranted = await _healthService.requestPermissions();
      if (permissionsGranted) {
        await _loadHealthData();
        setState(() {
          _connectionStatus = ConnectionStatus.connected;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permissions denied. Cannot fetch health data.')),
        );
        setState(() {
          _connectionChoice = ConnectionChoice.none; // Go back to choice screen
        });
      }
    } catch (e) {
      print('Error syncing with Google Fit: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to sync: $e')),
      );
       setState(() {
          _connectionChoice = ConnectionChoice.none; // Go back to choice screen
        });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // --- NEW: Logic for Direct BLE Flow ---
  void _initiateDirectBleConnection() {
    setState(() {
      _connectionChoice = ConnectionChoice.directBle;
    });
    // Activate streams for BLE connection
    _listenToConnectionStatus();
    _listenToDiscoveredDevices();
  }

  void _listenToConnectionStatus() {
    _connectionStatusSubscription = _wearableService.connectionStatus.listen((status) {
      setState(() {
        _connectionStatus = status;
      });
      if (status == ConnectionStatus.connected) {
        _listenToHeartRate(); // Start listening for real-time HR
        _wearableService.startHeartRateMonitoring();
      }
    });
  }

  void _listenToDiscoveredDevices() {
    _discoveredDevicesSubscription = _wearableService.discoveredDevices.listen((devices) {
      setState(() {
        _discoveredDevices = devices;
      });
    });
  }

  void _listenToHeartRate() {
    _heartRateSubscription?.cancel();
    _heartRateSubscription = _wearableService.heartRate.listen((hr) async {
      if (mounted) {
        setState(() {
          _currentHeartRate = hr;
          // Update summary with real-time data
          _healthSummary['heartRate'] = {'average': hr};
        });
        await _storeHeartRateData(hr);
      }
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

  Future<void> _loadHealthData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Fetch historical data from Health Connect
      final summary = await _healthService.getHealthSummary();
      setState(() {
        _healthSummary = summary;
      });
    } catch (e) {
      print('Error loading health data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _resetConnection() {
    _connectionStatusSubscription?.cancel();
    _discoveredDevicesSubscription?.cancel();
    _heartRateSubscription?.cancel();
    _wearableService.disconnectDevice();
    setState(() {
      _connectionChoice = ConnectionChoice.none;
      _connectionStatus = ConnectionStatus.disconnected;
      _discoveredDevices = [];
      _healthSummary = {};
      _currentHeartRate = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stress Monitoring'),
        backgroundColor: Theme.of(context).primaryColor,
        actions: [
          // Show disconnect button if a connection is active
          if (_connectionChoice != ConnectionChoice.none)
            IconButton(
              icon: const Icon(Icons.link_off),
              onPressed: _resetConnection,
              tooltip: 'Disconnect',
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    switch (_connectionChoice) {
      case ConnectionChoice.none:
        return _buildChoiceScreen();
      case ConnectionChoice.googleFit:
        return _connectionStatus == ConnectionStatus.connected
            ? _buildDashboard()
            : _buildChoiceScreen(); // Or a loading/error screen
      case ConnectionChoice.directBle:
        switch (_connectionStatus) {
          case ConnectionStatus.connected:
            return _buildDashboard();
          case ConnectionStatus.connecting:
            return const Center(child: Text('Connecting...'));
          case ConnectionStatus.disconnected:
          case ConnectionStatus.error:
            return _buildDeviceDiscovery();
        }
    }
  }

  // --- NEW: Initial screen for user to select connection method ---
  Widget _buildChoiceScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.watch, size: 64, color: Colors.grey),
            const SizedBox(height: 24),
            const Text(
              'Connect Your Wearable',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'To monitor your stress, please sync your health data.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              icon: const Icon(Icons.sync),
              label: const Text('Sync with Google Fit'),
              onPressed: _syncWithGoogleFit,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '(Recommended)',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.green),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              icon: const Icon(Icons.bluetooth_searching),
              label: const Text('Connect via Bluetooth'),
              onPressed: _initiateDirectBleConnection,
              style: OutlinedButton.styleFrom(
                 padding: const EdgeInsets.symmetric(vertical: 16),
                 textStyle: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceDiscovery() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          ElevatedButton(
            onPressed: () async {
              try {
                await _wearableService.startScan();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Scan failed: $e')),
                );
              }
            },
            child: const Text('Scan for Devices'),
          ),
          const SizedBox(height: 16),
          if (_discoveredDevices.isEmpty)
            const Center(child: Text('No devices found.'))
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
    // Use real-time HR if available, otherwise use summary
    final heartRate = _currentHeartRate > 0
        ? _currentHeartRate
        : (_healthSummary['heartRate']?['average'] ?? 0).toInt();
    
    final steps = _healthSummary['steps']?['total'] ?? 0;
    final sleep = _healthSummary['sleep']?['total'] ?? 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 4,
            color: Colors.green[50],
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 32),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      _connectionChoice == ConnectionChoice.googleFit
                          ? 'Synced with Google Fit'
                          : 'Device Connected via Bluetooth',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green[800]),
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
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Health Summary', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 16),
                        Text('Heart Rate: $heartRate bpm'),
                        Text('Total Steps Today: $steps'),
                        Text('Last Sleep: ${sleep.toStringAsFixed(1)} hours'),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// Dummy implementations for StressLevel and StressAlert for compilation
enum StressLevel { low, moderate, high, critical }
class StressAlert {
  final String message;
  final DateTime timestamp;
  final StressLevel level;
  final bool requiresImmediateAttention;
  StressAlert({required this.message, required this.timestamp, required this.level, this.requiresImmediateAttention = false});
}