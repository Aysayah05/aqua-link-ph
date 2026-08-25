import 'package:cloud_firestore/cloud_firestore.dart';

class SaleModel {
  const SaleModel({
    required this.id,
    required this.amount,
    required this.type,
    required this.paymentMethod,
    required this.recordedByName,
    this.orderId,
    this.customerId,
    this.customerName,
    this.productSummary = '',
    this.note = '',
    DateTime? createdAt,
  }) : createdAt = createdAt;

  final String id;
  final double amount;
  final String type;
  final String paymentMethod;
  final String recordedByName;
  final String? orderId;
  final String? customerId;
  final String? customerName;
  final String productSummary;
  final String note;
  final DateTime? createdAt;

  factory SaleModel.fromDoc(DocumentSnapshot doc) {
    final Map<String, dynamic> d = doc.data() as Map<String, dynamic>? ?? {};
    return SaleModel(
      id: doc.id,
      amount: d['amount'] is num
          ? (d['amount'] as num).toDouble()
          : double.tryParse('${d['amount']}') ?? 0,
      type: (d['type'] ?? 'walk_in') as String,
      paymentMethod: (d['paymentMethod'] ?? 'cash') as String,
      recordedByName: (d['recordedByName'] ?? '') as String,
      orderId: d['orderId'] as String?,
      customerId: d['customerId'] as String?,
      customerName: d['customerName'] as String?,
      productSummary: (d['productSummary'] ?? '') as String,
      note: (d['note'] ?? '') as String,
      createdAt: (d['soldAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'amount': amount,
      'type': type,
      'paymentMethod': paymentMethod,
      'recordedByName': recordedByName,
      'orderId': orderId,
      'customerId': customerId,
      'customerName': customerName,
      'productSummary': productSummary,
      'note': note,
      'soldAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }
}
