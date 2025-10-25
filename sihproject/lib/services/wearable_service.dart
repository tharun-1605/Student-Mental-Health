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
    if (_connectedDevice == null) throw Exception('No device connected');

    try {
      final services = await _connectedDevice!.discoverServices();

      // UUIDs for the specific Boat Watch
      final dataServiceUuid = Guid('3802');
      final dataCharacteristicUuid = Guid('4a02');
      final commandServiceUuid = Guid('6e400001-b5a3-f393-e0a9-e50e24dcca9e');
      final commandCharacteristicUuid = Guid('6e400002-b5a3-f393-e0a9-e50e24dcca9e');

      final dataService = services.firstWhere((s) => s.uuid == dataServiceUuid);
      final dataCharacteristic = dataService.characteristics.firstWhere((c) => c.uuid == dataCharacteristicUuid);

      final commandService = services.firstWhere((s) => s.uuid == commandServiceUuid);
      final commandCharacteristic = commandService.characteristics.firstWhere((c) => c.uuid == commandCharacteristicUuid);

      print('Found data characteristic: ${dataCharacteristic.uuid}');
      print('Found command characteristic: ${commandCharacteristic.uuid}');

      // 1. Write command to start measurement
      if (commandCharacteristic.properties.write) {
        print('Writing start command to ${commandCharacteristic.uuid}');
        await commandCharacteristic.write([0x01]);
        print('Start command sent successfully.');
      } else {
        throw Exception('Command characteristic does not support write.');
      }

      // 2. Listen for notifications
      if (dataCharacteristic.properties.notify) {
        await dataCharacteristic.setNotifyValue(true);
        dataCharacteristic.value.listen((value) {
          print('Received data on ${dataCharacteristic.uuid}: $value');
          final hr = _parseHeartRate(value);
          if (hr > 0) {
            print('Parsed valid heart rate: $hr');
            _heartRateController.add(hr);
          } else {
            print('Parsed value is not a valid heart rate, ignoring.');
          }
        });
        print('Successfully subscribed to notifications on ${dataCharacteristic.uuid}');
      } else {
        throw Exception('Characteristic does not support notify.');
      }

    } catch (e) {
      print('Error during heart rate monitoring setup: $e');
      throw Exception('Could not start heart rate monitoring. See logs for details.');
    }
  }

  String _getCharacteristicProperties(BluetoothCharacteristic char) {
    List<String> properties = [];
    if (char.properties.read) properties.add('read');
    if (char.properties.write) properties.add('write');
    if (char.properties.notify) properties.add('notify');
    if (char.properties.indicate) properties.add('indicate');
    return properties.join(', ');
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
      return 0; // No data
    }

    // The first byte is often a status/acknowledgment byte.
    // The actual heart rate value is typically the second byte.
    if (value.length >= 2) {
      return value[1];
    }
    
    // If we receive a single byte, it's likely a status update (like [1] for 'started')
    // and not the actual heart rate value, so we return 0.
    return 0;
  }

  Future<void> startOxygenMonitoring() async {
    print('Oxygen monitoring not implemented for this device yet.');
    // throw Exception('No device connected');
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
    print('Stress monitoring not implemented for this device yet.');
    // if (_connectedDevice == null) {
    //   throw Exception('No device connected');
    // }
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
    print('Steps monitoring not implemented for this device yet.');

    // if (_connectedDevice == null) {
    //   throw Exception('No device connected');
    // }
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
