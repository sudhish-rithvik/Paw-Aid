// lib/data/models/ngo_model.dart

class NgoModel {
  final String id;
  final String name;
  final String registrationNumber;
  final String email;
  final String phone;
  final String city;
  final String state;
  final String address;
  final double latitude;
  final double longitude;
  final double serviceRadiusKm;
  final List<String> specializations;
  final String status; // 'pending' | 'approved' | 'rejected'
  final String? rejectionReason;
  final int numVehicles;
  final int numVolunteers;
  final int activeCasesCount;
  final int totalRescued;
  final double successRate;

  const NgoModel({
    required this.id,
    required this.name,
    required this.registrationNumber,
    required this.email,
    required this.phone,
    required this.city,
    required this.state,
    required this.address,
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.serviceRadiusKm = 25.0,
    required this.specializations,
    required this.status,
    this.rejectionReason,
    this.numVehicles = 0,
    this.numVolunteers = 0,
    this.activeCasesCount = 0,
    this.totalRescued = 0,
    this.successRate = 0.95,
  });

  bool get isApproved => status == 'approved';

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'registration_number': registrationNumber,
        'email': email,
        'phone': phone,
        'city': city,
        'state': state,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'service_radius_km': serviceRadiusKm,
        'specializations': specializations,
        'status': status,
        'rejection_reason': rejectionReason,
        'num_vehicles': numVehicles,
        'num_volunteers': numVolunteers,
        'active_cases_count': activeCasesCount,
        'total_rescued': totalRescued,
        'success_rate': successRate,
      };

  factory NgoModel.fromMap(Map<String, dynamic> map, [String? docId]) => NgoModel(
        id: docId ?? map['id'] ?? map['ngoId'] ?? '',
        name: map['name'] ?? map['organizationName'] ?? '',
        registrationNumber: map['registration_number'] ?? map['registrationNumber'] ?? '',
        email: map['email'] ?? '',
        phone: map['phone'] ?? '',
        city: map['city'] ?? 'Chennai',
        state: map['state'] ?? 'Tamil Nadu',
        address: map['address'] ?? '',
        latitude: (map['latitude'] ?? map['lat'] ?? 13.0827 as num).toDouble(),
        longitude: (map['longitude'] ?? map['lng'] ?? 80.2707 as num).toDouble(),
        serviceRadiusKm: (map['service_radius_km'] ?? map['serviceRadiusKm'] ?? 30.0 as num).toDouble(),
        specializations: List<String>.from(map['specializations'] ?? ['Dog', 'Cat']),
        status: (map['status'] ?? map['verificationStatus'] ?? 'pending').toString().toLowerCase(),
        rejectionReason: map['rejection_reason'] ?? map['rejectionReason'],
        numVehicles: (map['num_vehicles'] ?? map['numVehicles'] ?? 0 as num).toInt(),
        numVolunteers: (map['num_volunteers'] ?? map['numVolunteers'] ?? 0 as num).toInt(),
        activeCasesCount: (map['active_cases_count'] ?? map['activeRescuesCount'] ?? 0 as num).toInt(),
        totalRescued: (map['total_rescued'] ?? map['totalRescuesCount'] ?? 0 as num).toInt(),
        successRate: (map['success_rate'] ?? map['successRate'] ?? 0.95 as num).toDouble(),
      );
}
