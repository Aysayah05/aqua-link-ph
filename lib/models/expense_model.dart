import 'package:cloud_firestore/cloud_firestore.dart';

class ExpenseModel {
  const ExpenseModel({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.spentAt,
    required this.createdByName,
    this.notes = '',
    DateTime? createdAt,
  }) : createdAt = createdAt;

  final String id;
  final String title;
  final String category;
  final double amount;
  final DateTime spentAt;
  final String createdByName;
  final String notes;
  final DateTime? createdAt;

  factory ExpenseModel.fromDoc(DocumentSnapshot doc) {
    final Map<String, dynamic> d = doc.data() as Map<String, dynamic>? ?? {};
    return ExpenseModel(
      id: doc.id,
      title: (d['title'] ?? '') as String,
      category: (d['category'] ?? 'Others') as String,
      amount: d['amount'] is num
          ? (d['amount'] as num).toDouble()
          : double.tryParse('${d['amount']}') ?? 0,
      spentAt: (d['spentAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdByName: (d['createdByName'] ?? '') as String,
      notes: (d['notes'] ?? '') as String,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'category': category,
      'amount': amount,
      'spentAt': Timestamp.fromDate(spentAt),
      'createdByName': createdByName,
      'notes': notes,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

