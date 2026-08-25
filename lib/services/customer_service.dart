import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';
import '../models/customer_model.dart';

class CustomerService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<CustomerModel>> streamCustomers() {
    return _db
        .collection(Collections.customers)
        .snapshots()
        .map((snap) =>
            snap.docs.map(CustomerModel.fromDoc).toList()
              ..sort((a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase())));
  }

  Future<List<CustomerModel>> fetchCustomersOnce() async {
    final QuerySnapshot snap = await _db.collection(Collections.customers).get();
    return snap.docs.map(CustomerModel.fromDoc).toList();
  }

  Stream<CustomerModel?> streamCustomer(String id) {
    return _db
        .collection(Collections.customers)
        .doc(id)
        .snapshots()
        .map((doc) => doc.exists ? CustomerModel.fromDoc(doc) : null);
  }

  Future<String> addWalkInCustomer({
    required String fullName,
    required String contactNumber,
    required String address,
    String notes = '',
  }) async {
    final DocumentReference ref = await _db.collection(Collections.customers).add(
          CustomerModel(
            id: '',
            fullName: fullName.trim(),
            contactNumber: contactNumber.trim(),
            address: address.trim(),
            notes: notes,
          ).toMap(),
        );
    return ref.id;
  }

  Future<void> updateCustomer(String id, CustomerModel customer) {
    return _db
        .collection(Collections.customers)
        .doc(id)
        .update(customer.toUpdateMap());
  }

  Future<CustomerModel?> getCustomerById(String id) async {
    final DocumentSnapshot doc =
        await _db.collection(Collections.customers).doc(id).get();
    if (!doc.exists) return null;
    return CustomerModel.fromDoc(doc);
  }
}
