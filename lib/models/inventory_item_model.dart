import 'package:cloud_firestore/cloud_firestore.dart';

class InventoryItemModel {
  const InventoryItemModel({
    required this.id,
    required this.name,
    required this.category,
    required this.unitPrice,
    required this.quantityOnHand,
    required this.reorderLevel,
    this.unitLabel = 'pcs',
    DateTime? updatedAt,
  }) : updatedAt = updatedAt;

  final String id;
  final String name;
  final String category;
  final double unitPrice;
  final int quantityOnHand;
  final int reorderLevel;
  final String unitLabel;
  final DateTime? updatedAt;

  bool get isLowStock => quantityOnHand <= reorderLevel;

  factory InventoryItemModel.fromDoc(DocumentSnapshot doc) {
    final Map<String, dynamic> d = doc.data() as Map<String, dynamic>? ?? {};
    return InventoryItemModel(
      id: doc.id,
      name: (d['name'] ?? '') as String,
      category: (d['category'] ?? '') as String,
      unitPrice: d['unitPrice'] is num
          ? (d['unitPrice'] as num).toDouble()
          : double.tryParse('${d['unitPrice']}') ?? 0,
      quantityOnHand: (d['quantityOnHand'] ?? 0) as int,
      reorderLevel: (d['reorderLevel'] ?? 0) as int,
      unitLabel: (d['unitLabel'] ?? 'pcs') as String,
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'category': category,
      'unitPrice': unitPrice,
      'quantityOnHand': quantityOnHand,
      'reorderLevel': reorderLevel,
      'unitLabel': unitLabel,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
