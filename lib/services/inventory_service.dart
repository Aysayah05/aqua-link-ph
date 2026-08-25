import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';
import '../models/inventory_item_model.dart';

class InventoryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<InventoryItemModel>> streamItems() {
    return _db
        .collection(Collections.inventory)
        .snapshots()
        .map((snap) => snap.docs
            .map(InventoryItemModel.fromDoc)
            .toList()
              ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())));
  }

  Future<void> addItem(InventoryItemModel item) {
    return _db.collection(Collections.inventory).add(item.toMap());
  }

  Future<void> updateItem(String id, InventoryItemModel item) {
    return _db.collection(Collections.inventory).doc(id).update(item.toMap());
  }

  Future<void> adjustQuantity(String id, int delta) {
    return _db.collection(Collections.inventory).doc(id).update({
      'quantityOnHand': FieldValue.increment(delta),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteItem(String id) {
    return _db.collection(Collections.inventory).doc(id).delete();
  }
}
