import 'package:flutter/material.dart';

class AppConstants {
  AppConstants._();

  static const String appName = 'Aqua Link PH';
  static const String stationName = 'Edelycalie Water Refilling Station';
  static const String stationTagline =
      'Web-Based Water Station Management with QR-Based Gallon Inventory, Delivery Tracking & Profit Analytics';
  static const String stationAddress = 'Purok 2, Brgy. San Isidro, Philippines';
  static const String stationPhone = '0917 555 0143';
  static const String stationHours = 'Mon–Sat · 6:00 AM – 7:00 PM';

  static const double deliveryFee = 20;
}

class Roles {
  Roles._();

  static const String admin = 'admin';
  static const String staff = 'staff';
  static const String customer = 'customer';

  static String label(String role) {
    switch (role) {
      case admin:
        return 'Administrator';
      case staff:
        return 'Staff';
      case customer:
        return 'Customer';
    }
    return role;
  }
}

class Collections {
  Collections._();

  static const String users = 'users';
  static const String customers = 'customers';
  static const String orders = 'orders';
  static const String gallons = 'gallons';
  static const String inventory = 'inventory';
  static const String sales = 'sales';
  static const String expenses = 'expenses';
  static const String notifications = 'notifications';
  static const String gallonHistory = 'history';
  static const String config = 'config';
}

class OrderStatus {
  OrderStatus._();

  static const String pending = 'pending';
  static const String confirmed = 'confirmed';
  static const String preparing = 'preparing';
  static const String inTransit = 'in_transit';
  static const String delivered = 'delivered';
  static const String cancelled = 'cancelled';

  static const List<String> activeFlow = [
    pending,
    confirmed,
    preparing,
    inTransit,
    delivered,
  ];

  static const List<String> all = [
    pending,
    confirmed,
    preparing,
    inTransit,
    delivered,
    cancelled,
  ];

  static String label(String status) {
    switch (status) {
      case pending:
        return 'Pending';
      case confirmed:
        return 'Confirmed';
      case preparing:
        return 'Preparing';
      case inTransit:
        return 'In Transit';
      case delivered:
        return 'Delivered';
      case cancelled:
        return 'Cancelled';
    }
    return status;
  }

  static Color color(String status) {
    switch (status) {
      case pending:
        return const Color(0xFFF2C94C);
      case confirmed:
        return const Color(0xFF2F80ED);
      case preparing:
        return const Color(0xFF9B51E0);
      case inTransit:
        return const Color(0xFF27C6DA);
      case delivered:
        return const Color(0xFF2ECC71);
      case cancelled:
        return const Color(0xFFEB5757);
    }
    return Colors.grey;
  }

  static int stepIndex(String status) => activeFlow.indexOf(status);
}

class PaymentStatus {
  PaymentStatus._();

  static const String unpaid = 'unpaid';
  static const String paid = 'paid';

  static String label(String s) => s == paid ? 'Paid' : 'Unpaid';

  static Color color(String s) =>
      s == paid ? const Color(0xFF2ECC71) : const Color(0xFFEB5757);
}

class PaymentMethod {
  PaymentMethod._();

  static const String cash = 'cash';
  static const String gcash = 'gcash';

  static String label(String m) => m == cash ? 'Cash' : 'GCash';
}

class OrderType {
  OrderType._();

  static const String delivery = 'delivery';
  static const String walkIn = 'walk_in';

  static String label(String t) => t == delivery ? 'Delivery' : 'Walk-in';
}

class GallonStatus {
  GallonStatus._();

  static const String available = 'available';
  static const String assigned = 'assigned';
  static const String outForDelivery = 'out_for_delivery';
  static const String withCustomer = 'with_customer';
  static const String returned = 'returned';
  static const String damaged = 'damaged';
  static const String lost = 'lost';

  static const List<String> all = [
    available,
    assigned,
    outForDelivery,
    withCustomer,
    returned,
    damaged,
    lost,
  ];

  static String label(String s) {
    switch (s) {
      case available:
        return 'Available';
      case assigned:
        return 'Assigned';
      case outForDelivery:
        return 'Out for Delivery';
      case withCustomer:
        return 'With Customer';
      case returned:
        return 'Returned';
      case damaged:
        return 'Damaged';
      case lost:
        return 'Lost';
    }
    return s;
  }

  static Color color(String s) {
    switch (s) {
      case available:
        return const Color(0xFF2ECC71);
      case assigned:
        return const Color(0xFFF2C94C);
      case outForDelivery:
        return const Color(0xFF27C6DA);
      case withCustomer:
        return const Color(0xFF2F80ED);
      case returned:
        return const Color(0xFF9B51E0);
      case damaged:
        return const Color(0xFFEB5757);
      case lost:
        return const Color(0xFF8CA0BF);
    }
    return Colors.grey;
  }

  static const Map<String, List<String>> allowedTransitions = {
    available: [assigned, damaged, lost],
    assigned: [outForDelivery, available, damaged, lost],
    outForDelivery: [withCustomer, lost, damaged],
    withCustomer: [returned, damaged, lost],
    returned: [available, damaged],
    damaged: [available, lost],
    lost: [],
  };
}

class ExpenseCategories {
  static const List<String> all = [
    'Electricity',
    'Water Bill',
    'Rent',
    'Supplies',
    'Salaries',
    'Transportation',
    'Maintenance',
    'Others',
  ];
}
