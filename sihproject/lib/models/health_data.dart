import 'package:cloud_firestore/cloud_firestore.dart';

enum HealthDataType {
  heartRate,
  sleep,
  steps,
  stress,
  activity
}

class HealthDataPoint {
  final DateTime timestamp;
  final double value;
  final HealthDataType type;
  final String? unit;
  final Map<String, dynamic>? metadata;

  HealthDataPoint({
    required this.timestamp,
    required this.value,
    required this.type,
    this.unit,
    this.metadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'timestamp': Timestamp.fromDate(timestamp),
      'value': value,
      'type': type.toString(),
      'unit': unit,
      'metadata': metadata,
    };
  }

  factory HealthDataPoint.fromMap(Map<String, dynamic> map) {
    return HealthDataPoint(
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      value: (map['value'] as num).toDouble(),
      type: HealthDataType.values.firstWhere(
        (e) => e.toString() == map['type'],
      ),
      unit: map['unit'],
      metadata: map['metadata'],
    );
  }
}

class HeartRateData extends HealthDataPoint {
  final int? restingHeartRate;
  final String? zone; // resting, fat_burn, cardio, peak

  HeartRateData({
    required super.timestamp,
    required super.value,
    this.restingHeartRate,
    this.zone,
  }) : super(
    type: HealthDataType.heartRate,
    unit: 'bpm',
    metadata: {
      if (restingHeartRate != null) 'restingHeartRate': restingHeartRate,
      if (zone != null) 'zone': zone,
    },
  );
}

class SleepData extends HealthDataPoint {
  final int? deepSleepMinutes;
  final int? lightSleepMinutes;
  final int? remSleepMinutes;
  final int? awakeMinutes;
  final SleepQuality? quality;

  SleepData({
    required super.timestamp,
    required super.value, // total sleep duration in minutes
    this.deepSleepMinutes,
    this.lightSleepMinutes,
    this.remSleepMinutes,
    this.awakeMinutes,
    this.quality,
  }) : super(
    type: HealthDataType.sleep,
    unit: 'minutes',
    metadata: {
      if (deepSleepMinutes != null) 'deepSleepMinutes': deepSleepMinutes,
      if (lightSleepMinutes != null) 'lightSleepMinutes': lightSleepMinutes,
      if (remSleepMinutes != null) 'remSleepMinutes': remSleepMinutes,
      if (awakeMinutes != null) 'awakeMinutes': awakeMinutes,
      if (quality != null) 'quality': quality.toString(),
    },
  );
}

class ActivityData extends HealthDataPoint {
  final int? caloriesBurned;
  final double? distance; // in km
  final ActivityType? activityType;

  ActivityData({
    required super.timestamp,
    required super.value, // steps
    this.caloriesBurned,
    this.distance,
    this.activityType,
  }) : super(
    type: HealthDataType.steps,
    unit: 'steps',
    metadata: {
      if (caloriesBurned != null) 'caloriesBurned': caloriesBurned,
      if (distance != null) 'distance': distance,
      if (activityType != null) 'activityType': activityType.toString(),
    },
  );
}

class StressData extends HealthDataPoint {
  final StressLevel? level;
  final List<String>? sources;

  StressData({
    required super.timestamp,
    required super.value, // stress score 0-100
    this.level,
    this.sources,
  }) : super(
    type: HealthDataType.stress,
    unit: 'score',
    metadata: {
      if (level != null) 'level': level.toString(),
      if (sources != null) 'sources': sources,
    },
  );
}

enum SleepQuality {
  poor,
  fair,
  good,
  excellent
}

enum ActivityType {
  walking,
  running,
  cycling,
  swimming,
  other
}

enum StressLevel {
  low,
  moderate,
  high,
  critical
}

class HealthInsight {
  final String id;
  final DateTime timestamp;
  final String title;
  final String description;
  final InsightType type;
  final List<String> recommendations;
  final Map<String, dynamic> data;

  HealthInsight({
    required this.id,
    required this.timestamp,
    required this.title,
    required this.description,
    required this.type,
    required this.recommendations,
    required this.data,
  });

  Map<String, dynamic> toMap() {
    return {
      'timestamp': Timestamp.fromDate(timestamp),
      'title': title,
      'description': description,
      'type': type.toString(),
      'recommendations': recommendations,
      'data': data,
    };
  }

  factory HealthInsight.fromMap(String id, Map<String, dynamic> map) {
    return HealthInsight(
      id: id,
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      title: map['title'],
      description: map['description'],
      type: InsightType.values.firstWhere(
        (e) => e.toString() == map['type'],
      ),
      recommendations: List<String>.from(map['recommendations']),
      data: map['data'],
    );
  }
}

enum InsightType {
  stressPattern,
  sleepQuality,
  activityLevel,
  heartRateAnomaly,
  generalWellness
}

class WearableDevice {
  final String id;
  final String name;
  final String brand;
  final String model;
  final DeviceType deviceType;
  final String? macAddress;
  final bool isConnected;
  final DateTime? lastSyncTime;
  final Map<String, dynamic> capabilities;

  WearableDevice({
    required this.id,
    required this.name,
    required this.brand,
    required this.model,
    required this.deviceType,
    this.macAddress,
    this.isConnected = false,
    this.lastSyncTime,
    required this.capabilities,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'brand': brand,
      'model': model,
      'deviceType': deviceType.toString(),
      'macAddress': macAddress,
      'isConnected': isConnected,
      'lastSyncTime': lastSyncTime != null ? Timestamp.fromDate(lastSyncTime!) : null,
      'capabilities': capabilities,
    };
  }

  factory WearableDevice.fromMap(String id, Map<String, dynamic> map) {
    return WearableDevice(
      id: id,
      name: map['name'],
      brand: map['brand'],
      model: map['model'],
      deviceType: DeviceType.values.firstWhere(
        (e) => e.toString() == map['deviceType'],
      ),
      macAddress: map['macAddress'],
      isConnected: map['isConnected'] ?? false,
      lastSyncTime: map['lastSyncTime'] != null
          ? (map['lastSyncTime'] as Timestamp).toDate()
          : null,
      capabilities: map['capabilities'],
    );
  }
}

enum DeviceType {
  smartwatch,
  fitnessBand,
  heartRateMonitor,
  other
}
