import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';
import '../models/app_notification_model.dart';

class NotificationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<AppNotification>> streamForUser(String userId) {
    return _db
        .collection(Collections.notifications)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snap) => snap.docs
            .map(AppNotification.fromDoc)
            .toList()
              ..sort((a, b) =>
                  (b.createdAt ?? DateTime(1970)).compareTo(a.createdAt ?? DateTime(1970))));
  }

  Future<void> markRead(String notificationId) {
    return _db
        .collection(Collections.notifications)
        .doc(notificationId)
        .update({'read': true});
  }

  Future<void> markAllRead(List<AppNotification> notifications) async {
    final WriteBatch batch = _db.batch();
    for (final AppNotification n in notifications.where((n) => !n.read)) {
      batch.update(_db.collection(Collections.notifications).doc(n.id), {'read': true});
    }
    await batch.commit();
  }
}
