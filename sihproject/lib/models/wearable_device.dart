import 'package:cloud_firestore/cloud_firestore.dart';

enum WearableBrand {
  wearOS,
  appleWatch,
  fitbit,
  miBand,
  garmin,
  samsung,
  boat,
  other
}

enum ConnectionStatus {
  disconnected,
  connecting,
  connected,
  error
}

class WearableDeviceInfo {
  final String id;
  final String name;
  final WearableBrand brand;
  final String model;
  final String? macAddress;
  final ConnectionStatus status;
  final DateTime? lastConnected;
  final Map<String, dynamic> capabilities;
  final bool isPaired;

  WearableDeviceInfo({
    required this.id,
    required this.name,
    required this.brand,
    required this.model,
    this.macAddress,
    this.status = ConnectionStatus.disconnected,
    this.lastConnected,
    required this.capabilities,
    this.isPaired = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'brand': brand.toString(),
      'model': model,
      'macAddress': macAddress,
      'status': status.toString(),
      'lastConnected': lastConnected != null ? Timestamp.fromDate(lastConnected!) : null,
      'capabilities': capabilities,
      'isPaired': isPaired,
    };
  }

  factory WearableDeviceInfo.fromMap(String id, Map<String, dynamic> map) {
    return WearableDeviceInfo(
      id: id,
      name: map['name'],
      brand: WearableBrand.values.firstWhere(
        (e) => e.toString() == map['brand'],
      ),
      model: map['model'],
      macAddress: map['macAddress'],
      status: ConnectionStatus.values.firstWhere(
        (e) => e.toString() == map['status'],
        orElse: () => ConnectionStatus.disconnected,
      ),
      lastConnected: map['lastConnected'] != null
          ? (map['lastConnected'] as Timestamp).toDate()
          : null,
      capabilities: map['capabilities'] ?? {},
      isPaired: map['isPaired'] ?? false,
    );
  }

  WearableDeviceInfo copyWith({
    String? name,
    WearableBrand? brand,
    String? model,
    String? macAddress,
    ConnectionStatus? status,
    DateTime? lastConnected,
    Map<String, dynamic>? capabilities,
    bool? isPaired,
  }) {
    return WearableDeviceInfo(
      id: id,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      macAddress: macAddress ?? this.macAddress,
      status: status ?? this.status,
      lastConnected: lastConnected ?? this.lastConnected,
      capabilities: capabilities ?? this.capabilities,
      isPaired: isPaired ?? this.isPaired,
    );
  }
}

class WearableCapabilities {
  final bool supportsHeartRate;
  final bool supportsSleepTracking;
  final bool supportsStepCounting;
  final bool supportsStressMonitoring;
  final bool supportsGPS;
  final bool supportsBloodOxygen;
  final bool supportsECG;
  final List<String> supportedDataTypes;

  const WearableCapabilities({
    this.supportsHeartRate = false,
    this.supportsSleepTracking = false,
    this.supportsStepCounting = false,
    this.supportsStressMonitoring = false,
    this.supportsGPS = false,
    this.supportsBloodOxygen = false,
    this.supportsECG = false,
    this.supportedDataTypes = const [],
  });

  factory WearableCapabilities.fromMap(Map<String, dynamic> map) {
    return WearableCapabilities(
      supportsHeartRate: map['heartRate'] ?? false,
      supportsSleepTracking: map['sleepTracking'] ?? false,
      supportsStepCounting: map['stepCounting'] ?? false,
      supportsStressMonitoring: map['stressMonitoring'] ?? false,
      supportsGPS: map['gps'] ?? false,
      supportsBloodOxygen: map['bloodOxygen'] ?? false,
      supportsECG: map['ecg'] ?? false,
      supportedDataTypes: List<String>.from(map['dataTypes'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'heartRate': supportsHeartRate,
      'sleepTracking': supportsSleepTracking,
      'stepCounting': supportsStepCounting,
      'stressMonitoring': supportsStressMonitoring,
      'gps': supportsGPS,
      'bloodOxygen': supportsBloodOxygen,
      'ecg': supportsECG,
      'dataTypes': supportedDataTypes,
    };
  }

  WearableCapabilities copyWith({
    bool? supportsHeartRate,
    bool? supportsSleepTracking,
    bool? supportsStepCounting,
    bool? supportsStressMonitoring,
    bool? supportsGPS,
    bool? supportsBloodOxygen,
    bool? supportsECG,
    List<String>? supportedDataTypes,
  }) {
    return WearableCapabilities(
      supportsHeartRate: supportsHeartRate ?? this.supportsHeartRate,
      supportsSleepTracking: supportsSleepTracking ?? this.supportsSleepTracking,
      supportsStepCounting: supportsStepCounting ?? this.supportsStepCounting,
      supportsStressMonitoring: supportsStressMonitoring ?? this.supportsStressMonitoring,
      supportsGPS: supportsGPS ?? this.supportsGPS,
      supportsBloodOxygen: supportsBloodOxygen ?? this.supportsBloodOxygen,
      supportsECG: supportsECG ?? this.supportsECG,
      supportedDataTypes: supportedDataTypes ?? this.supportedDataTypes,
    );
  }
}

// Predefined capabilities for different wearable brands
class WearableBrandCapabilities {
  static const Map<WearableBrand, WearableCapabilities> brandCapabilities = {
    WearableBrand.wearOS: WearableCapabilities(
      supportsHeartRate: true,
      supportsSleepTracking: true,
      supportsStepCounting: true,
      supportsStressMonitoring: true,
      supportsGPS: true,
      supportsBloodOxygen: true,
      supportedDataTypes: ['heartRate', 'sleep', 'steps', 'stress', 'activity'],
    ),
    WearableBrand.appleWatch: WearableCapabilities(
      supportsHeartRate: true,
      supportsSleepTracking: true,
      supportsStepCounting: true,
      supportsStressMonitoring: false,
      supportsGPS: true,
      supportsBloodOxygen: true,
      supportsECG: true,
      supportedDataTypes: ['heartRate', 'sleep', 'steps', 'activity', 'bloodOxygen', 'ecg'],
    ),
    WearableBrand.fitbit: WearableCapabilities(
      supportsHeartRate: true,
      supportsSleepTracking: true,
      supportsStepCounting: true,
      supportsStressMonitoring: true,
      supportsGPS: true,
      supportsBloodOxygen: true,
      supportedDataTypes: ['heartRate', 'sleep', 'steps', 'stress', 'activity', 'bloodOxygen'],
    ),
    WearableBrand.miBand: WearableCapabilities(
      supportsHeartRate: true,
      supportsSleepTracking: true,
      supportsStepCounting: true,
      supportsStressMonitoring: true,
      supportsGPS: false,
      supportsBloodOxygen: true,
      supportedDataTypes: ['heartRate', 'sleep', 'steps', 'stress', 'bloodOxygen'],
    ),
    WearableBrand.garmin: WearableCapabilities(
      supportsHeartRate: true,
      supportsSleepTracking: true,
      supportsStepCounting: true,
      supportsStressMonitoring: true,
      supportsGPS: true,
      supportsBloodOxygen: true,
      supportsECG: true,
      supportedDataTypes: ['heartRate', 'sleep', 'steps', 'stress', 'activity', 'bloodOxygen', 'ecg'],
    ),
    WearableBrand.samsung: WearableCapabilities(
      supportsHeartRate: true,
      supportsSleepTracking: true,
      supportsStepCounting: true,
      supportsStressMonitoring: true,
      supportsGPS: true,
      supportsBloodOxygen: true,
      supportedDataTypes: ['heartRate', 'sleep', 'steps', 'stress', 'activity', 'bloodOxygen'],
    ),
    WearableBrand.boat: WearableCapabilities(
      supportsHeartRate: true,
      supportsSleepTracking: true,
      supportsStepCounting: true,
      supportsStressMonitoring: true,
      supportsGPS: false,
      supportsBloodOxygen: true,
      supportedDataTypes: ['heartRate', 'sleep', 'steps', 'stress', 'bloodOxygen'],
    ),
  };
}
