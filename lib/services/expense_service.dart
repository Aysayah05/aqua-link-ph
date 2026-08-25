import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';
import '../models/expense_model.dart';

class ExpenseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<ExpenseModel>> streamExpenses() {
    return _db
        .collection(Collections.expenses)
        .snapshots()
        .map((snap) => snap.docs
            .map(ExpenseModel.fromDoc)
            .toList()
              ..sort((a, b) => b.spentAt.compareTo(a.spentAt)));
  }

  Future<String> addExpense(ExpenseModel expense) async {
    final DocumentReference ref =
        await _db.collection(Collections.expenses).add(expense.toMap());
    return ref.id;
  }

  Future<void> updateExpense(String id, ExpenseModel expense) {
    return _db
        .collection(Collections.expenses)
        .doc(id)
        .update({
      'title': expense.title,
      'category': expense.category,
      'amount': expense.amount,
      'spentAt': Timestamp.fromDate(expense.spentAt),
      'notes': expense.notes,
    });
  }

  Future<void> deleteExpense(String id) {
    return _db.collection(Collections.expenses).doc(id).delete();
  }

  static double totalInMonth(List<ExpenseModel> expenses, DateTime month) {
    return expenses
        .where((e) =>
            e.spentAt.year == month.year && e.spentAt.month == month.month)
        .fold(0.0, (acc, e) => acc + e.amount);
  }

  static double totalInRange(List<ExpenseModel> expenses, DateTime from, DateTime to) {
    return total(
        expenses.where((e) =>
            !e.spentAt.isBefore(from) &&
            !e.spentAt.isAfter(to.add(const Duration(days: 1)))).toList());
  }

  static double total(List<ExpenseModel> expenses) =>
      expenses.fold(0.0, (acc, e) => acc + e.amount);

  static Map<String, double> byCategory(List<ExpenseModel> expenses) {
    final Map<String, double> result = {};
    for (final ExpenseModel e in expenses) {
      result[e.category] = (result[e.category] ?? 0) + e.amount;
    }
    final List<MapEntry<String, double>> sorted = result.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sorted);
  }
}
