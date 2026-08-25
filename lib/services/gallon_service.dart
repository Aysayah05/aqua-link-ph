import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';
import '../models/gallon_model.dart';

class GallonService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<GallonModel>> streamGallons({String? status}) {
    Query<Map<String, dynamic>> query =
        _db.collection(Collections.gallons) as Query<Map<String, dynamic>>;
    if (status != null && status.isNotEmpty) {
      query = query.where('status', isEqualTo: status);
    }
    return query.snapshots().map(
        (snap) => snap.docs.map(GallonModel.fromDoc).toList()..sort((a, b) => a.id.compareTo(b.id)));
  }

  Stream<GallonModel?> streamGallonById(String id) {
    return _db
        .collection(Collections.gallons)
        .doc(id)
        .snapshots()
        .map((doc) => doc.exists ? GallonModel.fromDoc(doc) : null);
  }

  Stream<List<GallonModel>> streamGallonsForCustomer(String customerId) {
    return _db
        .collection(Collections.gallons)
        .where('currentCustomerId', isEqualTo: customerId)
        .snapshots()
        .map((snap) => snap.docs.map(GallonModel.fromDoc).toList());
  }

  Stream<List<GallonModel>> streamGallonsForOrder(String orderId) {
    return _db
        .collection(Collections.gallons)
        .where('currentOrderId', isEqualTo: orderId)
        .snapshots()
        .map((snap) => snap.docs.map(GallonModel.fromDoc).toList());
  }

  Future<GallonModel?> findByQrCode(String qrValue) async {
    final QuerySnapshot snap = await _db
        .collection(Collections.gallons)
        .where('qrCodeValue', isEqualTo: qrValue.trim())
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return GallonModel.fromDoc(snap.docs.first);
  }

  Future<List<String>> registerGallons(int count, {required String byUserName}) async {
    final List<String> created = [];
    int next = await _nextGallonNumber();
    for (int i = 0; i < count; i++) {
      final String code = 'GLN-${next.toString().padLeft(4, '0')}';
      final GallonModel gallon = GallonModel(id: code, qrCodeValue: code, status: GallonStatus.available);
      await _db.collection(Collections.gallons).doc(code).set(gallon.toCreateMap());
      await _writeHistory(code, GallonHistoryEntry(
        id: '',
        action: 'registered',
        toStatus: GallonStatus.available,
        byUserName: byUserName,
        note: 'Gallon registered to the system',
      ));
      created.add(code);
      next++;
    }
    return created;
  }

  Future<int> _nextGallonNumber() async {
    final QuerySnapshot snap = await _db
        .collection(Collections.gallons)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return 1;
    final String lastId = snap.docs.first.id;
    final RegExpMatch? match = RegExp(r'(\d+)').firstMatch(lastId);
    if (match == null) return snap.docs.length + 1;
    return (int.tryParse(match.group(1)!) ?? 0) + 1;
  }

  Future<bool> transitionGallon({
    required GallonModel gallon,
    required String newStatus,
    required String byUserName,
    String? customerName,
    String? note,
  }) async {
    final List<String> allowed =
        GallonStatus.allowedTransitions[gallon.status] ?? const [];
    if (!allowed.contains(newStatus)) {
      throw Exception(
          '${GallonStatus.label(gallon.status)} gallons cannot move to ${GallonStatus.label(newStatus)}.');
    }

    final bool clearsCustomer = newStatus == GallonStatus.available ||
        newStatus == GallonStatus.damaged ||
        newStatus == GallonStatus.lost;

    await _db
        .collection(Collections.gallons)
        .doc(gallon.id)
        .update(gallon.statusUpdateMap(
          newStatus: newStatus,
          customerId: clearsCustomer ? null : gallon.currentCustomerId,
          customerName: clearsCustomer ? null : (customerName ?? gallon.currentCustomerName),
          orderId: newStatus == GallonStatus.withCustomer ||
                  clearsCustomer
              ? (clearsCustomer ? null : gallon.currentOrderId)
              : gallon.currentOrderId,
        ));

    await _writeHistory(gallon.id, GallonHistoryEntry(
      id: '',
      action: 'status_change',
      fromStatus: gallon.status,
      toStatus: newStatus,
      byUserName: byUserName,
      customerName: customerName ?? gallon.currentCustomerName,
      orderId: gallon.currentOrderId,
      note: note ?? '',
    ));
    return true;
  }

  Future<void> assignGallonToOrder({
    required GallonModel gallon,
    required String orderId,
    required String customerId,
    required String customerName,
    required String byUserName,
  }) async {
    if (!GallonStatus.allowedTransitions[gallon.status]!.contains(GallonStatus.assigned)) {
      throw Exception('Gallon ${gallon.qrCodeValue} is ${GallonStatus.label(gallon.status)} and cannot be assigned.');
    }
    await _db.collection(Collections.gallons).doc(gallon.id).update(
          gallon.statusUpdateMap(
            newStatus: GallonStatus.assigned,
            customerId: customerId,
            customerName: customerName,
            orderId: orderId,
          ),
        );
    await _writeHistory(gallon.id, GallonHistoryEntry(
      id: '',
      action: 'assigned_to_order',
      fromStatus: gallon.status,
      toStatus: GallonStatus.assigned,
      byUserName: byUserName,
      customerName: customerName,
      orderId: orderId,
      note: 'Assigned for order $orderId',
    ));
  }

  Future<int> autoAssignGallons({
    required int count,
    required String orderId,
    required String customerId,
    required String customerName,
    required String byUserName,
  }) async {
    final QuerySnapshot available = await _db
        .collection(Collections.gallons)
        .where('status', isEqualTo: GallonStatus.available)
        .limit(count)
        .get();
    if (available.docs.length < count) {
      throw Exception(
          'Only ${available.docs.length} available gallons left. Register more gallons first.');
    }
    for (final QueryDocumentSnapshot doc in available.docs) {
      await assignGallonToOrder(
        gallon: GallonModel.fromDoc(doc),
        orderId: orderId,
        customerId: customerId,
        customerName: customerName,
        byUserName: byUserName,
      );
    }
    return available.docs.length;
  }

  Future<int> releaseOrderGallons({
    required String orderId,
    required String byUserName,
  }) async {
    final QuerySnapshot assigned = await _db
        .collection(Collections.gallons)
        .where('currentOrderId', isEqualTo: orderId)
        .where('status', whereIn: [GallonStatus.assigned, GallonStatus.outForDelivery])
        .get();
    for (final QueryDocumentSnapshot doc in assigned.docs) {
      await transitionGallon(
        gallon: GallonModel.fromDoc(doc),
        newStatus: GallonStatus.available,
        byUserName: byUserName,
        note: 'Released after order cancellation',
      );
    }
    return assigned.docs.length;
  }

  Future<void> deliverOrderGallons({required String orderId}) async {
    final QuerySnapshot moving = await _db
        .collection(Collections.gallons)
        .where('currentOrderId', isEqualTo: orderId)
        .where('status', isEqualTo: GallonStatus.outForDelivery)
        .get();
    for (final QueryDocumentSnapshot doc in moving.docs) {
      final GallonModel g = GallonModel.fromDoc(doc);
      await _db.collection(Collections.gallons).doc(g.id).update(
            g.statusUpdateMap(newStatus: GallonStatus.withCustomer),
          );
      await _writeHistory(g.id, GallonHistoryEntry(
        id: '',
        action: 'status_change',
        fromStatus: g.status,
        toStatus: GallonStatus.withCustomer,
        byUserName: 'system',
        customerName: g.currentCustomerName,
        orderId: orderId,
        note: 'Delivered with order',
      ));
    }
  }

  Future<void> advanceOrderGallons({
    required String orderId,
    required String toStatus,
    required String byUserName,
  }) async {
    final Map<String, String> sourceMap = {
      GallonStatus.assigned: GallonStatus.outForDelivery,
      GallonStatus.outForDelivery: GallonStatus.withCustomer,
    };
    final String? source = sourceMap[toStatus];
    if (source == null) return;
    final QuerySnapshot snap = await _db
        .collection(Collections.gallons)
        .where('currentOrderId', isEqualTo: orderId)
        .where('status', isEqualTo: source)
        .get();
    for (final QueryDocumentSnapshot doc in snap.docs) {
      final GallonModel g = GallonModel.fromDoc(doc);
      await _db.collection(Collections.gallons).doc(g.id).update(
            g.statusUpdateMap(newStatus: toStatus),
          );
      await _writeHistory(g.id, GallonHistoryEntry(
        id: '',
        action: 'status_change',
        fromStatus: g.status,
        toStatus: toStatus,
        byUserName: byUserName,
        customerName: g.currentCustomerName,
        orderId: orderId,
        note: '',
      ));
    }
  }

  Stream<List<GallonHistoryEntry>> streamHistory(String gallonId) {
    return _db
        .collection(Collections.gallons)
        .doc(gallonId)
        .collection(Collections.gallonHistory)
        .snapshots()
        .map((snap) => snap.docs
            .map(GallonHistoryEntry.fromDoc)
            .toList()
              ..sort((a, b) =>
                  (b.timestamp ?? DateTime(1970)).compareTo(a.timestamp ?? DateTime(1970))));
  }

  Future<void> _writeHistory(String gallonId, GallonHistoryEntry entry) {
    return _db
        .collection(Collections.gallons)
        .doc(gallonId)
        .collection(Collections.gallonHistory)
        .add(entry.toMap());
  }

  Future<Map<String, int>> countByStatus() async {
    final QuerySnapshot snap = await _db.collection(Collections.gallons).get();
    final Map<String, int> counts = {};
    for (final GallonModel g in snap.docs.map(GallonModel.fromDoc)) {
      counts[g.status] = (counts[g.status] ?? 0) + 1;
    }
    return counts;
  }
}
