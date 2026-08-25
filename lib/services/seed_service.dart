import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';
import '../models/order_model.dart';
import '../models/sale_model.dart';
import 'auth_service.dart';

class SeedResult {
  const SeedResult({required this.success, required this.message});
  final bool success;
  final String message;
}

class SeedService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Random _rng = Random();

  String? pendingOrderId;
  String? confirmedOrderId;
  String? transitOrderId;

  Future<SeedResult> seedAll() async {
    try {
      final QuerySnapshot existing =
          await _db.collection(Collections.orders).limit(1).get();
      if (existing.docs.isNotEmpty) {
        return const SeedResult(
            success: false,
            message: 'Demo data already exists (orders found). Seeding was skipped.');
      }

      final List<SeedProduct> products = await _seedInventory();
      final Map<String, String> customers = await _seedWalkInCustomers();
      await _seedAccounts(customers);
      await _seedHistoricalOrders(products, customers);
      await _seedActiveOrders(products, customers);
      await _seedGallons(customers);

      return const SeedResult(
        success: true,
        message: 'Demo data created successfully!\n\n'
            'Products, 6 customers, ~90 orders & sales (35 days),\n'
            '30 QR gallons, expenses.\n\n'
            'Demo logins (password Aqua123!):\n'
            'staff@aquaph.test · maria@aquaph.test',
      );
    } catch (e) {
      return SeedResult(success: false, message: 'Seeding failed: $e');
    }
  }

  Future<List<SeedProduct>> _seedInventory() async {
    const List<Map<String, dynamic>> items = [
      {'name': 'Purified Water (Round 5-gal)', 'category': 'Refill', 'unitPrice': 40.0, 'quantityOnHand': 120, 'reorderLevel': 20, 'unitLabel': 'gallons'},
      {'name': 'Distilled Water (Round 5-gal)', 'category': 'Refill', 'unitPrice': 45.0, 'quantityOnHand': 85, 'reorderLevel': 20, 'unitLabel': 'gallons'},
      {'name': 'Alkaline Water (Round 5-gal)', 'category': 'Refill', 'unitPrice': 55.0, 'quantityOnHand': 14, 'reorderLevel': 15, 'unitLabel': 'gallons'},
      {'name': 'Empty Round Containers', 'category': 'Containers', 'unitPrice': 350.0, 'quantityOnHand': 60, 'reorderLevel': 10, 'unitLabel': 'pcs'},
      {'name': 'Bottle Caps & Seals', 'category': 'Supplies', 'unitPrice': 5.0, 'quantityOnHand': 480, 'reorderLevel': 100, 'unitLabel': 'pcs'},
    ];
    final List<SeedProduct> result = [];
    for (final Map<String, dynamic> item in items) {
      final DocumentReference ref = await _db
          .collection(Collections.inventory)
          .add(<String, dynamic>{...item, 'updatedAt': FieldValue.serverTimestamp()});
      result.add(SeedProduct(id: ref.id, name: item['name'] as String, price: item['unitPrice'] as double));
    }
    return result;
  }

  Future<Map<String, String>> _seedWalkInCustomers() async {
    const List<Map<String, String>> people = [
      {'fullName': 'Juan Dela Cruz', 'contactNumber': '09171230002', 'address': '45 Mabini Ave., Purok 3'},
      {'fullName': 'Ana Reyes', 'contactNumber': '09171230003', 'address': '8 Bonifacio Rd., Brgy. Malinao'},
      {'fullName': 'Carlo Mendoza', 'contactNumber': '09171230004', 'address': '23 Aguinaldo Hwy., Purok 5'},
      {'fullName': 'Grace Lim', 'contactNumber': '09171230005', 'address': '77 Luna St., Brgy. Poblacion'},
      {'fullName': 'Rico Torres', 'contactNumber': '09171230006', 'address': '31 Magsaysay Dr., Purok 2'},
    ];
    final Map<String, String> idsByName = {};
    for (final Map<String, String> p in people) {
      final DocumentReference ref =
          await _db.collection(Collections.customers).add(<String, dynamic>{
        'userId': null,
        ...p,
        'notes': '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      idsByName[p['fullName']!] = ref.id;
    }
    return idsByName;
  }

  Future<String?> _seedAccounts(Map<String, String> customers) async {
    final AuthService auth = AuthService();
    await auth.createStaffAccount(
      name: 'Miguel Ramos',
      email: 'staff@aquaph.test',
      password: 'Aqua123!',
      role: Roles.staff,
      phone: '09171231001',
    );
    final AuthResult maria = await auth.createStaffAccount(
      name: 'Maria Santos',
      email: 'maria@aquaph.test',
      password: 'Aqua123!',
      role: Roles.customer,
      phone: '09171230001',
    );
    if (!maria.success) return null;
    final QuerySnapshot snap = await _db
        .collection(Collections.users)
        .where('email', isEqualTo: 'maria@aquaph.test')
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final String uid = snap.docs.first.id;
    await _db.collection(Collections.customers).doc(uid).set(<String, dynamic>{
      'userId': uid,
      'fullName': 'Maria Santos',
      'contactNumber': '09171230001',
      'address': '12 Rizal St., Brgy. San Isidro',
      'notes': '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    customers['Maria Santos'] = uid;
    return uid;
  }

  Future<void> _seedHistoricalOrders(
      List<SeedProduct> products, Map<String, String> customers) async {
    final DateTime now = DateTime.now();
    final List<String> names = customers.keys.toList();

    for (int daysAgo = 34; daysAgo >= 1; daysAgo--) {
      final int ordersToday = 2 + _rng.nextInt(2);
      for (int i = 0; i < ordersToday; i++) {
        final DateTime when = now.subtract(Duration(days: daysAgo, hours: 1 + _rng.nextInt(9)));
        final String name = names[_rng.nextInt(names.length)];
        final SeedProduct product = products[_rng.nextInt(2)];
        final int qty = 1 + _rng.nextInt(3);
        final bool delivery = _rng.nextBool();
        final double total =
            product.price * qty + (delivery ? AppConstants.deliveryFee : 0);
        final String method =
            _rng.nextBool() ? PaymentMethod.cash : PaymentMethod.gcash;

        final DocumentReference ref =
            await _db.collection(Collections.orders).add(OrderModel(
                  id: '',
                  customerId: customers[name]!,
                  customerName: name,
                  customerPhone: '09${_rng.nextInt(900000000 + 100000000)}',
                  customerAddress: 'Seeded address $daysAgo-$i',
                  orderType: delivery ? OrderType.delivery : OrderType.walkIn,
                  productId: product.id,
                  productName: product.name,
                  unitPrice: product.price,
                  quantity: qty,
                  totalAmount: total,
                  status: OrderStatus.delivered,
                  paymentStatus: PaymentStatus.paid,
                  contactNumber: '09171230001',
                  deliveryRequest: '',
                  paymentMethod: method,
                  createdAt: when,
                  updatedAt: when,
                  deliveredAt: when.add(const Duration(hours: 2)),
                ).toCreateMap());

        await _db.collection(Collections.sales).add(SaleModel(
              id: '',
              amount: total,
              type: delivery ? OrderType.delivery : OrderType.walkIn,
              paymentMethod: method,
              recordedByName: 'Miguel Ramos',
              orderId: ref.id,
              customerId: customers[name],
              customerName: name,
              productSummary: '${product.name} × $qty',
              createdAt: when,
            ).toMap());
      }
    }

    for (int i = 0; i < 26; i++) {
      final DateTime when =
          now.subtract(Duration(days: _rng.nextInt(35), hours: 1 + _rng.nextInt(10)));
      final double amount = (1 + _rng.nextInt(4)) * 40.0;
      await _db.collection(Collections.sales).add(SaleModel(
            id: '',
            amount: amount,
            type: OrderType.walkIn,
            paymentMethod: _rng.nextBool() ? PaymentMethod.cash : PaymentMethod.gcash,
            recordedByName: 'Miguel Ramos',
            customerName: 'Walk-in Customer',
            productSummary: 'Purified Water (Round 5-gal)',
            createdAt: when,
          ).toMap());
    }
  }

  Future<void> _seedActiveOrders(
      List<SeedProduct> products, Map<String, String> customers) async {
    final DateTime now = DateTime.now();
    final String? mariaUid = customers['Maria Santos'];

    Future<String> makeOrder({
      required String name,
      required String status,
      required String paymentStatus,
      required Duration age,
      bool driverNearby = false,
    }) async {
      final SeedProduct product = products.first;
      const int qty = 2;
      final double total =
          product.price * qty + AppConstants.deliveryFee;
      final DocumentReference ref =
          await _db.collection(Collections.orders).add(OrderModel(
                id: '',
                customerId: customers[name]!,
                userId: name == 'Maria Santos' ? mariaUid : null,
                customerName: name,
                customerPhone: '09171230001',
                customerAddress: name == 'Maria Santos'
                    ? '12 Rizal St., Brgy. San Isidro'
                    : 'Seeded active order address',
                orderType: OrderType.delivery,
                productId: product.id,
                productName: product.name,
                unitPrice: product.price,
                quantity: qty,
                totalAmount: total,
                status: status,
                paymentStatus: paymentStatus,
                contactNumber: '09171230001',
                deliveryRequest: 'Call upon arrival',
                driverNearby: driverNearby,
                createdAt: now.subtract(age),
                updatedAt: now.subtract(age),
              ).toCreateMap());
      return ref.id;
    }

    pendingOrderId = await makeOrder(
        name: 'Juan Dela Cruz',
        status: OrderStatus.pending,
        paymentStatus: PaymentStatus.unpaid,
        age: const Duration(minutes: 25));
    await makeOrder(
        name: 'Grace Lim',
        status: OrderStatus.pending,
        paymentStatus: PaymentStatus.unpaid,
        age: const Duration(hours: 1));
    confirmedOrderId = await makeOrder(
        name: 'Ana Reyes',
        status: OrderStatus.confirmed,
        paymentStatus: PaymentStatus.unpaid,
        age: const Duration(hours: 2));
    final String preparingOrderId = await makeOrder(
        name: 'Carlo Mendoza',
        status: OrderStatus.preparing,
        paymentStatus: PaymentStatus.unpaid,
        age: const Duration(hours: 3));
    transitOrderId = await makeOrder(
        name: 'Maria Santos',
        status: OrderStatus.inTransit,
        paymentStatus: PaymentStatus.unpaid,
        age: const Duration(hours: 4),
        driverNearby: true);
    await makeOrder(
        name: 'Rico Torres',
        status: OrderStatus.delivered,
        paymentStatus: PaymentStatus.paid,
        age: const Duration(hours: 6));

    if (mariaUid != null && transitOrderId != null) {
      await _db.collection(Collections.notifications).add(<String, dynamic>{
        'userId': mariaUid,
        'orderId': transitOrderId,
        'type': 'near_arrival',
        'title': 'Delivery is near',
        'body': 'Your water delivery is arriving at your location in a few minutes.',
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    gallonPlan = <GallonSeed>[
      GallonSeed('GLN-0001', GallonStatus.assigned, pendingOrderId, 'Juan Dela Cruz'),
      GallonSeed('GLN-0002', GallonStatus.assigned, pendingOrderId, 'Juan Dela Cruz'),
      GallonSeed('GLN-0003', GallonStatus.assigned, confirmedOrderId, 'Ana Reyes'),
      GallonSeed('GLN-0004', GallonStatus.assigned, confirmedOrderId, 'Ana Reyes'),
      GallonSeed('GLN-0005', GallonStatus.outForDelivery, preparingOrderId, 'Carlo Mendoza'),
      GallonSeed('GLN-0006', GallonStatus.outForDelivery, preparingOrderId, 'Carlo Mendoza'),
      GallonSeed('GLN-0007', GallonStatus.outForDelivery, transitOrderId, 'Maria Santos'),
      GallonSeed('GLN-0008', GallonStatus.outForDelivery, transitOrderId, 'Maria Santos'),
      const GallonSeed('GLN-0014', GallonStatus.withCustomer, null, 'Rico Torres'),
      const GallonSeed('GLN-0015', GallonStatus.returned, null, null),
      const GallonSeed('GLN-0016', GallonStatus.damaged, null, null),
    ];
  }

  List<GallonSeed>? gallonPlan;

  Future<void> _seedGallons(Map<String, String> customers) async {
    for (int i = 1; i <= 30; i++) {
      final String code = 'GLN-${i.toString().padLeft(4, '0')}';
      await _db.collection(Collections.gallons).doc(code).set(<String, dynamic>{
        'gallonId': code,
        'qrCodeValue': code,
        'status': GallonStatus.available,
        'currentCustomerId': null,
        'currentCustomerName': null,
        'currentOrderId': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    final List<GallonSeed>? plan = gallonPlan;
    if (plan == null) return;
    for (final GallonSeed g in plan) {
      final Map<String, dynamic> update = <String, dynamic>{
        'status': g.status,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (g.orderId != null) {
        update['currentOrderId'] = g.orderId;
        update['currentCustomerId'] = g.customerName != null ? customers[g.customerName!] : null;
        update['currentCustomerName'] = g.customerName;
      } else if (g.status == GallonStatus.withCustomer) {
        update['currentCustomerName'] = g.customerName;
      }
      await _db.collection(Collections.gallons).doc(g.code).update(update);
    }
  }
}

class SeedProduct {
  const SeedProduct({required this.id, required this.name, required this.price});
  final String id;
  final String name;
  final double price;
}

class GallonSeed {
  const GallonSeed(this.code, this.status, this.orderId, this.customerName);
  final String code;
  final String status;
  final String? orderId;
  final String? customerName;
}
