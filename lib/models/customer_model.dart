import 'package:cloud_firestore/cloud_firestore.dart';

class CustomerModel {
  const CustomerModel({
    required this.id,
    this.userId,
    required this.fullName,
    required this.contactNumber,
    required this.address,
    this.notes = '',
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt,
        updatedAt = updatedAt;

  final String id;
  final String? userId;
  final String fullName;
  final String contactNumber;
  final String address;
  final String notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get hasAccount => userId != null && userId!.isNotEmpty;

  factory CustomerModel.fromDoc(DocumentSnapshot doc) {
    final Map<String, dynamic> d = doc.data() as Map<String, dynamic>? ?? {};
    return CustomerModel(
      id: doc.id,
      userId: (d['userId'] as String?)?.isEmpty == true ? null : d['userId'] as String?,
      fullName: (d['fullName'] ?? '') as String,
      contactNumber: (d['contactNumber'] ?? '') as String,
      address: (d['address'] ?? '') as String,
      notes: (d['notes'] ?? '') as String,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'fullName': fullName,
      'contactNumber': contactNumber,
      'address': address,
      'notes': notes,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return {
      'fullName': fullName,
      'contactNumber': contactNumber,
      'address': address,
      'notes': notes,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  String initials() {
    final List<String> parts =
        fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  CustomerModel copyWith({
    String? id,
    String? userId,
    String? fullName,
    String? contactNumber,
    String? address,
    String? notes,
  }) {
    return CustomerModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      fullName: fullName ?? this.fullName,
      contactNumber: contactNumber ?? this.contactNumber,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
