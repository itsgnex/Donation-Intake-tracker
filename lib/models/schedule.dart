import 'package:cloud_firestore/cloud_firestore.dart';

class Schedule {
  final String id;
  final String storeId;
  final String storeName;
  final Timestamp pickupDate;
  final String timeWindow;
  final String status;
  final String? volunteerId;
  final String? volunteerName;

  Schedule({
    required this.id,
    required this.storeId,
    required this.storeName,
    required this.pickupDate,
    required this.timeWindow,
    required this.status,
    this.volunteerId,
    this.volunteerName,
  });

  factory Schedule.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Schedule(
      id: doc.id,
      storeId: data['storeId'] ?? '',
      storeName: data['storeName'] ?? '',
      pickupDate: data['pickupDate'] as Timestamp? ?? Timestamp.now(),
      timeWindow: data['timeWindow'] ?? '',
      status: data['status'] ?? 'scheduled',
      volunteerId: data['volunteerId'],
      volunteerName: data['volunteerName'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'storeId': storeId,
      'storeName': storeName,
      'pickupDate': pickupDate,
      'timeWindow': timeWindow,
      'status': status,
      'volunteerId': volunteerId,
      'volunteerName': volunteerName,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
