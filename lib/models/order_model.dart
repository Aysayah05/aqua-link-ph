import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';

class OrderModel {
  const OrderModel({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.customerAddress,
    required this.orderType,
    required this.productId,
    required this.productName,
    required this.unitPrice,
    required this.quantity,
    required this.totalAmount,
    required this.status,
    required this.paymentStatus,
    this.userId,
    this.contactNumber = '',
    this.deliveryRequest = '',
    this.paymentMethod,
    this.driverNearby = false,
    this.createdAt,
    this.updatedAt,
    this.deliveredAt,
  });

  final String id;
  final String customerId;
  final String? userId;
  final String customerName;
  final String customerPhone;
  final String customerAddress;
  final String orderType;
  final String productId;
  final String productName;
  final double unitPrice;
  final int quantity;
  final double totalAmount;
  final String status;
  final String paymentStatus;
  final String contactNumber;
  final String deliveryRequest;
  final String? paymentMethod;
  final bool driverNearby;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deliveredAt;

  double get subtotal => unitPrice * quantity;

  factory OrderModel.fromDoc(DocumentSnapshot doc) {
    final Map<String, dynamic> d = doc.data() as Map<String, dynamic>? ?? {};
    return OrderModel(
      id: doc.id,
      customerId: (d['customerId'] ?? '') as String,
      userId: d['userId'] as String?,
      customerName: (d['customerName'] ?? '') as String,
      customerPhone: (d['customerPhone'] ?? '') as String,
      customerAddress: (d['customerAddress'] ?? '') as String,
      orderType: (d['orderType'] ?? OrderType.delivery) as String,
      productId: (d['productId'] ?? '') as String,
      productName: (d['productName'] ?? '') as String,
      unitPrice: _toDouble(d['unitPrice']),
      quantity: (d['quantity'] ?? 0) as int,
      totalAmount: _toDouble(d['totalAmount']),
      status: (d['status'] ?? OrderStatus.pending) as String,
      paymentStatus: (d['paymentStatus'] ?? PaymentStatus.unpaid) as String,
      contactNumber: (d['contactNumber'] ?? '') as String,
      deliveryRequest: (d['deliveryRequest'] ?? '') as String,
      paymentMethod: d['paymentMethod'] as String?,
      driverNearby: (d['driverNearby'] ?? false) as bool,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
      deliveredAt: (d['deliveredAt'] as Timestamp?)?.toDate(),
    );
  }

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  Map<String, dynamic> toCreateMap() {
    return {
      'customerId': customerId,
      'userId': userId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'customerAddress': customerAddress,
      'orderType': orderType,
      'productId': productId,
      'productName': productName,
      'unitPrice': unitPrice,
      'quantity': quantity,
      'totalAmount': totalAmount,
      'status': status,
      'paymentStatus': paymentStatus,
      'contactNumber': contactNumber,
      'deliveryRequest': deliveryRequest,
      'driverNearby': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
