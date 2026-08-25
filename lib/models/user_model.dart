import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';

class UserModel {
  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.phone = '',
    this.address = '',
    this.disabled = false,
    this.createdAt,
  });

  final String uid;
  final String name;
  final String email;
  final String role;
  final String phone;
  final String address;
  final bool disabled;
  final DateTime? createdAt;

  bool get isAdmin => role == Roles.admin;
  bool get isStaff => role == Roles.staff;
  bool get isCustomer => role == Roles.customer;

  factory UserModel.fromDoc(DocumentSnapshot doc) {
    final Map<String, dynamic> d = doc.data() as Map<String, dynamic>? ?? {};
    return UserModel(
      uid: doc.id,
      name: (d['name'] ?? '') as String,
      email: (d['email'] ?? '') as String,
      role: (d['role'] ?? Roles.customer) as String,
      phone: (d['phone'] ?? '') as String,
      address: (d['address'] ?? '') as String,
      disabled: (d['disabled'] ?? false) as bool,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toCreateMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'role': role,
      'phone': phone,
      'address': address,
      'disabled': false,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> profileUpdateMap({required String name, required String phone, required String address}) {
    return {
      'name': name,
      'phone': phone,
      'address': address,
    };
  }

  Map<String, dynamic> customerProfileUpdateMap() {
    return {
      'fullName': name,
      'contactNumber': phone,
      'address': address,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  String initials() {
    final List<String> parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}
