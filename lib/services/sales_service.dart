import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';
import '../core/utils/formatters.dart' show DateOnly;
import '../models/sale_model.dart';

class SalesService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<SaleModel>> streamSales() {
    return _db
        .collection(Collections.sales)
        .snapshots()
        .map((snap) => snap.docs
            .map(SaleModel.fromDoc)
            .toList()
              ..sort((a, b) =>
                  (b.createdAt ?? DateTime(1970)).compareTo(a.createdAt ?? DateTime(1970))));
  }

  Stream<List<SaleModel>> streamSalesByCustomer(String customerId) {
    return _db
        .collection(Collections.sales)
        .where('customerId', isEqualTo: customerId)
        .snapshots()
        .map((snap) => snap.docs
            .map(SaleModel.fromDoc)
            .toList()
              ..sort((a, b) =>
                  (b.createdAt ?? DateTime(1970)).compareTo(a.createdAt ?? DateTime(1970))));
  }

  Future<String> recordSale(SaleModel sale) async {
    final DocumentReference ref =
        await _db.collection(Collections.sales).add(sale.toMap());
    return ref.id;
  }

  static double total(List<SaleModel> sales) =>
      sales.fold(0.0, (acc, s) => acc + s.amount);

  static double totalForDay(List<SaleModel> sales, DateTime day) {
    final DateTime d = day.dateOnly;
    return total(sales.where((s) {
      final DateTime sd = (s.createdAt ?? DateTime(1970)).dateOnly;
      return sd.isAtSameMomentAs(d);
    }).toList());
  }

  static Map<DateTime, double> byDay(List<SaleModel> sales, int lastDays) {
    final DateTime today = DateTime.now().dateOnly;
    final Map<DateTime, double> result = {};
    for (int i = lastDays - 1; i >= 0; i--) {
      result[today.subtract(Duration(days: i))] = 0;
    }
    for (final SaleModel s in sales) {
      final DateTime key = (s.createdAt ?? today).dateOnly;
      if (result.containsKey(key)) {
        result[key] = result[key]! + s.amount;
      }
    }
    return result;
  }

  static Map<int, double> byWeek(List<SaleModel> sales, int lastWeeks) {
    final DateTime now = DateTime.now();
    final Map<int, double> result = {};
    for (int i = lastWeeks - 1; i >= 0; i--) {
      result[i] = 0;
    }
    for (final SaleModel s in sales) {
      final DateTime dt = s.createdAt ?? now;
      final int weeksAgo =
          ((now.difference(dt).inDays) / 7).floor();
      if (weeksAgo >= 0 && weeksAgo < lastWeeks) {
        result[weeksAgo] = result[weeksAgo]! + s.amount;
      }
    }
    return result;
  }

  static Map<String, double> byMonth(List<SaleModel> sales, int lastMonths) {
    final DateTime now = DateTime.now();
    final Map<String, double> result = {};
    for (int i = lastMonths - 1; i >= 0; i--) {
      final DateTime m = DateTime(now.year, now.month - i);
      result['${m.year}-${m.month.toString().padLeft(2, '0')}'] = 0;
    }
    for (final SaleModel s in sales) {
      final DateTime dt = s.createdAt ?? now;
      final String key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
      if (result.containsKey(key)) {
        result[key] = result[key]! + s.amount;
      }
    }
    return result;
  }

  static List<SaleModel> inRange(List<SaleModel> sales, DateTime from, DateTime to) {
    return sales.where((s) {
      final DateTime d = s.createdAt ?? DateTime(1970);
      return !d.isBefore(from) && !d.isAfter(to);
    }).toList();
  }
}
