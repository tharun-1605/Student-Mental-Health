import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/wearable_device.dart';

class WearableService {
  static final WearableService _instance = WearableService._internal();
  factory WearableService() => _instance;

  WearableService._internal();

  final FlutterBluePlus _flutterBlue = FlutterBluePlus();
  StreamSubscription? _scanSubscription;
  StreamSubscription? _connectionSubscription;

  final StreamController<List<WearableDeviceInfo>> _discoveredDevicesController =
      StreamController.broadcast();
  final StreamController<ConnectionStatus> _connectionStatusController =
      StreamController.broadcast();
  final StreamController<int> _heartRateController =
      StreamController.broadcast();
  final StreamController<int> _oxygenController =
      StreamController.broadcast();
  final StreamController<int> _stressController =
      StreamController.broadcast();
  final StreamController<int> _stepsController =
      StreamController.broadcast();

  Stream<List<WearableDeviceInfo>> get discoveredDevices =>
      _discoveredDevicesController.stream;
  Stream<ConnectionStatus> get connectionStatus =>
      _connectionStatusController.stream;
  Stream<int> get heartRate => _heartRateController.stream;
  Stream<int> get oxygen => _oxygenController.stream;
  Stream<int> get stress => _stressController.stream;
  Stream<int> get steps => _stepsController.stream;

  BluetoothDevice? _connectedDevice;
  List<WearableDeviceInfo> _discoveredDevices = [];

  Future<bool> requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location, // ACCESS_FINE_LOCATION required for BLE scanning
    ].request();

    return statuses.values.every((status) => status.isGranted);
  }

  Future<bool> isBluetoothAvailable() async {
    try {
      return await FlutterBluePlus.isAvailable;
    } catch (e) {
      return false;
    }
  }

  Future<bool> isBluetoothEnabled() async {
    try {
      return await FlutterBluePlus.isOn;
    } catch (e) {
      return false;
    }
  }

  Future<void> startScan({Duration timeout = const Duration(seconds: 10)}) async {
    print('WearableService: Starting scan...');

    final bluetoothAvailable = await isBluetoothAvailable();
    print('WearableService: Bluetooth available: $bluetoothAvailable');

    final bluetoothEnabled = await isBluetoothEnabled();
    print('WearableService: Bluetooth enabled: $bluetoothEnabled');

    if (!bluetoothEnabled) {
      print('WearableService: Bluetooth not enabled, throwing exception');
      throw Exception('Bluetooth is not enabled');
    }

    final permissionsGranted = await requestPermissions();
    print('WearableService: Permissions granted: $permissionsGranted');

    if (!permissionsGranted) {
      print('WearableService: Permissions not granted, throwing exception');
      throw Exception('Bluetooth permissions not granted');
    }

    _discoveredDevices.clear();
    _discoveredDevicesController.add([]);
    print('WearableService: Cleared discovered devices');

    _scanSubscription?.cancel();
    print('WearableService: Setting up scan results listener');

    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      print('WearableService: Scan results received: ${results.length} devices');
      for (var result in results) {
        print('WearableService: Found device: ${result.device.name} (${result.device.remoteId})');
      }

      // Filter out devices with empty names to avoid listing irrelevant devices
      final filteredResults = results.where((result) => result.device.name.isNotEmpty).toList();

      _discoveredDevices = filteredResults.map((result) {
        return _bluetoothDeviceToWearableInfo(result.device);
      }).toList();

      print('WearableService: Mapped to wearable info: ${_discoveredDevices.length} devices');
      _discoveredDevicesController.add(_discoveredDevices);
    });

    print('WearableService: Starting FlutterBluePlus scan with timeout: $timeout');
    await FlutterBluePlus.startScan(timeout: timeout);
    print('WearableService: Scan completed');
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    _scanSubscription?.cancel();
  }

  Future<bool> connectToDevice(WearableDeviceInfo deviceInfo) async {
    try {
      await stopScan();
      _connectionStatusController.add(ConnectionStatus.connecting);

      // Find the Bluetooth device
      BluetoothDevice? device = await _findBluetoothDevice(deviceInfo);
      if (device == null) {
        throw Exception('Device not found');
      }

      _connectedDevice = device;

      // Connect to the device if not already connected
      if (!device.isConnected) {
        await device.connect(timeout: const Duration(seconds: 15));
      }

      // Discover services
      List<BluetoothService> services = await device.discoverServices();

      // Update device info with connection status
      _connectionStatusController.add(ConnectionStatus.connected);

      // Start monitoring connection status
      _monitorConnection();

      return true;
    } catch (e) {
      _connectionStatusController.add(ConnectionStatus.error);
      throw Exception('Failed to connect: $e');
    }
  }

  Future<void> disconnectDevice() async {
    if (_connectedDevice != null) {
      await _connectedDevice!.disconnect();
      _connectedDevice = null;
      _connectionStatusController.add(ConnectionStatus.disconnected);
      _stopPeriodicHeartRateRead();
    }
  }

  Future<void> _monitorConnection() async {
    if (_connectedDevice == null) return;

    _connectionSubscription?.cancel();
    _connectionSubscription = _connectedDevice!.connectionState.listen((state) {
      switch (state) {
        case BluetoothConnectionState.disconnected:
          _connectionStatusController.add(ConnectionStatus.disconnected);
          // Auto-reconnect attempt
          _attemptReconnect();
          break;
        case BluetoothConnectionState.connected:
          _connectionStatusController.add(ConnectionStatus.connected);
          break;
        case BluetoothConnectionState.connecting:
          _connectionStatusController.add(ConnectionStatus.connecting);
          break;
        case BluetoothConnectionState.disconnecting:
          // Handle disconnecting state if needed
          break;
      }
    });
  }

  Future<void> _attemptReconnect() async {
    if (_connectedDevice == null) return;

    // Wait a bit before attempting reconnect
    await Future.delayed(const Duration(seconds: 2));

    try {
      if (!_connectedDevice!.isConnected) {
        await _connectedDevice!.connect(timeout: const Duration(seconds: 10));
        // If reconnect successful, start heart rate monitoring again
        await startHeartRateMonitoring();
      }
    } catch (e) {
      // Reconnect failed, will try again on next disconnect
      print('Auto-reconnect failed: $e');
    }
  }

  Future<BluetoothDevice?> _findBluetoothDevice(WearableDeviceInfo deviceInfo) async {
    List<BluetoothDevice> devices = FlutterBluePlus.connectedDevices;

    // First check connected devices
    for (var device in devices) {
      if (device.remoteId.str == deviceInfo.id) {
        return device;
      }
    }

    // If not found, try to find by name or MAC address from discovered devices
    // We need to get the actual BluetoothDevice from scan results
    List<ScanResult> scanResults = await FlutterBluePlus.scanResults.first;
    for (var result in scanResults) {
      if (result.device.remoteId.str == deviceInfo.id ||
          result.device.name == deviceInfo.name ||
          result.device.remoteId.str == deviceInfo.macAddress) {
        return result.device;
      }
    }

    return null;
  }

  WearableDeviceInfo _bluetoothDeviceToWearableInfo(BluetoothDevice device) {
    // Try to identify the device brand based on name or other characteristics
    WearableBrand brand = _identifyBrand(device);

    return WearableDeviceInfo(
      id: device.remoteId.str,
      name: device.name.isNotEmpty ? device.name : 'Unknown Device',
      brand: brand,
      model: _getModelFromName(device.name),
      macAddress: device.remoteId.str,
      status: ConnectionStatus.disconnected,
      capabilities: WearableBrandCapabilities.brandCapabilities[brand]?.toMap() ?? {},
      isPaired: false,
    );
  }

  WearableBrand _identifyBrand(BluetoothDevice device) {
    String name = device.name.toLowerCase();

    if (name.contains('wear') || name.contains('pixel')) {
      return WearableBrand.wearOS;
    } else if (name.contains('watch') || name.contains('apple')) {
      return WearableBrand.appleWatch;
    } else if (name.contains('fitbit')) {
      return WearableBrand.fitbit;
    } else if (name.contains('mi band') || name.contains('xiaomi')) {
      return WearableBrand.miBand;
    } else if (name.contains('garmin')) {
      return WearableBrand.garmin;
    } else if (name.contains('galaxy') || name.contains('samsung')) {
      return WearableBrand.samsung;
    } else if (name.contains('boat')) {
      return WearableBrand.boat;
    } else {
      return WearableBrand.other;
    }
  }

  String _getModelFromName(String deviceName) {
    // Extract model information from device name
    // This is a simplified implementation
    return deviceName.isNotEmpty ? deviceName : 'Unknown Model';
  }

  Future<List<WearableDeviceInfo>> getPairedDevices() async {
    List<BluetoothDevice> devices = await FlutterBluePlus.bondedDevices;
    print('Paired devices: ${devices.map((d) => d.name).toList()}');

    return devices.map((device) {
      return _bluetoothDeviceToWearableInfo(device);
    }).toList();
  }

  Future<List<WearableDeviceInfo>> getConnectedDevices() async {
    List<BluetoothDevice> devices = FlutterBluePlus.connectedDevices;
    print('Connected devices: ${devices.map((d) => d.name).toList()}');

    return devices.map((device) {
      return _bluetoothDeviceToWearableInfo(device);
    }).toList();
  }

  Future<void> setConnectedDevice(WearableDeviceInfo deviceInfo) async {
    BluetoothDevice? device = await _findBluetoothDevice(deviceInfo);
    if (device != null && device.isConnected) {
      _connectedDevice = device;
      _connectionStatusController.add(ConnectionStatus.connected);
      _monitorConnection();
    }
  }

  Future<bool> isDeviceConnected() async {
    if (_connectedDevice == null) return false;

    try {
      return _connectedDevice!.isConnected;
    } catch (e) {
      return false;
    }
  }

  Future<void> startHeartRateMonitoring() async {
    if (_connectedDevice == null) {
      throw Exception('No device connected');
    }

    final services = await _connectedDevice!.discoverServices();

    // Log all services and characteristics for debugging
    for (var service in services) {
      print('Service: ${service.uuid}');
      for (var char in service.characteristics) {
        print('  Characteristic: ${char.uuid}');
      }
    }

    BluetoothService? heartRateService;
    BluetoothCharacteristic? heartRateCharacteristic;

    // List of known heart rate service and characteristic UUIDs
    final knownHeartRateServices = [
      Guid('0000180d-0000-1000-8000-00805f9b34fb'), // Standard
      Guid('0000fee0-0000-1000-8000-00805f9b34fb'), // Xiaomi/Boat
      Guid('0000fee1-0000-1000-8000-00805f9b34fb'), // Xiaomi/Boat alternative
    ];

    final knownHeartRateCharacteristics = [
      Guid('00002a37-0000-1000-8000-00805f9b34fb'), // Standard
      Guid('00000006-0000-3512-2118-0009af100700'), // Xiaomi heart rate
      Guid('00000001-0000-3512-2118-0009af100700'), // Xiaomi heart rate alternative
      Guid('ae01'), // Boat Crest potential heart rate
      Guid('ae02'), // Boat Crest potential
      Guid('4a02'), // Boat Crest potential
      Guid('ae3b'), // Boat Crest potential
      Guid('ae3c'), // Boat Crest potential
    ];

    final knownHeartRateControlCharacteristics = [
      Guid('00000002-0000-3512-2118-0009af100700'), // Xiaomi heart rate control
    ];

    // Try known services and characteristics
    for (var serviceUuid in knownHeartRateServices) {
      try {
        heartRateService = services.firstWhere((s) => s.uuid == serviceUuid);
        for (var charUuid in knownHeartRateCharacteristics) {
          try {
            heartRateCharacteristic = heartRateService.characteristics.firstWhere((c) => c.uuid == charUuid);
            break;
          } catch (e) {
            // Continue to next characteristic
          }
        }
        if (heartRateCharacteristic != null) break;
      } catch (e) {
        // Continue to next service
      }
    }

    // If not found, try to find any characteristic that might be heart rate
    if (heartRateCharacteristic == null) {
      print('Known heart rate UUIDs not found, searching for alternatives...');
      for (var service in services) {
        for (var char in service.characteristics) {
          String uuidStr = char.uuid.toString().toLowerCase();
          if (uuidStr.contains('heart') || uuidStr.contains('hr') || uuidStr.contains('2a37') ||
              uuidStr.contains('0006') || uuidStr.contains('0001') || uuidStr.contains('ae') ||
              uuidStr.contains('4a')) {
            heartRateService = service;
            heartRateCharacteristic = char;
            print('Found potential heart rate characteristic: ${char.uuid}');
            break;
          }
        }
        if (heartRateCharacteristic != null) break;
      }
    }

    if (heartRateCharacteristic == null) {
      throw Exception('Heart rate characteristic not found. Available services and characteristics logged above.');
    }

    print('Using heart rate characteristic: ${heartRateCharacteristic.uuid}');

    // For Xiaomi/Boat devices, try to start heart rate measurement
    if (heartRateService != null && knownHeartRateServices.skip(1).contains(heartRateService.uuid)) {
      try {
        var controlChar = heartRateService.characteristics.firstWhere(
          (c) => knownHeartRateControlCharacteristics.contains(c.uuid),
        );
        await controlChar.write([0x01]); // Start heart rate measurement
        print('Sent start command to heart rate control characteristic');
        await Future.delayed(const Duration(seconds: 1)); // Wait for device to start
      } catch (e) {
        print('Failed to write to heart rate control characteristic: $e');
      }
    }

    try {
      await heartRateCharacteristic.setNotifyValue(true);
      heartRateCharacteristic.value.listen((value) {
        final hr = _parseHeartRate(value);
        print('Received heart rate: $hr from value: $value');
        _heartRateController.add(hr);
      });

      // Read initial value
      final initialValue = await heartRateCharacteristic.read();
      final initialHr = _parseHeartRate(initialValue);
      _heartRateController.add(initialHr);
    } catch (e) {
      print('Failed to set notify value, trying periodic read: $e');
      // Fallback: read periodically if notify not supported
      _startPeriodicHeartRateRead(heartRateCharacteristic);
    }
  }

  Timer? _periodicReadTimer;

  void _startPeriodicHeartRateRead(BluetoothCharacteristic characteristic) {
    _periodicReadTimer?.cancel();
    _periodicReadTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      try {
        List<int> value = await characteristic.read();
        final hr = _parseHeartRate(value);
        print('Periodic read heart rate: $hr from value: $value');
        _heartRateController.add(hr);
      } catch (e) {
        print('Failed periodic read of heart rate: $e');
      }
    });
  }

  void _stopPeriodicHeartRateRead() {
    _periodicReadTimer?.cancel();
    _periodicReadTimer = null;
  }

  int _parseHeartRate(List<int> value) {
    if (value.isEmpty) {
      print('Empty heart rate value received');
      return 0;
    }

    print('Parsing heart rate value: $value');

    // Try standard Bluetooth SIG heart rate format first
    if (value.length >= 2) {
      final flags = value[0];
      final is16bit = (flags & 0x01) != 0;

      if (is16bit && value.length >= 3) {
        return (value[2] << 8) + value[1];
      } else {
        return value[1];
      }
    }

    // Try Xiaomi/Boat format (little endian 16-bit)
    if (value.length >= 2) {
      return (value[1] << 8) + value[0];
    }

    // Fallback: assume single byte
    return value[0];
  }

  Future<void> startOxygenMonitoring() async {
    if (_connectedDevice == null) {
      throw Exception('No device connected');
    }

    final services = await _connectedDevice!.discoverServices();

    BluetoothCharacteristic? oxygenCharacteristic;

    // List of known oxygen/SpO2 characteristic UUIDs
    final knownOxygenCharacteristics = [
      Guid('00002a5f-0000-1000-8000-00805f9b34fb'), // Standard SpO2
      Guid('00000007-0000-3512-2118-0009af100700'), // Xiaomi SpO2
      Guid('ae0a'), // Boat Crest potential SpO2
      Guid('ae0b'), // Boat Crest potential
    ];

    // Try known characteristics
    for (var service in services) {
      for (var charUuid in knownOxygenCharacteristics) {
        try {
          oxygenCharacteristic = service.characteristics.firstWhere((c) => c.uuid == charUuid);
          break;
        } catch (e) {
          // Continue to next characteristic
        }
      }
      if (oxygenCharacteristic != null) break;
    }

    // If not found, try to find any characteristic that might be oxygen
    if (oxygenCharacteristic == null) {
      print('Known oxygen UUIDs not found, searching for alternatives...');
      for (var service in services) {
        for (var char in service.characteristics) {
          String uuidStr = char.uuid.toString().toLowerCase();
          if (uuidStr.contains('spo2') || uuidStr.contains('oxygen') || uuidStr.contains('2a5f') ||
              uuidStr.contains('0007') || uuidStr.contains('ae0')) {
            oxygenCharacteristic = char;
            print('Found potential oxygen characteristic: ${char.uuid}');
            break;
          }
        }
        if (oxygenCharacteristic != null) break;
      }
    }

    if (oxygenCharacteristic == null) {
      print('Oxygen characteristic not found, trying periodic read fallback');
      // Fallback: try to find any characteristic that might work
      for (var service in services) {
        if (service.characteristics.isNotEmpty) {
          oxygenCharacteristic = service.characteristics.first;
          print('Using fallback oxygen characteristic: ${oxygenCharacteristic.uuid}');
          break;
        }
      }
    }

    if (oxygenCharacteristic == null) {
      throw Exception('Oxygen characteristic not found');
    }

    print('Using oxygen characteristic: ${oxygenCharacteristic.uuid}');

    try {
      await oxygenCharacteristic.setNotifyValue(true);
      oxygenCharacteristic.value.listen((value) {
        final oxygen = _parseOxygen(value);
        print('Received oxygen: $oxygen from value: $value');
        _oxygenController.add(oxygen);
      });
    } catch (e) {
      print('Failed to set notify value for oxygen, trying periodic read: $e');
      // Fallback: read periodically if notify not supported
      _startPeriodicOxygenRead(oxygenCharacteristic);
    }
  }

  void _startPeriodicOxygenRead(BluetoothCharacteristic characteristic) {
    _periodicOxygenReadTimer?.cancel();
    _periodicOxygenReadTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      try {
        List<int> value = await characteristic.read();
        final oxygen = _parseOxygen(value);
        print('Periodic read oxygen: $oxygen from value: $value');
        _oxygenController.add(oxygen);
      } catch (e) {
        print('Failed periodic read of oxygen: $e');
      }
    });
  }

  int _parseOxygen(List<int> value) {
    if (value.isEmpty) {
      print('Empty oxygen value received');
      return 0;
    }

    print('Parsing oxygen value: $value');

    // Try standard SpO2 format
    if (value.length >= 2) {
      return value[1]; // SpO2 percentage
    }

    // Try Xiaomi/Boat format
    if (value.isNotEmpty) {
      return value[0];
    }

    return 0;
  }

  Future<void> startStressMonitoring() async {
    if (_connectedDevice == null) {
      throw Exception('No device connected');
    }

    final services = await _connectedDevice!.discoverServices();

    BluetoothCharacteristic? stressCharacteristic;

    // List of known stress characteristic UUIDs (these are hypothetical as stress is not standardized)
    final knownStressCharacteristics = [
      Guid('00000008-0000-3512-2118-0009af100700'), // Xiaomi stress (hypothetical)
      Guid('ae0c'), // Boat Crest potential stress
      Guid('ae0d'), // Boat Crest potential
    ];

    // Try known characteristics
    for (var service in services) {
      for (var charUuid in knownStressCharacteristics) {
        try {
          stressCharacteristic = service.characteristics.firstWhere((c) => c.uuid == charUuid);
          break;
        } catch (e) {
          // Continue to next characteristic
        }
      }
      if (stressCharacteristic != null) break;
    }

    // If not found, try to find any characteristic that might be stress
    if (stressCharacteristic == null) {
      print('Known stress UUIDs not found, searching for alternatives...');
      for (var service in services) {
        for (var char in service.characteristics) {
          String uuidStr = char.uuid.toString().toLowerCase();
          if (uuidStr.contains('stress') || uuidStr.contains('0008') || uuidStr.contains('ae0c') ||
              uuidStr.contains('ae0d')) {
            stressCharacteristic = char;
            print('Found potential stress characteristic: ${char.uuid}');
            break;
          }
        }
        if (stressCharacteristic != null) break;
      }
    }

    if (stressCharacteristic == null) {
      print('Stress characteristic not found, trying periodic read fallback');
      // Fallback: try to find any characteristic that might work
      for (var service in services) {
        if (service.characteristics.isNotEmpty) {
          stressCharacteristic = service.characteristics.first;
          print('Using fallback stress characteristic: ${stressCharacteristic.uuid}');
          break;
        }
      }
    }

    if (stressCharacteristic == null) {
      throw Exception('Stress characteristic not found');
    }

    print('Using stress characteristic: ${stressCharacteristic.uuid}');

    try {
      await stressCharacteristic.setNotifyValue(true);
      stressCharacteristic.value.listen((value) {
        final stress = _parseStress(value);
        print('Received stress: $stress from value: $value');
        _stressController.add(stress);
      });
    } catch (e) {
      print('Failed to set notify value for stress, trying periodic read: $e');
      // Fallback: read periodically if notify not supported
      _startPeriodicStressRead(stressCharacteristic);
    }
  }

  void _startPeriodicStressRead(BluetoothCharacteristic characteristic) {
    _periodicStressReadTimer?.cancel();
    _periodicStressReadTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      try {
        List<int> value = await characteristic.read();
        final stress = _parseStress(value);
        print('Periodic read stress: $stress from value: $value');
        _stressController.add(stress);
      } catch (e) {
        print('Failed periodic read of stress: $e');
      }
    });
  }

  int _parseStress(List<int> value) {
    if (value.isEmpty) {
      print('Empty stress value received');
      return 0;
    }

    print('Parsing stress value: $value');

    // Assume stress is a single byte value 0-100
    if (value.isNotEmpty) {
      return value[0].clamp(0, 100);
    }

    return 0;
  }

  Timer? _periodicOxygenReadTimer;
  Timer? _periodicStressReadTimer;
  Timer? _periodicStepsReadTimer;

  Future<void> startStepsMonitoring() async {
    if (_connectedDevice == null) {
      throw Exception('No device connected');
    }

    final services = await _connectedDevice!.discoverServices();

    BluetoothCharacteristic? stepsCharacteristic;

    // List of known steps characteristic UUIDs
    final knownStepsCharacteristics = [
      Guid('00002a53-0000-1000-8000-00805f9b34fb'), // Standard steps
      Guid('00000009-0000-3512-2118-0009af100700'), // Xiaomi steps (hypothetical)
      Guid('ae0e'), // Boat Crest potential steps
      Guid('ae0f'), // Boat Crest potential
    ];

    // Try known characteristics
    for (var service in services) {
      for (var charUuid in knownStepsCharacteristics) {
        try {
          stepsCharacteristic = service.characteristics.firstWhere((c) => c.uuid == charUuid);
          break;
        } catch (e) {
          // Continue to next characteristic
        }
      }
      if (stepsCharacteristic != null) break;
    }

    // If not found, try to find any characteristic that might be steps
    if (stepsCharacteristic == null) {
      print('Known steps UUIDs not found, searching for alternatives...');
      for (var service in services) {
        for (var char in service.characteristics) {
          String uuidStr = char.uuid.toString().toLowerCase();
          if (uuidStr.contains('steps') || uuidStr.contains('0009') || uuidStr.contains('ae0e') ||
              uuidStr.contains('ae0f')) {
            stepsCharacteristic = char;
            print('Found potential steps characteristic: ${char.uuid}');
            break;
          }
        }
        if (stepsCharacteristic != null) break;
      }
    }

    if (stepsCharacteristic == null) {
      print('Steps characteristic not found, trying periodic read fallback');
      // Fallback: try to find any characteristic that might work
      for (var service in services) {
        if (service.characteristics.isNotEmpty) {
          stepsCharacteristic = service.characteristics.first;
          print('Using fallback steps characteristic: ${stepsCharacteristic.uuid}');
          break;
        }
      }
    }

    if (stepsCharacteristic == null) {
      throw Exception('Steps characteristic not found');
    }

    print('Using steps characteristic: ${stepsCharacteristic.uuid}');

    try {
      await stepsCharacteristic.setNotifyValue(true);
      stepsCharacteristic.value.listen((value) {
        final steps = _parseSteps(value);
        print('Received steps: $steps from value: $value');
        _stepsController.add(steps);
      });
    } catch (e) {
      print('Failed to set notify value for steps, trying periodic read: $e');
      // Fallback: read periodically if notify not supported
      _startPeriodicStepsRead(stepsCharacteristic);
    }
  }

  void _startPeriodicStepsRead(BluetoothCharacteristic characteristic) {
    _periodicStepsReadTimer?.cancel();
    _periodicStepsReadTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      try {
        List<int> value = await characteristic.read();
        final steps = _parseSteps(value);
        print('Periodic read steps: $steps from value: $value');
        _stepsController.add(steps);
      } catch (e) {
        print('Failed periodic read of steps: $e');
      }
    });
  }

  int _parseSteps(List<int> value) {
    if (value.isEmpty) {
      print('Empty steps value received');
      return 0;
    }

    print('Parsing steps value: $value');

    // Assume steps is a 32-bit little endian integer
    if (value.length >= 4) {
      return value[0] | (value[1] << 8) | (value[2] << 16) | (value[3] << 24);
    }

    // Fallback: try 16-bit integer
    if (value.length >= 2) {
      return value[0] | (value[1] << 8);
    }

    // Fallback: single byte
    return value[0];
  }

  void _stopPeriodicOxygenRead() {
    _periodicOxygenReadTimer?.cancel();
    _periodicOxygenReadTimer = null;
  }

  void _stopPeriodicStressRead() {
    _periodicStressReadTimer?.cancel();
    _periodicStressReadTimer = null;
  }

  void _stopPeriodicStepsRead() {
    _periodicStepsReadTimer?.cancel();
    _periodicStepsReadTimer = null;
  }

  void dispose() {
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
    _stopPeriodicHeartRateRead();
    _stopPeriodicOxygenRead();
    _stopPeriodicStressRead();
    _stopPeriodicStepsRead();
    _discoveredDevicesController.close();
    _connectionStatusController.close();
    _heartRateController.close();
    _oxygenController.close();
    _stressController.close();
    _stepsController.close();
  }
}
