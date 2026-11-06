// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

class SavedLocation {
  int? id;
  String name;
  bool isNamed;
  String type; // 'fuel_station', 'service_shop', 'both'
  double? latitude;
  double? longitude;
  double radiusMeters;
  bool isSuspectFuel;
  bool isSuspectServiceOrParts;
  String? suspectReason;
  bool isRecommendedFuel;
  bool isRecommendedServiceOrParts;
  String? performanceReason;
  double? rating;
  String? notes;
  DateTime createdAt;

  SavedLocation({
    this.id,
    required this.name,
    this.isNamed = false,
    this.type = 'fuel_station',
    this.latitude,
    this.longitude,
    this.radiusMeters = 80.0,
    this.isSuspectFuel = false,
    this.isSuspectServiceOrParts = false,
    this.suspectReason,
    this.isRecommendedFuel = false,
    this.isRecommendedServiceOrParts = false,
    this.performanceReason,
    this.rating,
    this.notes,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isSuspect => isSuspectFuel || isSuspectServiceOrParts;
  bool get isRecommended => isRecommendedFuel || isRecommendedServiceOrParts;

  String get displayName {
    if (isNamed && name.trim().isNotEmpty) {
      return name;
    }
    if (latitude != null && longitude != null) {
      return 'Unnamed (${latitude!.toStringAsFixed(4)}, ${longitude!.toStringAsFixed(4)})';
    }
    return 'Unnamed Location';
  }

  Map<String, dynamic> toMap() {
    var map = <String, dynamic>{
      'name': name,
      'isNamed': isNamed ? 1 : 0,
      'type': type,
      'latitude': latitude,
      'longitude': longitude,
      'radiusMeters': radiusMeters,
      'isSuspectFuel': isSuspectFuel ? 1 : 0,
      'isSuspectServiceOrParts': isSuspectServiceOrParts ? 1 : 0,
      'suspectReason': suspectReason,
      'isRecommendedFuel': isRecommendedFuel ? 1 : 0,
      'isRecommendedServiceOrParts': isRecommendedServiceOrParts ? 1 : 0,
      'performanceReason': performanceReason,
      'rating': rating,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
    };
    if (id != null) map['id'] = id;
    return map;
  }

  factory SavedLocation.fromMap(Map<String, dynamic> map) {
    return SavedLocation(
      id: map['id'] as int?,
      name: map['name'] as String? ?? 'Unnamed Location',
      isNamed: map['isNamed'] == 1 || map['isNamed'] == true,
      type: map['type'] as String? ?? 'fuel_station',
      latitude: map['latitude'] != null ? (map['latitude'] as num).toDouble() : null,
      longitude: map['longitude'] != null ? (map['longitude'] as num).toDouble() : null,
      radiusMeters: map['radiusMeters'] != null ? (map['radiusMeters'] as num).toDouble() : 80.0,
      isSuspectFuel: map['isSuspectFuel'] == 1 || map['isSuspectFuel'] == true,
      isSuspectServiceOrParts: map['isSuspectServiceOrParts'] == 1 || map['isSuspectServiceOrParts'] == true,
      suspectReason: map['suspectReason'] as String?,
      isRecommendedFuel: map['isRecommendedFuel'] == 1 || map['isRecommendedFuel'] == true,
      isRecommendedServiceOrParts: map['isRecommendedServiceOrParts'] == 1 || map['isRecommendedServiceOrParts'] == true,
      performanceReason: map['performanceReason'] as String?,
      rating: map['rating'] != null ? (map['rating'] as num).toDouble() : null,
      notes: map['notes'] as String?,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  SavedLocation copyWith({
    int? id,
    String? name,
    bool? isNamed,
    String? type,
    double? latitude,
    double? longitude,
    double? radiusMeters,
    bool? isSuspectFuel,
    bool? isSuspectServiceOrParts,
    String? suspectReason,
    bool? isRecommendedFuel,
    bool? isRecommendedServiceOrParts,
    String? performanceReason,
    double? rating,
    String? notes,
    DateTime? createdAt,
  }) {
    return SavedLocation(
      id: id ?? this.id,
      name: name ?? this.name,
      isNamed: isNamed ?? this.isNamed,
      type: type ?? this.type,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      isSuspectFuel: isSuspectFuel ?? this.isSuspectFuel,
      isSuspectServiceOrParts: isSuspectServiceOrParts ?? this.isSuspectServiceOrParts,
      suspectReason: suspectReason ?? this.suspectReason,
      isRecommendedFuel: isRecommendedFuel ?? this.isRecommendedFuel,
      isRecommendedServiceOrParts: isRecommendedServiceOrParts ?? this.isRecommendedServiceOrParts,
      performanceReason: performanceReason ?? this.performanceReason,
      rating: rating ?? this.rating,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
