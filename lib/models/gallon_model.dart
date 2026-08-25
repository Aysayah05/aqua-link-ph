import 'package:cloud_firestore/cloud_firestore.dart';

class GallonModel {
  const GallonModel({
    required this.id,
    required this.qrCodeValue,
    required this.status,
    this.currentCustomerId,
    this.currentCustomerName,
    this.currentOrderId,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt,
        updatedAt = updatedAt;

  final String id;
  final String qrCodeValue;
  final String status;
  final String? currentCustomerId;
  final String? currentCustomerName;
  final String? currentOrderId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isActiveUse =>
      status == 'assigned' || status == 'out_for_delivery' || status == 'with_customer';

  factory GallonModel.fromDoc(DocumentSnapshot doc) {
    final Map<String, dynamic> d = doc.data() as Map<String, dynamic>? ?? {};
    return GallonModel(
      id: doc.id,
      qrCodeValue: (d['qrCodeValue'] ?? '') as String,
      status: (d['status'] ?? 'available') as String,
      currentCustomerId: d['currentCustomerId'] as String?,
      currentCustomerName: d['currentCustomerName'] as String?,
      currentOrderId: d['currentOrderId'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toCreateMap() {
    return {
      'gallonId': id,
      'qrCodeValue': qrCodeValue,
      'status': status,
      'currentCustomerId': currentCustomerId,
      'currentCustomerName': currentCustomerName,
      'currentOrderId': currentOrderId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> statusUpdateMap({
    required String newStatus,
    String? customerId,
    String? customerName,
    String? orderId,
  }) {
    return {
      'status': newStatus,
      'currentCustomerId': customerId,
      'currentCustomerName': customerName,
      'currentOrderId': orderId,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

class GallonHistoryEntry {
  const GallonHistoryEntry({
    required this.id,
    required this.action,
    required this.toStatus,
    this.fromStatus,
    this.byUserName,
    this.customerName,
    this.orderId,
    this.note = '',
    this.timestamp,
  });

  final String id;
  final String action;
  final String? fromStatus;
  final String toStatus;
  final String? byUserName;
  final String? customerName;
  final String? orderId;
  final String note;
  final DateTime? timestamp;

  factory GallonHistoryEntry.fromDoc(DocumentSnapshot doc) {
    final Map<String, dynamic> d = doc.data() as Map<String, dynamic>? ?? {};
    return GallonHistoryEntry(
      id: doc.id,
      action: (d['action'] ?? '') as String,
      fromStatus: d['fromStatus'] as String?,
      toStatus: (d['toStatus'] ?? '') as String,
      byUserName: d['byUserName'] as String?,
      customerName: d['customerName'] as String?,
      orderId: d['orderId'] as String?,
      note: (d['note'] ?? '') as String,
      timestamp: (d['at'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'action': action,
      'fromStatus': fromStatus,
      'toStatus': toStatus,
      'byUserName': byUserName,
      'customerId': null,
      'customerName': customerName,
      'orderId': orderId,
      'note': note,
      'at': timestamp != null ? Timestamp.fromDate(timestamp!) : FieldValue.serverTimestamp(),
    };
  }
}
