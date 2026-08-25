import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';
import '../models/order_model.dart';
import '../models/sale_model.dart';

class OrderService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<OrderModel>> streamOrders({String? status, String? userId}) {
    Query<Map<String, dynamic>> query = _db.collection(Collections.orders) as Query<Map<String, dynamic>>;
    if (status != null && status.isNotEmpty) {
      query = query.where('status', isEqualTo: status);
    }
    if (userId != null && userId.isNotEmpty) {
      query = query.where('userId', isEqualTo: userId);
    }
    return query.snapshots().map((snap) => snap.docs
        .map(OrderModel.fromDoc)
        .toList()
          ..sort((a, b) => (b.createdAt ?? DateTime(1970)).compareTo(a.createdAt ?? DateTime(1970))));
  }

  Stream<List<OrderModel>> streamOrdersByCustomer(String customerId) {
    return _db
        .collection(Collections.orders)
        .where('customerId', isEqualTo: customerId)
        .snapshots()
        .map((snap) => snap.docs
            .map(OrderModel.fromDoc)
            .toList()
              ..sort((a, b) =>
                  (b.createdAt ?? DateTime(1970)).compareTo(a.createdAt ?? DateTime(1970))));
  }

  Future<String> placeOrder(OrderModel order) async {
    final DocumentReference ref =
        await _db.collection(Collections.orders).add(order.toCreateMap());
    return ref.id;
  }

  Future<void> updateStatus(String orderId, String newStatus) async {
    final Map<String, dynamic> update = {
      'status': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (newStatus == OrderStatus.delivered) {
      update['deliveredAt'] = FieldValue.serverTimestamp();
    }
    if (newStatus != OrderStatus.inTransit) {
      update['driverNearby'] = false;
    }
    await _db.collection(Collections.orders).doc(orderId).update(update);
  }

  Future<void> setDriverNearby(String orderId, String userId, bool nearby) async {
    await _db.collection(Collections.orders).doc(orderId).update({
      'driverNearby': nearby,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (nearby && userId.isNotEmpty) {
      await _db.collection(Collections.notifications).add({
        'userId': userId,
        'orderId': orderId,
        'type': 'near_arrival',
        'title': 'Delivery is near',
        'body': 'Your water delivery is arriving at your location in a few minutes.',
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> markPaid({
    required String orderId,
    required String paymentMethod,
    required SaleModel sale,
  }) async {
    final WriteBatch batch = _db.batch();
    batch.update(_db.collection(Collections.orders).doc(orderId), {
      'paymentStatus': PaymentStatus.paid,
      'paymentMethod': paymentMethod,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(_db.collection(Collections.sales).doc(), sale.toMap());
    await batch.commit();
  }

  Future<void> cancelOrder(String orderId) {
    return _db.collection(Collections.orders).doc(orderId).update({
      'status': OrderStatus.cancelled,
      'driverNearby': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<OrderModel>> streamUnpaidOrders() {
    return _db
        .collection(Collections.orders)
        .where('paymentStatus', isEqualTo: PaymentStatus.unpaid)
        .snapshots()
        .map((snap) => snap.docs
            .map(OrderModel.fromDoc)
            .where((o) =>
                o.status == OrderStatus.delivered || o.status == OrderStatus.inTransit)
            .toList()
              ..sort((a, b) =>
                  (b.createdAt ?? DateTime(1970)).compareTo(a.createdAt ?? DateTime(1970))));
  }
}
